import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/restaurants/presentation/discovery_filter_sheet.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../onboarding/fake_onboarding_repository.dart';

void main() {
  group('DiscoveryFilterSheet', () {
    late AuthController auth;
    late FakeAuthRepository authRepository;

    /// The last payload the sheet handed its writer, or null if it never got
    /// that far.
    int? sentRadiusKm;
    var applied = 0;

    Future<void> pumpSheet(
      WidgetTester tester, {
      int? searchRadiusKm = 10,
      TextScaler textScaler = TextScaler.noScaling,
      Size viewport = const Size(390, 844),
    }) async {
      sentRadiusKm = null;
      applied = 0;

      authRepository = FakeAuthRepository()
        ..sessionPresent = true
        ..profile = AppUser(
          id: 'a4c0a0f0-0000-4000-8000-000000000001',
          name: 'Aisyah',
          email: 'aisyah@ngap.test',
          onboardedAt: DateTime(2026, 3, 4),
          searchRadiusKm: searchRadiusKm,
        );
      auth = AuthController(authRepository);
      final controller = auth;
      final repository = authRepository;
      addTearDown(() async {
        controller.dispose();
        await repository.dispose();
      });
      await auth.bootstrap();

      useViewport(tester, viewport);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Scaffold(
            body: DiscoveryFilterSheet(
              authController: auth,
              catalog: FakeOnboardingRepository(),
              onApply: ({
                required List<int> cuisineIds,
                required List<int> dietaryTagIds,
                double? minRating,
                int? searchRadiusKm,
              }) async {
                applied++;
                sentRadiusKm = searchRadiusKm;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the radius is answered here, not only in Settings',
        (tester) async {
      await pumpSheet(tester);

      expect(find.text('Search radius'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget);
      // The button repeats the count back before the deck is thrown away.
      expect(find.text('Apply 1 limit'), findsOneWidget);
    });

    testWidgets('Apply carries the radius the slider was left on',
        (tester) async {
      await pumpSheet(tester);

      // Tapping the left edge of a discrete slider takes it to its first
      // stop, which is 1 km — the same value the slider's start anchor
      // names, hence two matches.
      final slider = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(slider.left + 2, slider.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('1 km'), findsNWidgets(2));

      await tester.tap(find.text('Apply 1 limit'));
      await tester.pumpAndSettle();

      expect(applied, 1);
      expect(sentRadiusKm, 1);
    });

    testWidgets('an untouched radius reaches the writer unchanged',
        (tester) async {
      await pumpSheet(tester, searchRadiusKm: 30);

      await tester.tap(find.text('Apply 1 limit'));
      await tester.pumpAndSettle();

      expect(sentRadiusKm, 30);
    });

    testWidgets('Clear all lets the deck look any distance', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      // The value and the slider's end anchor now say the same thing.
      expect(find.text('Any distance'), findsNWidgets(2));

      await tester.tap(find.text('Apply with no limits'));
      await tester.pumpAndSettle();

      expect(sentRadiusKm, isNull);
    });

    testWidgets('nothing to clear leaves Clear all dead', (tester) async {
      await pumpSheet(tester, searchRadiusKm: null);

      final clearAll = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Clear all'),
          matching: find.byType(TextButton),
        ),
      );

      expect(clearAll.onPressed, isNull);
      expect(find.text('Apply with no limits'), findsOneWidget);
    });

    testWidgets('a rating limit warns that it will empty the deck',
        (tester) async {
      await pumpSheet(tester);

      expect(find.textContaining('empty the deck'), findsNothing);

      await tester.tap(find.text('★ 4.0+'));
      await tester.pumpAndSettle();

      expect(find.textContaining('empty the deck'), findsOneWidget);
    });

    testWidgets('the sheet holds together at 320 px and double text size',
        (tester) async {
      await pumpSheet(
        tester,
        viewport: const Size(320, 720),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
