import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../../onboarding/models/onboarding_draft.dart';

/// The three controls behind "Any rules?".
///
/// They live here rather than inside the first-run step because the same three
/// questions are asked in three places — the wizard, the You tab's edit sheets
/// and Settings — and a preference that looks like a different control on the
/// screen where you change it does not read as the same preference.

/// The design's `.setrow`: a dark card holding one question, a header over a
/// full-width control. The switch variant is [PrefSwitchRow], which puts the
/// label and the control on one line instead.
class PrefRow extends StatelessWidget {
  const PrefRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        border: Border.all(color: kHairline),
      ),
      child: child,
    );
  }
}

/// `.setrow.inline` — a title, a line of explanation, and a switch.
///
/// The whole row is the target, not just the 50 px switch: a rule you can only
/// change by hitting a thumb is a rule people leave wrong.
class PrefSwitchRow extends StatelessWidget {
  const PrefSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      hint: subtitle,
      toggled: value,
      // Excluding the children keeps the announcement one sentence instead of
      // three fragments; that also drops the InkWell's action, so the tap is
      // re-declared here (D83).
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: Material(
        color: kSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPanel),
          side: const BorderSide(color: kHairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusPanel),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: kTextFontFamily,
                          fontSize: kFontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: kTextOnPhoto,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: kTextFontFamily,
                          fontSize: kFontSizeSmall,
                          color: kCreamSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PrefSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's `.switch`: a 50×30 track that turns ember, with a cream thumb
/// that slides its own width. Not a Material [Switch] — that one draws an
/// outline, a different thumb size and a different travel, and the difference
/// is visible next to anything else on these screens.
class PrefSwitch extends StatelessWidget {
  const PrefSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Set only when the switch stands alone; inside a [PrefSwitchRow] the row
  /// carries the label and the switch must not announce a second one.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const inset = (kSwitchHeight - kSwitchThumbSize) / 2;

