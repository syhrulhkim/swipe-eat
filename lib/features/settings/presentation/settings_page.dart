import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/models/app_user.dart';
import '../../auth/state/auth_controller.dart';
import '../../onboarding/models/onboarding_draft.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/preference_controls.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.authController,
    this.repository,
  });

  final AuthController authController;

  /// Injectable for tests; defaults to the real Supabase-backed repository.
  final ProfileRepository? repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ProfileRepository _repository =
      widget.repository ?? ProfileRepository();

  /// Local copy so the slider tracks the finger; the profile row is only
  /// written on release, and a failed write snaps back to this value's
  /// previous state.
  late int? _radiusKm = widget.authController.user?.searchRadiusKm;

  /// The budget range while the finger is on it, for the same reason as
  /// [_radiusKm]: a range reports on every division it crosses, so writing
  /// from `onChanged` would fire a dozen RPCs per drag and leave the session
  /// holding whichever reply happened to land last. Null means "showing what
  /// the profile says".
  int? _dragBudgetMin;
  int? _dragBudgetMax;
  bool _draggingBudget = false;
  bool _saving = false;
  bool _deleting = false;

  Future<void> _saveRadius(int? radiusKm) async {
    final previous = widget.authController.user?.searchRadiusKm;
    if (radiusKm == previous) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // The radius is a hard server-side filter: the deck and Explore only
      // serve rows within it, so the write has to land before it "counts".
      final user = await _repository.updateSearchRadius(radiusKm);
      if (!mounted) {
        return;
      }
      widget.authController.applyUser(user);
      setState(() {
        _radiusKm = user.searchRadiusKm;
        _saving = false;
      });
    } on Object catch (error) {
      // Any failure means the same thing to the user: the radius did not
      // save, so put the old one back and say so.
      debugPrint('Radius save failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _radiusKm = previous;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your search radius.')),
      );
    }
  }

  /// The diet & budget answers, written the moment they change.
  ///
  /// Optimistic like the You tab's sheets and for the same reason: these are
  /// hard deck filters, so the screen has to agree with the finger immediately
  /// and put the old answer back — loudly — if the write does not land.
  Future<void> _savePreference(
    AppUser optimistic,
    Future<AppUser> Function() write,
  ) async {
    final previous = widget.authController.user;
    widget.authController.applyUser(optimistic);

    try {
      widget.authController.applyUser(await write());
    } on Object catch (error) {
      debugPrint('Preference save failed: $error');
      if (previous != null) {
        widget.authController.applyUser(previous);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that preference.')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the page.')),
    );
  }

  /// Two-step delete: a dialog that spells out what is lost, then the call. Both
  /// stores require this path to exist in the app, and it is irreversible, so it
  /// is deliberately not a one-tap action.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, your taste preferences and '
          'every place you liked, saved or marked as visited. It cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deleting = true;
    });
    final deleted = await widget.authController.deleteAccount();
    if (!mounted) {
      return;
    }
    setState(() {
      _deleting = false;
    });

    if (deleted) {
      // The router redirects to login off the unauthenticated state; closing
      // Settings first stops it animating out over the login page.
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.authController.errorMessage ??
              'Your account could not be deleted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stopIndex = kRadiusStops.indexOf(_radiusKm);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      // The rules below are drawn straight from the session, so the page has
      // to rebuild when a write lands — and when an optimistic one is rolled
      // back.
      body: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) => _buildBody(context, stopIndex),
      ),
    );
  }

  Widget _buildBody(BuildContext context, int stopIndex) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text(
          'Discovery',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Search radius',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      radiusLabel(_radiusKm),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Slider(
                  // An unknown stored value (not on the stops) renders as
                  // "Any distance" rather than crashing on -1.
                  value: (stopIndex < 0 ? kRadiusStops.length - 1 : stopIndex)
                      .toDouble(),
                  max: (kRadiusStops.length - 1).toDouble(),
                  divisions: kRadiusStops.length - 1,
                  label: radiusLabel(_radiusKm),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _radiusKm = kRadiusStops[value.round()];
                          });
                        },
                  onChangeEnd: (value) =>
                      _saveRadius(kRadiusStops[value.round()]),
                ),
                Text(
                  'Only places within this distance of your location are '
                  'shown in the deck and on Explore.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RulesSection(
          user: widget.authController.user,
          onHalalOnly: (value, user) => _savePreference(
            user.copyWith(halalOnly: value),
            () => _repository.updatePreferences(halalOnly: value),
          ),
          onVegetarian: (value, user) => _savePreference(
            user.copyWith(vegetarian: value),
            () => _repository.updatePreferences(vegetarian: value),
          ),
          onSpice: (value, user) => _savePreference(
            user.copyWith(spiceLevel: value.level),
            () => _repository.updatePreferences(spiceLevel: value.level),
          ),
          budgetMin: _draggingBudget ? _dragBudgetMin : null,
          budgetMax: _draggingBudget ? _dragBudgetMax : null,
          onBudgetChanged: (min, max) => setState(() {
            _draggingBudget = true;
            _dragBudgetMin = min;
            _dragBudgetMax = max;
          }),
          onBudget: (min, max, user) {
            setState(() {
              _draggingBudget = false;
              _dragBudgetMin = null;
              _dragBudgetMax = null;
            });
            unawaited(_savePreference(
              user.copyWith(budgetMin: min, budgetMax: max),
              () => _repository.updatePreferences(
                budgetMin: min,
                budgetMax: max,
              ),
            ));
          },
        ),
        const SizedBox(height: 20),
        Text(
          'About',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Terms of use'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(AppConfig.termsUrl),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sign out'),
                  trailing: const Icon(Icons.logout_rounded, size: 18),
                  onTap:
                      _deleting ? null : () => widget.authController.logout(),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Delete account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Permanently removes your account and everything in it.',
                  ),
                  trailing: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                  onTap: _deleting ? null : _confirmDelete,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Any rules?" as it appears in Settings — the same four controls the first
