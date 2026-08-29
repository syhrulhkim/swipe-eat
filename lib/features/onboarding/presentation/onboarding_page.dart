import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/place_name.dart';
import '../../../core/location/user_location.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
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
  });

  final AuthController authController;
  final OnboardingRepository? repository;
  final PositionResolver resolvePosition;
  final PlaceNameResolver resolvePlace;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepCount = 4;

  late final OnboardingRepository _repository;
  late final OnboardingDraft _draft;
  late final TextEditingController _nameController;
  final _pageController = PageController();

  TasteCatalog _catalog = const TasteCatalog.empty();
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

  /// Whether the current step has enough to move on. Steps 3 and 4 are always
  /// satisfiable — every tile and the location itself have valid defaults.
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
    return _step == _stepCount - 1 ? 'Finish' : 'Continue';
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
                  ? const Center(child: CircularProgressIndicator())
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
        _StepProgress(step: _step, total: _stepCount),
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (_step > 0)
              TextButton(
                onPressed: _saving ? null : () => _goToStep(_step - 1),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _canAdvance && !_saving && !_locating ? _next : null,
              style: FilledButton.styleFrom(
                backgroundColor: kAccentEmber,
                foregroundColor: kOnAccent,
                disabledBackgroundColor: kSurfacePanel,
                minimumSize: const Size(140, 48),
              ),
              child: Text(_primaryLabel),
            ),
          ],
        ),
      ],
    );
  }
}

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
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= step
                      ? kAccentEmber
                      : Colors.white.withValues(alpha: 0.14),
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
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: kAccentEmber,
              foregroundColor: kOnAccent,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