    Widget track = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: SizedBox(
        // The track is 30 px tall; the touch target has to be 44.
        height: kUtilityButtonSize,
        width: kSwitchWidth,
        child: Center(
          child: AnimatedContainer(
            duration: kMotionDuration,
            curve: kMotionEase,
            width: kSwitchWidth,
            height: kSwitchHeight,
            decoration: BoxDecoration(
              color: value ? kAccentEmber : kSurfacePanel,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(color: value ? kAccentEmber : kHairline),
            ),
            child: AnimatedAlign(
              duration: kMotionDuration,
              curve: kMotionEase,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: inset),
                child: Container(
                  width: kSwitchThumbSize,
                  height: kSwitchThumbSize,
                  decoration: const BoxDecoration(
                    color: kAccentCream,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final label = semanticLabel;
    if (label == null) {
      // The row above already declares the switch; this one is decoration as
      // far as a screen reader is concerned.
      return ExcludeSemantics(child: track);
    }

    return Semantics(
      label: label,
      toggled: value,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: track,
    );
  }
}

/// The design's `.seg`: a panel-coloured pill holding equal buttons, the
/// chosen one filled ember. Used for spice, and shaped so a null selection is
/// a state it can draw — the first-run step is skippable, so "not answered"
/// has to look different from "Mild".
class PrefSegmented<T> extends StatelessWidget {
  const PrefSegmented({
    super.key,
    required this.options,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  final List<T> options;
  final String Function(T option) labelOf;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Horizontal only: the vertical padding lives inside each button, so
      // the finger gets the design's 4 px of track as target rather than as
      // dead space. Same pixels drawn, a 44 pt hit box instead of a 36 (§7f).
      padding: const EdgeInsets.symmetric(horizontal: kSegmentTrackPadding),
      decoration: BoxDecoration(
        color: kSurfacePanel,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: kSegmentTrackPadding),
            Expanded(
              child: _SegmentButton(
                label: labelOf(options[index]),
                selected: options[index] == value,
                onTap: () => onChanged(options[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      // See D83: excluding the child's semantics also drops the tap action.
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // Drawn at 36, tapped at 44 — the filter chips' rule (§7f). The
        // padding is the track's own, moved inside the target: without it
        // these four are the smallest touchable things in the app.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSegmentTrackPadding),
          child: AnimatedContainer(
            duration: kMotionDuration,
            curve: kMotionEase,
            height: kSegmentHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kAccentEmber : Colors.transparent,
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeSmall,
                  fontWeight: FontWeight.w600,
                  color: selected ? kOnAccent : kCreamSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header of a stacked [PrefRow]: a title on the left and either a quiet
/// caption or a live read-out on the right.
class PrefRowHeader extends StatelessWidget {
  const PrefRowHeader({
    super.key,
    required this.title,
    this.caption,
    this.output,
  });

  final String title;

  /// The grey line that explains the question ("How hot is too hot?").
  final String? caption;

  /// The display-face read-out over a range ("RM 10–40").
  final String? output;

  @override
  Widget build(BuildContext context) {
    final captionText = caption;
    final outputText = output;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeBody,
              fontWeight: FontWeight.w600,
              color: kTextOnPhoto,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (captionText != null)
          Flexible(
            child: Text(
              captionText,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeSmall,
                color: kCreamSecondary,
              ),
            ),
          ),
        if (outputText != null)
          // Flexible and fitted, like the stat tiles' numbers: "RM 10–40" beside
          // "Budget per person" does not fit a 320 px screen at double text
          // size, and a read-out that overflows is one you cannot read at all.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                outputText,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: kDisplayFontFamily,
                  fontSize: kFontSizeRangeOutput,
                  fontWeight: FontWeight.w700,
                  color: kTextOnPhoto,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The spice question as one card: header plus the four-step segment.
class PrefSpiceRow extends StatelessWidget {
  const PrefSpiceRow({super.key, required this.value, required this.onChanged});

  final SpiceLevel? value;
  final ValueChanged<SpiceLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return PrefRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PrefRowHeader(title: 'Spice', caption: 'How hot is too hot?'),
          const SizedBox(height: 12),
          PrefSegmented<SpiceLevel>(
            options: SpiceLevel.values,
            labelOf: (option) => option.label,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The budget question as one card: header with a live read-out, the range
/// itself, and the two end labels under it.
///
/// [max] null is "and up" — the upper thumb parked at [kBudgetCeiling].
class PrefBudgetRow extends StatelessWidget {
  const PrefBudgetRow({
    super.key,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  final int? min;
  final int? max;

  /// Reports the pair. A null upper end means the cap was released.
  ///
  /// Fires on every division the thumb crosses, so a caller that writes here
  /// writes a dozen times per drag. Callers that persist should keep the pair
  /// locally from this and save from [onChangeEnd].
  final void Function(int min, int? max) onChanged;

  /// The same pair, once, when the finger lifts. Null for callers that keep
  /// the answer in memory until a screen of their own is finished — the
  /// first-run step and the You tab's sheet both do.
  final void Function(int min, int? max)? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final lower = (min ?? kBudgetDefaultMin).toDouble();
    final upper = (max ?? kBudgetCeiling).toDouble();

    return PrefRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrefRowHeader(
            title: 'Budget per person',
            output: budgetRangeLabel(min ?? kBudgetDefaultMin, max),
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kAccentEmber,
              inactiveTrackColor: kSurfacePanel,
              thumbColor: kAccentCream,
              overlayColor: kGlass,
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10,
              ),
              trackHeight: 4,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: RangeSlider(
              values: RangeValues(lower, upper),
              min: kBudgetFloor.toDouble(),
              max: kBudgetCeiling.toDouble(),
              divisions: (kBudgetCeiling - kBudgetFloor) ~/ kBudgetStep,
              onChanged: (values) => _report(values, onChanged),
              onChangeEnd: onChangeEnd == null
                  ? null
                  : (values) => _report(values, onChangeEnd!),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RangeEnd('RM $kBudgetFloor'),
              _RangeEnd('RM $kBudgetCeiling+'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Turns a pair of thumb positions into the pair the profile stores.
void _report(RangeValues values, void Function(int min, int? max) sink) {
  final newMin = values.start.round();
  final newMax = values.end.round();
  sink(
    newMin,
    // The top stop releases the ceiling rather than setting one.
    newMax >= kBudgetCeiling ? null : newMax,
  );
}

class _RangeEnd extends StatelessWidget {
  const _RangeEnd(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: kTextFontFamily,
        fontSize: kFontSizeMicro,
        color: kCreamMuted,
      ),
    );
  }
}
