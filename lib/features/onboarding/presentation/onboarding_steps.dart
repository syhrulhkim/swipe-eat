import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../../core/ui/radius_options.dart';
import '../models/onboarding_draft.dart';
import '../models/taste_option.dart';

/// Step 1 — who you are.
class OnboardingYouStep extends StatelessWidget {
  const OnboardingYouStep({
    super.key,
    required this.nameController,
    required this.avatarUrl,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final String? avatarUrl;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'What should we call you?',
          subtitle: 'This is the only thing other people would ever see.',
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: kSurfacePanel,
            backgroundImage: url == null ? null : NetworkImage(url),
            child: url != null
                ? null
                : const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: kTextOnPhotoMuted,
                  ),
          ),
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        TextField(
          controller: nameController,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: kTextOnPhoto),
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Your name',
          ),
        ),
      ],
    );
  }
}

/// Step 2 — the cold-start taste signal.
class OnboardingTasteStep extends StatelessWidget {
  const OnboardingTasteStep({
    super.key,
    required this.catalog,
    required this.draft,
    required this.onChanged,
  });

  final TasteCatalog catalog;
  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'What do you like to eat?',
          subtitle: 'Pick at least one. This is what the deck starts from — '
              'it learns the rest from your swipes.',
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        _ChipWrap(
          options: catalog.cuisines,
          selected: draft.cuisineIds,
          onToggle: (id) {
            draft.toggleCuisine(id);
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        Text('Anything we should avoid?', style: appPanelTitleStyle(context)),
        const SizedBox(height: 4),
        Text(
          'Optional. We use this to nudge the order, never to hide places — '
          'the catalog does not carry reliable dietary data yet.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kTextOnPhotoMuted,
              ),
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        _ChipWrap(
          options: catalog.dietaryTags,
          selected: draft.dietaryIds,
          onToggle: (id) {
            draft.toggleDietary(id);
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Step 3 — the three ranking tiles plus the hard distance filter.
class OnboardingHabitsStep extends StatelessWidget {
  const OnboardingHabitsStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final stopIndex = kRadiusStops.indexOf(draft.radiusKm);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'How do you eat?',
          subtitle: 'Tap a tile to change it. You can edit all of this later '
              'from your profile.',
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        PreferenceTile(
          icon: Icons.wb_sunny_rounded,
          title: 'Morning mode',
          subtitle: 'Show breakfast first before 11am',
          trailingLabel: draft.morningMode ? 'On' : 'Off',
          tint: kTintMorning,
          onTap: () {
            draft.morningMode = !draft.morningMode;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        PreferenceTile(
          icon: Icons.local_fire_department_rounded,
          title: 'Spice bias',
          subtitle: 'Prioritize bolder flavors',
          trailingLabel: draft.spiceBias.label,
          tint: kTintSpice,
          onTap: () {
            draft.spiceBias = draft.spiceBias.next;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        PreferenceTile(
          icon: Icons.pin_drop_rounded,
          title: 'Nearby focus',
          subtitle: 'Favor shorter distances',
          trailingLabel: draft.nearbyFocus ? 'On' : 'Off',
          tint: kTintNearby,
          onTap: () {
            draft.nearbyFocus = !draft.nearbyFocus;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        AppPanel(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search radius',
                        style: appPanelTitleStyle(context),
                      ),
                    ),
                    Text(
                      radiusLabel(draft.radiusKm),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: kAccentEmber,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                Text(
                  'A hard limit: places further than this are not shown at '
                  'all.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kTextOnPhotoMuted,
                      ),
                ),
                Slider(
                  value: (stopIndex < 0 ? kRadiusStops.length - 1 : stopIndex)
                      .toDouble(),
                  min: 0,
                  max: (kRadiusStops.length - 1).toDouble(),
                  divisions: kRadiusStops.length - 1,
                  label: radiusLabel(draft.radiusKm),
                  activeColor: kAccentEmber,
                  onChanged: (value) {
                    draft.radiusKm = kRadiusStops[value.round()];
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 4 — the location primer.
class OnboardingLocationStep extends StatelessWidget {
  const OnboardingLocationStep({
    super.key,
    required this.draft,
    required this.isLocating,
    required this.onUseLocation,
    required this.onSkip,
  });

  final OnboardingDraft draft;
  final bool isLocating;
  final VoidCallback onUseLocation;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final located = draft.locationSource == LocationSource.gps;
    final skipped = draft.locationSource == LocationSource.denied;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'Where are you eating?',
          subtitle: 'Distance is the strongest signal in the deck. We store '
              'one coordinate on your profile and update it as you move — we '
              'never keep a trail.',
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        // Loops only while the fix is being taken: a pulse that never stops
        // would claim the app is still looking after it has an answer.
        Center(
          child: AppLottie(
            motion: AppMotion.pin,
            size: 120,
            repeat: isLocating,
          ),
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        AppPanel(
          accent: located ? kAccentEmber : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  located ? Icons.check_circle_rounded : Icons.my_location_rounded,
                  color: located ? kAccentEmber : kTextOnPhotoMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    located
                        ? draft.placeName ?? 'Location set'
                        : skipped
                            ? 'Skipped — the deck will rank without distance.'
                            : 'Not set yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kTextOnPhotoSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        AppPrimaryButton(
          label: isLocating ? 'Finding you...' : 'Use my location',
          icon: Icons.near_me_rounded,
          expand: true,
          onPressed: isLocating ? null : onUseLocation,
        ),
        const SizedBox(height: 8),
        AppSecondaryButton(
          label: 'Not now',
          expand: true,
          onPressed: isLocating ? null : onSkip,
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<TasteOption> options;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _TasteChip(
            option: option,
            selected: selected.contains(option.id),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

class _TasteChip extends StatelessWidget {
  const _TasteChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TasteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emoji = option.emoji;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kAccentEmber : kSurfacePanel,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(
              color: selected ? kAccentEmber : kHairline,
            ),
          ),
          child: Text(
            emoji == null ? option.label : '$emoji  ${option.label}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? kOnAccent : kTextOnPhotoSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: appTitleStyle(context)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kTextOnPhotoMuted,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

/// Vertical rhythm shared by the four steps.
class AppOnboardingGaps {
  const AppOnboardingGaps._();

  static const double item = 10;
  static const double section = 20;
}
