import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/data/profile_repository.dart';

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
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
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
      body: ListView(
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
                    // "No limit" rather than crashing on -1.
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
                    onTap: _deleting
                        ? null
                        : () => widget.authController.logout(),
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
      ),
    );
  }
}
