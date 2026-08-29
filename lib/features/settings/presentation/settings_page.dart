import 'package:flutter/material.dart';

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
    } catch (error) {
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
            'App Settings',
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
                    title: const Text('Language'),
                    subtitle: const Text('English'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifications'),
                    subtitle: const Text('Enabled'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
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
