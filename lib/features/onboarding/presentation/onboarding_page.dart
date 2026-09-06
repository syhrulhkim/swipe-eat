import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../friends/data/contacts_reader.dart';
import '../../friends/models/friend.dart';
import '../../friends/state/friends_controller.dart';
import '../data/onboarding_repository.dart';
import '../models/onboarding_draft.dart';
import '../models/taste_option.dart';
import 'onboarding_steps.dart';

/// Injected so widget tests can drive the location step without the geolocator
/// platform channel (which has no implementation under `flutter test`).
typedef PositionResolver = Future<Position> Function();
typedef PlaceNameResolver = Future<String?> Function(Position position);

/// The four-step wizard every account walks exactly once.
///
/// Nothing is written until "Finish": the draft lives in memory, so quitting
/// mid-wizard leaves `onboarded_at` null and the router simply shows the
/// wizard again next launch, rather than stranding a half-configured account.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.authController,
    this.repository,
    this.resolvePosition = resolveUserPosition,
    this.resolvePlace = resolvePlaceName,
    this.readContacts = readContactPhoneNumbers,
    this.friends,
  });

  final AuthController authController;
  final OnboardingRepository? repository;
  final PositionResolver resolvePosition;
  final PlaceNameResolver resolvePlace;

  /// Injected for the same reason the position resolver is: reading the
  /// address book is a platform channel with no implementation under
  /// `flutter test`. Every test runs against a reader that never touches one,
  /// which is also what makes "Skip sends nothing" a thing a test can assert.
  final ContactsReader readContacts;

  /// The friend graph, so the requests chosen here can be sent once the
  /// account exists. Null takes the app-lifetime singleton.
  final FriendsController? friends;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepCount = 7;

  /// "Any rules?" — the diet and budget step. Skippable because its answers
  /// hide restaurants rather than reorder them.
  static const _rulesStep = 2;

  /// "Eat with people" — the other skippable step, and the reason the topbar's
  /// Skip slot is now asked about twice.
  ///
  /// It sits here, immediately after the rules, and not later: `_skipLocation`
  /// calls `_finish()` outright, so anything placed after the location step is
  /// silently skipped by everybody who declines location.
  static const _friendsStep = 3;

  late final OnboardingRepository _repository;
  late final OnboardingDraft _draft;
  late final TextEditingController _nameController;
  final _pageController = PageController();

  TasteCatalog _catalog = const TasteCatalog.empty();
  List<FriendProfile> _matches = const [];
  bool _hasSearchedContacts = false;
  bool _searchingContacts = false;
  String? _contactsError;
  int _step = 0;
  bool _loading = true;
  bool _locating = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OnboardingRepository();

    // A Google/Apple signup already knows the user's name; only the
    // `handle_new_user` placeholder is worth clearing.
    final existing = widget.authController.user?.name ?? '';
    _draft = OnboardingDraft(name: existing == 'User' ? '' : existing);
    _nameController = TextEditingController(text: _draft.name);

    _loadCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final catalog = await _repository.loadCatalog();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Could not load the taste list. Check your connection.';
      });
    }
  }

  /// Whether the current step has enough to move on. Everything past the taste
  /// step is always satisfiable — the rules, the tiles and the location itself
  /// all have valid defaults.
  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _draft.hasName;
      case 1:
        return _draft.hasTaste;
      default:
        return true;
    }
  }

  String get _primaryLabel {
    if (_saving) {
      return 'Setting up...';
    }
    // The design's words, not "Finish": the last step teaches the gestures,
    // so the button that leaves it should name what is on the other side.
    if (_step == _stepCount - 1) {
      return 'Show me dinner';
    }
    // "Add 3 friends", as the design draws it — the button says what pressing
    // it will do, and its number is the tick count, not the match count.
    // With nobody ticked it is a plain Continue rather than "Add 0 friends".
    if (_step == _friendsStep && _draft.friendIds.isNotEmpty) {
      final count = _draft.friendIds.length;
      return 'Add $count ${count == 1 ? 'friend' : 'friends'}';
    }
    return 'Continue';
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
      return;
    }
    await _finish();
  }

  /// Skipping the rules step is an answer, not an escape hatch: it clears the
  /// defaults sitting on screen before moving on, so nobody who never looked
  /// at the step ends up with a budget cap they did not choose.
  void _skipRules() {
    setState(_draft.clearRules);
    _goToStep(_step + 1);
  }

  /// Reads the address book, hashes what it finds, and asks the server which
  /// of those hashes it knows.
  ///
  /// The raw numbers never leave this method: [FriendsController.matchContacts]
  /// takes them and hashes them itself, so there is no version of this call
  /// that forgets to. A refusal at the permission sheet comes back as an empty
  /// list, which is the same screen as "nobody matched" — being told you have
  /// no friends here because you said no would be a strange thing to read.
  Future<void> _findFriends() async {
    if (_searchingContacts) {
      return;
    }
    setState(() {
      _searchingContacts = true;
      _contactsError = null;
    });

    try {
      final numbers = await widget.readContacts();
      final matches = await _friends.matchContacts(numbers);
      // A result that arrives for a step the user has already left is dropped
      // whole, ticks and all. Skip clears `friendIds` and moves on; without
      // this line a slow permission sheet or a slow network could refill the
      // set behind them and `_finish` would send requests they never asked to
      // send. Skip has to mean skipped even when it is tapped mid-flight.
      if (!mounted || _step != _friendsStep) {
        return;
      }
      setState(() {
        _matches = matches;
        _hasSearchedContacts = true;
        _searchingContacts = false;
        // Everybody who matched starts ticked. They are people the user has in
        // their phone; the screen is a chance to take some off, not a form to
        // fill in.
        _draft.friendIds
          ..clear()
          ..addAll(matches.map((person) => person.id));
      });
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (!mounted || _step != _friendsStep) {
        return;
      }
      setState(() {
        _searchingContacts = false;
        _contactsError = 'Could not check your contacts. You can add friends '
            'later from the You tab.';
      });
    }
  }

  void _toggleFriend(String userId) {
    setState(() {
      if (!_draft.friendIds.remove(userId)) {
        _draft.friendIds.add(userId);
      }
    });
  }

  /// Skip on the friends step sends nothing and reads nothing.
  ///
  /// Not "sends an empty list" — the contacts reader is never called, so the
  /// permission sheet never appears, and no hash of any number is computed.
  /// Somebody who skips this step has told the app to stay out of their
  /// address book, and the way to honour that is to not go in.
  void _skipFriends() {
    setState(() {
      _draft.friendIds.clear();
      // A search still in flight is abandoned here, not awaited: the result is
      // dropped when it lands (see `_findFriends`), and leaving the flag up
      // would grey out Continue on every step after this one.
      _searchingContacts = false;
    });
    _goToStep(_step + 1);
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);

    final position = await widget.resolvePosition();
    // A fallback fix is a made-up coordinate; storing it would tell the deck
    // the user is somewhere they are not, so it counts as "no location".
    final real = !isFallbackUserPosition(position);
    final place = real ? await widget.resolvePlace(position) : null;

    if (!mounted) {
      return;
    }

    setState(() {
      _locating = false;
      if (real) {
        _draft
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..placeName = place
          ..locationSource = LocationSource.gps;
      } else {
        _draft
          ..latitude = null
          ..longitude = null
          ..placeName = null
          ..locationSource = LocationSource.denied;
      }
    });

    if (!real) {
      _showMessage(
        'Location is off for Swipe Eat. You can turn it on later in Settings.',
      );
    }
  }

  /// "Not now" is an answer, not an escape: it records `denied` so the ranking
  /// stops waiting for a fix, and finishes the wizard rather than leaving the
  /// user on a step with nothing left to do.
  Future<void> _skipLocation() async {
    setState(() {
      _draft
        ..latitude = null
        ..longitude = null
        ..placeName = null
        ..locationSource = LocationSource.denied;
    });
    await _finish();
  }

  Future<void> _finish() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);

    try {
      final user = await _repository.complete(_draft);
      if (!mounted) {
        return;
      }
      // After the profile exists, never before: a friend request needs two
      // accounts. Awaited, but its failures are swallowed inside
      // `sendRequests` — a request that did not send is worth less than a
      // setup that did.
      await _sendFriendRequests();
      if (!mounted) {
        return;
      }
      // Closes the router gate; the redirect then moves us to the dashboard.
      widget.authController.applyUser(user);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showMessage('Could not save your setup. Please try again.');
    }
  }

  /// Sends the requests, and swallows whatever goes wrong doing it.
  ///
  /// The real repository already tolerates one request failing among many, but
  /// the call as a whole can still fail — no network, a refresh that throws —
  /// and letting that reach `_finish` would put "Could not save your setup" on
  /// screen over a profile that saved perfectly. A friend request can be made
  /// again from the You tab; a completed wizard cannot be re-completed.
  Future<void> _sendFriendRequests() async {
    if (_draft.friendIds.isEmpty) {
      return;
    }
    try {
      await _friends.sendRequests(_draft.friendIds);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Nothing to say here: the setup succeeded, and the friends are one tap
      // away on a screen the user is about to be able to reach.
    }
  }

  FriendsController get _friends =>
      widget.friends ?? FriendsController.instance;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.dashboardMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: _loading
                  ? const Center(
                      child: AppLottie(motion: AppMotion.spinner, size: 72),
                    )
                  : _loadError != null
                      ? _LoadFailure(
                          message: _loadError!,
                          onRetry: _loadCatalog,
                        )
                      : _buildWizard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The design's first-run topbar: back, the progress bar, and — on the
        // one skippable step — a Skip. The two 44 px slots are always there so
        // the bar itself never shifts between steps.
        Row(
          children: [
            if (_step > 0)
              AppIconButton(
                key: const ValueKey('onboarding-back'),
                icon: Icons.chevron_left_rounded,
                size: kUtilityButtonSize,
                background: kGlass,
                semanticLabel: 'Back',
                onTap: _saving ? () {} : () => _goToStep(_step - 1),
              )
            else
              const SizedBox(width: kUtilityButtonSize),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                ),
                child: _StepProgress(step: _step, total: _stepCount),
              ),
            ),
            if (_step == _rulesStep)
              _SkipButton(onPressed: _saving ? null : _skipRules)
            else if (_step == _friendsStep)
              _SkipButton(onPressed: _saving ? null : _skipFriends)
            else
              const SizedBox(width: kUtilityButtonSize),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: PageView(
            controller: _pageController,
            // Driven by the buttons only: swiping past an unmet requirement
            // would put the user on a step the Continue button had refused.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              OnboardingYouStep(
                nameController: _nameController,
                avatarUrl: widget.authController.user?.avatarUrl,
                onChanged: (value) => setState(() => _draft.name = value),
              ),
              OnboardingTasteStep(
                catalog: _catalog,
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              OnboardingRulesStep(
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              OnboardingFriendsStep(
                matches: _matches,
                selectedIds: _draft.friendIds,
                hasSearched: _hasSearchedContacts,
                isSearching: _searchingContacts,
                onFindFriends: _findFriends,
                onToggle: _toggleFriend,
                error: _contactsError,
              ),
              OnboardingHabitsStep(
                draft: _draft,
                onChanged: () => setState(() {}),
              ),
              OnboardingLocationStep(
                draft: _draft,
                isLocating: _locating,
                onUseLocation: _useLocation,
                onSkip: _skipLocation,
              ),
              const OnboardingHowToSwipeStep(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // One block button in the foot, as the design draws it. Back moved to
        // the topbar, which is what freed the width.
        //
        // Disabled rather than busy: the wizard hands off to the router on
        // success and never rebuilds itself out of the saving state, so a
        // spinner here would keep spinning after the work is done.
        AppPrimaryButton(
          label: _primaryLabel,
          expand: true,
          onPressed: _canAdvance && !_saving && !_locating && !_searchingContacts
              ? _next
              : null,
        ),
      ],
    );
  }
}

/// The design's `.textbtn`: a quiet word, no fill, no border. It is the only
/// control on these screens that is neither primary nor a switch, and it looks
/// like it — a Skip that looked like a button would be pressed by accident.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(kUtilityButtonSize, kUtilityButtonSize),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        foregroundColor: kCreamSecondary,
        textStyle: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeSmall,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Skip'),
    );
  }
}

/// The design's `.steps`: one hairline segment per step, ember for where you
/// are, muted cream for what is behind you, hairline for what is ahead.
///
/// The three states matter. A bar that fills solid says "this much is done";
/// this one says "you are here, and there are four more" — which is the
/// question someone halfway through a first run is actually asking.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: kStepBarGap),
            Expanded(
              child: AnimatedContainer(
                duration: kMotionDuration,
                curve: kMotionEase,
                height: kStepBarHeight,
                decoration: BoxDecoration(
                  color: index == step
                      ? kAccentEmber
                      : index < step
                          ? kCreamMuted
                          : kHairline,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: kTextOnPhotoSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}
