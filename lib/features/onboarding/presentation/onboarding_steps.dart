import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../../core/ui/radius_options.dart';
import '../../friends/models/friend.dart';
import '../../friends/presentation/person_row.dart';
import '../../profile/presentation/preference_controls.dart';
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

/// Step 3 — "Any rules?": the diet and budget answers the deck treats as hard
/// filters rather than as weights.
///
/// This is the one step that hides restaurants instead of reordering them,
/// which is why it comes with a reason above it and a Skip beside it: a rule
/// nobody meant to set is worse than no rule at all.
class OnboardingRulesStep extends StatelessWidget {
  const OnboardingRulesStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final OnboardingDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'Any rules?',
          subtitle: "So we never show you somewhere you can't eat.",
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Only places we know are certified',
          value: draft.halalOnly,
          onChanged: (value) {
            draft.halalOnly = value;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        PrefSwitchRow(
          title: 'Vegetarian options',
          subtitle: 'Only places we know have a veg section',
          value: draft.vegetarian,
          onChanged: (value) {
            draft.vegetarian = value;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        PrefSpiceRow(
          value: draft.spiceLevel,
          onChanged: (value) {
            draft.spiceLevel = value;
            onChanged();
          },
        ),
        const SizedBox(height: AppOnboardingGaps.item),
        PrefBudgetRow(
          min: draft.budgetMin,
          max: draft.budgetMax,
          onChanged: (min, max) {
            draft
              ..budgetMin = min
              ..budgetMax = max;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Step 4 — the three ranking tiles plus the hard distance filter.
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
        // No spice tile here: the rules step already asks the question on its
        // four-step control, and `complete_onboarding` derives `spice_bias`
        // from that answer (D104). Two questions about one thing, the second
        // silently discarded, is worse than one.
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
                  located
                      ? Icons.check_circle_rounded
                      : Icons.my_location_rounded,
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
            option.label,
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

/// The design's "Three moves" step: what the three gestures do, before the
/// user meets a card that expects them.
///
/// Teaching the gestures is the whole point of the screen, so each row names
/// the gesture, gives it the word the app uses for it, and says what it means
/// in plain language. The words matter more than the arrows — "Ngap" is the
/// product's own verb, and this is where it is learned.
class OnboardingHowToSwipeStep extends StatelessWidget {
  const OnboardingHowToSwipeStep({super.key});

  /// Kept in the order the thumb learns them: the yes first, then the no,
  /// then the one that defers.
  static const _moves = <({IconData icon, String label, String meaning})>[
    (
      icon: Icons.arrow_forward_rounded,
      label: 'Ngap!',
      meaning: 'I want this',
    ),
    (
      icon: Icons.arrow_back_rounded,
      label: 'Skip',
      meaning: 'Not tonight',
    ),
    (
      icon: Icons.arrow_upward_rounded,
      label: 'Later',
      meaning: 'Save without deciding',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepHeading(
          title: 'Three moves',
          subtitle: 'Every card is a short video from the restaurant. Watch, '
              'then flick.',
        ),
        const SizedBox(height: AppOnboardingGaps.section),
        for (final move in _moves) ...[
          _MoveRow(icon: move.icon, label: move.label, meaning: move.meaning),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: AppOnboardingGaps.section),
        Text(
          'Bitten places land in Your bites. Set a date from there.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kCreamMuted,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

/// One gesture: its arrow, the app's word for it, and what it means.
class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.icon,
    required this.label,
    required this.meaning,
  });

  final IconData icon;
  final String label;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // One node per row: read as a sentence rather than as an arrow glyph
      // followed by two unrelated fragments.
      label: '$label — $meaning',
      excludeSemantics: true,
      child: AppPanel(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kGlass,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  border: Border.all(color: kHairline),
                ),
                child: Icon(icon, size: 19, color: kAccentEmber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: appPanelTitleStyle(context)),
                    const SizedBox(height: 2),
                    Text(
                      meaning,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: kCreamSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's 01f — the people you already know who are already here.
///
/// Three states, where the prototype draws one. The design shows the middle of
/// the story: six matched contacts, three of them ticked. The other two are
/// what the running app shows most of the time, and leaving them out would
/// mean a screen that works only for the lucky.
///
///   * **ask** — nothing has been read yet. One button, and the line about
///     what happens to the numbers.
///   * **matched** — the design's screen, with the count read off the result.
///   * **none** — the contacts were read and nobody matched. Says so, and
///     leaves Continue as the way out.
///
/// The privacy line is not the design's. The prototype says "We don't upload
/// your contacts. Matching happens on your phone." — and that cannot be true
/// of any scheme that finds friends among strangers, because the phone has no
/// way to know who else has an account without asking. What is true is that
/// the numbers leave scrambled, the names never leave at all, and nothing is
/// kept. That is what this says (D127).
class OnboardingFriendsStep extends StatelessWidget {
  const OnboardingFriendsStep({
    super.key,
    required this.matches,
    required this.selectedIds,
    required this.hasSearched,
    required this.isSearching,
    required this.onFindFriends,
    required this.onToggle,
    this.error,
  });

  /// The contacts who turned out to have accounts. Empty before the search and
  /// empty after a search that found nobody — [hasSearched] tells them apart.
  final List<FriendProfile> matches;
  final Set<String> selectedIds;
  final bool hasSearched;
  final bool isSearching;
  final VoidCallback onFindFriends;
  final ValueChanged<String> onToggle;
  final String? error;

  static const String privacyLine =
      'We send scrambled numbers, never names, and we don\'t keep them.';

  /// "Six of your contacts are already on Ngap" — the design's own sentence,
  /// with its number made honest. Spelled out to nine because a sentence that
  /// opens with a digit reads like a receipt.
  static const _spelled = <String>[
    'None',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
  ];

  String get _lede {
    if (!hasSearched) {
      return 'Ngap is better with people you already eat with. We can check '
          'which of your contacts are here. Optional, always.';
    }
    if (matches.isEmpty) {
      return 'Nobody in your contacts is on Ngap yet. You can add friends '
          'later from the You tab.';
    }
    final count = matches.length;
    final head = count < _spelled.length ? _spelled[count] : '$count';
    final are = count == 1 ? 'is' : 'are';
    final contact = count == 1 ? 'contact' : 'contacts';
    return '$head of your $contact $are already on Ngap. Add them and you can '
        'plan a dinner in two taps. Optional, always.';
  }

  @override
  Widget build(BuildContext context) {
    final failure = error;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _StepHeading(title: 'Eat with people', subtitle: _lede),
        const SizedBox(height: AppOnboardingGaps.section),
        if (!hasSearched) ...[
          AppPrimaryButton(
            label: isSearching ? 'Checking...' : 'Find friends from contacts',
            icon: Icons.contacts_rounded,
            expand: true,
            onPressed: isSearching ? null : onFindFriends,
          ),
          const SizedBox(height: AppOnboardingGaps.item),
        ],
        if (failure != null) ...[
          Text(
            failure,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kAccentEmber,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: AppOnboardingGaps.item),
        ],
        for (final person in matches)
          PersonRow(
            profile: person,
            selected: selectedIds.contains(person.id),
            onTap: () => onToggle(person.id),
          ),
        if (matches.isNotEmpty)
          const SizedBox(height: AppOnboardingGaps.section),
        // The line sits under whichever state is showing, because it is true
        // of all three: before the search it says what will happen, after it
        // says what did.
        Text(
          privacyLine,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kCreamMuted,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}
