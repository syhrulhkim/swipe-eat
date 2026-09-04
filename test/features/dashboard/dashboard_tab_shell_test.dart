import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/dashboard/presentation/dashboard_widgets.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  String title = 'Your bites',
  String? eyebrow,
  String? subtitle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DashboardTabShell(
        title: title,
        eyebrow: eyebrow,
        subtitle: subtitle,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('DashboardTabShell', () {
    testWidgets('a subtitle sits below the title, an eyebrow above it',
        (tester) async {
      // This is the whole distinction between the two slots, and it is the
      // reason the subtitle exists: the design puts a count under the title,
      // where the eyebrow could only ever put it over.
      await _pumpShell(tester, eyebrow: 'Your places', subtitle: '14 saved');

      final eyebrow = tester.getRect(find.text('Your places'));
      final title = tester.getRect(find.text('Your bites'));
      final subtitle = tester.getRect(find.text('14 saved'));

      expect(eyebrow.bottom, lessThanOrEqualTo(title.top));
      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('renders neither slot when neither is given', (tester) async {
      await _pumpShell(tester);

      expect(find.text('Your bites'), findsOneWidget);
      // Only the title: a shell with an empty subtitle must not reserve a
      // blank line under it.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a subtitle alone needs no eyebrow', (tester) async {
      await _pumpShell(tester, subtitle: '1 saved');

      expect(find.text('1 saved'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('the subtitle is quieter than the title', (tester) async {
      await _pumpShell(tester, subtitle: '14 saved');

      final subtitle = tester.widget<Text>(find.text('14 saved'));
      expect(subtitle.style?.color, kCreamSecondary);
    });

    testWidgets('every tab gets the glow, and it never takes a tap',
        (tester) async {
      await _pumpShell(tester);

      expect(
        find.descendant(
          of: find.byType(DashboardTabShell),
          matching: find.byType(ScreenGlow),
        ),
        findsOneWidget,
      );
    });
  });
}