/// run asks, so a preference does not change shape between the screen that
/// asked for it and the screen where it is changed.
///
/// Unlike the radius above it, these write per-change rather than on release:
/// a switch and a segment have no drag to finish.
class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.user,
    required this.onHalalOnly,
    required this.onVegetarian,
    required this.onSpice,
    required this.onBudget,
    required this.onBudgetChanged,
    this.budgetMin,
    this.budgetMax,
  });

  final AppUser? user;
  final void Function(bool value, AppUser user) onHalalOnly;
  final void Function(bool value, AppUser user) onVegetarian;
  final void Function(SpiceLevel value, AppUser user) onSpice;
  final void Function(int min, int? max, AppUser user) onBudget;

  /// Where the thumbs are mid-drag, before anything has been written. Null
  /// falls back to the stored answer.
  final void Function(int min, int? max) onBudgetChanged;
  final int? budgetMin;
  final int? budgetMax;

  @override
  Widget build(BuildContext context) {
    final account = user;
    if (account == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: account.halalOnly,
          onChanged: (value) => onHalalOnly(value, account),
        ),
        const SizedBox(height: 10),
        PrefSwitchRow(
          title: 'Vegetarian options',
          subtitle: 'Must have a real veg section',
          value: account.vegetarian,
          onChanged: (value) => onVegetarian(value, account),
        ),
        const SizedBox(height: 10),
        PrefSpiceRow(
          value: SpiceLevel.fromLevel(account.spiceLevel),
          onChanged: (value) => onSpice(value, account),
        ),
        const SizedBox(height: 10),
        PrefBudgetRow(
          min: budgetMin ?? account.budgetMin,
          // An unanswered budget opens where the first run opens it —
          // "RM 10–40" — not on a floor of RM 10 with no ceiling, which is a
          // real answer nobody here gave.
          // Mid-drag the pair is authoritative on its own: a released cap is a
          // null the finger just chose, so it must not fall back to the stored
          // ceiling and yank the thumb back down.
          max: budgetMin != null
              ? budgetMax
              : account.hasBudget
                  ? account.budgetMax
                  : kBudgetDefaultMax,
          onChanged: onBudgetChanged,
          onChangeEnd: (min, max) => onBudget(min, max, account),
        ),
      ],
    );
  }
}
