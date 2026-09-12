import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';
import 'package:swipe_eat/features/profile/presentation/preference_controls.dart';

import '../../support/widget_test_support.dart';

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 640);

const TextScaler _hugeTextScale = TextScaler.linear(2);

void main() {
  Future<void> pumpControl(
    WidgetTester tester,
    Widget child, {
    Size viewport = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    useViewport(tester, viewport);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              backgroundColor: kBackgroundDark,
              // A list, because that is what every caller is: the first-run
              // step, Settings and the edit sheets all scroll.
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [child],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PrefSwitchRow', () {
    testWidgets('reads as one toggle, not three fragments', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: true,
          onChanged: (_) {},
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Halal only')),
        isSemantics(
          label: 'Halal only',
          hint: 'Hides places without halal certification',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('an off switch announces its off state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Vegetarian options',
          subtitle: 'Must have a real veg section',
          value: false,
          onChanged: (_) {},
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Vegetarian options')),
        isSemantics(hasToggledState: true, isToggled: false),
      );

      handle.dispose();
    });

    testWidgets('a screen reader can flip it, not just read it',
        (tester) async {
      // D83: `excludeSemantics: true` drops the InkWell's action, so the row
      // re-declares it. A row that reads correctly and cannot be activated
      // fails silently, which is why this drives the action rather than
      // asserting the flag alone.
      final handle = tester.ensureSemantics();
      bool? reported;
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: false,
          onChanged: (value) => reported = value,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Halal only'));
      await tester.pump();

      expect(reported, isTrue);
      handle.dispose();
    });

    testWidgets('the whole row is the target, not just the thumb',
        (tester) async {
      bool? reported;
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: true,
          onChanged: (value) => reported = value,
        ),
      );

      await tester.tap(find.text('Hides places without halal certification'));
      await tester.pump();

      expect(reported, isFalse);
    });

    testWidgets('clears a 44 pt target', (tester) async {
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: false,
          onChanged: (_) {},
        ),
        viewport: _narrowViewport,
      );

      expect(
        tester.getSize(find.byType(PrefSwitchRow)).height,
        greaterThanOrEqualTo(kUtilityButtonSize),
      );
      // The switch beside it is a target in its own right: the design draws a
      // 30 px track and promises a 44 px touch area around it.
      expect(
        tester.getSize(find.byType(PrefSwitch)).height,
        greaterThanOrEqualTo(kUtilityButtonSize),
      );
    });
  });

  group('PrefSwitch on its own', () {
    testWidgets('carries its own label only when it stands alone',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpControl(
        tester,
        PrefSwitch(
          value: true,
          onChanged: (_) {},
          semanticLabel: 'Halal only',
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Halal only')),
        isSemantics(
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('inside a row it announces nothing of its own', (tester) async {
      // Otherwise the row and the switch would be read out as two controls
      // that happen to share a state.
      final handle = tester.ensureSemantics();
      await pumpControl(
        tester,
        PrefSwitchRow(
          title: 'Halal only',
          subtitle: 'Hides places without halal certification',
          value: true,
          onChanged: (_) {},
        ),
      );

      expect(find.bySemanticsLabel('Halal only'), findsOneWidget);

      handle.dispose();
    });
  });

  group('PrefSegmented', () {
    Widget spice({
      SpiceLevel? value,
      ValueChanged<SpiceLevel>? onChanged,
    }) {
      return PrefSpiceRow(
        value: value,
        onChanged: onChanged ?? (_) {},
      );
    }

    testWidgets('draws no selection until the question is answered',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpControl(tester, spice());

      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
          ),
          reason: label,
        );
      }

      handle.dispose();
    });

    testWidgets('marks exactly the chosen option as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpControl(tester, spice(value: SpiceLevel.pedas));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Pedas')),
        isSemantics(isSelected: true),
      );
      for (final label in const ['Mild', 'Medium', 'Bring it']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isSelected: false),
          reason: label,
        );
      }

      handle.dispose();
    });

    testWidgets('a screen reader can choose an option', (tester) async {
      final handle = tester.ensureSemantics();
      SpiceLevel? reported;
      await pumpControl(
        tester,
        spice(onChanged: (value) => reported = value),
      );

      tester.semantics.tap(find.semantics.byLabel('Bring it'));
      await tester.pump();

      expect(reported, SpiceLevel.bringIt);
      handle.dispose();
    });

    testWidgets('every segment clears a 44 pt target', (tester) async {
      // The design draws the pill 36 px tall (§7e); a finger still needs 44,
      // the same way the filter chips are drawn at 36 and tapped at 44 (§7f).
      // Without the difference the four spice buttons are the smallest
      // targets in the app.
      await pumpControl(tester, spice(), viewport: _narrowViewport);

      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        expect(
          tester
              .getSize(find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(GestureDetector),
                  )
                  .first)
              .height,
          greaterThanOrEqualTo(kUtilityButtonSize),
          reason: label,
        );
      }
    });

    testWidgets('keeps the pill 36 px whatever the target around it is',
        (tester) async {
      await pumpControl(tester, spice(value: SpiceLevel.mild));

      final pill = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((container) =>
              container.constraints?.maxHeight == kSegmentHeight);
      expect(pill, hasLength(SpiceLevel.values.length));
    });

    testWidgets('taps report the option under the finger', (tester) async {
      final tapped = <SpiceLevel>[];
      await pumpControl(
        tester,
        spice(onChanged: tapped.add),
      );

      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(
        tapped.map((level) => level.level).toList(),
        [1, 2, 3, 4],
        reason: 'the four labels map to the values the column stores',
      );
    });
  });

  group('PrefBudgetRow', () {
    testWidgets('opens on the range the prototype shows', (tester) async {
      await pumpControl(
        tester,
        PrefBudgetRow(
          min: kBudgetDefaultMin,
          max: kBudgetDefaultMax,
          onChanged: (_, __) {},
        ),
      );

      expect(find.text('RM 10–40'), findsOneWidget);
      expect(find.text('RM 5'), findsOneWidget);
      expect(find.text('RM 100+'), findsOneWidget);
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        40,
      );
    });

    testWidgets('the top stop releases the cap rather than setting one',
        (tester) async {
      int? reportedMin;
      int? reportedMax;
      var calls = 0;
      await pumpControl(
        tester,
        PrefBudgetRow(
          min: kBudgetDefaultMin,
          max: kBudgetDefaultMax,
          onChanged: (min, max) {
            calls++;
            reportedMin = min;
            reportedMax = max;
          },
        ),
      );

      // Driven through the callback: landing a range thumb on an exact
      // division by gesture is brittle, and the mapping is the subject.
      tester.widget<Slider>(find.byType(Slider)).onChanged!(
        100,
      );
      await tester.pump();

      expect(calls, 1);
      expect(reportedMin, 10);
      expect(reportedMax, isNull,
          reason: 'a stored 100 would hide every place priced above it');
    });

    testWidgets('a ceiling below the top stop is reported as itself',
        (tester) async {
      int? reportedMax;
      await pumpControl(
        tester,
        PrefBudgetRow(
          min: kBudgetDefaultMin,
          max: kBudgetDefaultMax,
          onChanged: (_, max) => reportedMax = max,
        ),
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(
        60,
      );
      await tester.pump();

      expect(reportedMax, 60);
    });

    testWidgets('a released cap reads "and up"', (tester) async {
      await pumpControl(
        tester,
        PrefBudgetRow(min: 10, max: null, onChanged: (_, __) {}),
      );

      expect(find.text('RM 10+'), findsOneWidget);
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        kBudgetCeiling.toDouble(),
        reason: 'the upper thumb parks at the top stop when there is no cap',
      );
    });

    testWidgets('the slider clears a 44 pt target', (tester) async {
      await pumpControl(
        tester,
        PrefBudgetRow(
          min: kBudgetDefaultMin,
          max: kBudgetDefaultMax,
          onChanged: (_, __) {},
        ),
        viewport: _narrowViewport,
      );

      expect(
        tester.getSize(find.byType(Slider)).height,
        greaterThanOrEqualTo(kUtilityButtonSize),
      );
    });
  });

  group('preference controls layout', () {
    testWidgets('the three questions survive 320 px at double text size',
        (tester) async {
      await pumpControl(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrefSwitchRow(
              title: 'Halal only',
              subtitle: 'Hides places without halal certification',
              value: true,
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),
            PrefSpiceRow(value: SpiceLevel.bringIt, onChanged: (_) {}),
            const SizedBox(height: 10),
            PrefBudgetRow(
              min: kBudgetDefaultMin,
              max: kBudgetDefaultMax,
              onChanged: (_, __) {},
            ),
          ],
        ),
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the segment labels shrink rather than overflow',
        (tester) async {
      // "Bring it" in a quarter of a 320 px pill has no room to grow, so the
      // label is fitted down instead of clipped.
      await pumpControl(
        tester,
        PrefSpiceRow(value: SpiceLevel.mild, onChanged: (_) {}),
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Bring it'), findsOneWidget);
    });
  });
}
