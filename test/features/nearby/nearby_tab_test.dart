import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/nearby/domain/nearby_format.dart';
import 'package:swipe_eat/features/nearby/presentation/nearby_pin.dart';
import 'package:swipe_eat/features/nearby/presentation/nearby_tab.dart';
import 'package:swipe_eat/features/nearby/state/nearby_controller.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/state/deck_handoff.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../profile/fake_profile_repository.dart';
import 'fake_nearby_repository.dart';

const _phone = Size(390, 844);
const _narrow = Size(320, 640);

const _user = AppUser(
  id: 'user-1',
  name: 'Aisyah',
  email: 'aisyah@example.com',
);

OpeningHours _hours(String opens, String closes) {
  return OpeningHours.fromJson({
    'opens_at': opens,
    'closes_at': closes,
    'closed_dow': const <int>[],
  });
}

void main() {
  late FakeNearbyRepository repository;
  late FakeAuthRepository auth;
  late AuthController authController;
  late DeckHandoff handoff;
  late LikesController likes;

  setUp(() {
    repository = FakeNearbyRepository();
    auth = FakeAuthRepository();
    authController = AuthController(auth)..applyUser(_user);
    handoff = DeckHandoff();
    likes = LikesController(followAuthChanges: false);
  });

  tearDown(() async {
    await auth.dispose();
  });

  NearbyController buildController({bool realFix = true}) {
    return NearbyController(
      authController: authController,
      repository: repository,
      profiles: FakeProfileRepository(_user),
      handoff: handoff,
      resolvePosition: () async =>
          realFix ? testPosition() : fallbackUserPosition(),
      // A Tuesday evening, so an "Open" place really is open.
      now: () => DateTime(2026, 9, 8, 19, 41),
    );
  }

  /// Loads the controller first, then mounts the tab around it, so nothing in
  /// the widget tree is waiting on a future while assertions run.
  Future<NearbyController> pumpTab(
    WidgetTester tester, {
    Size viewport = _phone,
    bool realFix = true,
  }) async {
    useViewport(tester, viewport);
    final controller = buildController(realFix: realFix);
    await controller.load();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            backgroundColor: kBackgroundDark,
            body: NearbyTab(
              authController: authController,
              controller: controller,
              tileProvider: FakeTileProvider(),
              likes: likes,
            ),
          ),
        ),
        GoRoute(
          path: '/restaurant/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // One frame for layout, one for the tile fade-in; never pumpAndSettle —
    // the map keeps its own repaint schedule.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return controller;
  }

  void seedThreePlaces() {
    repository.rows = [
      testPlace(
        1,
        name: 'Banana Leaf House',
        tag: 'South Indian',
        distanceKm: 0.45,
        openNow: true,
        priceFrom: 8,
        hours: _hours('10:00:00', '23:00:00'),
        latitude: 1.4655,
        longitude: 103.7578,
      ),
      testPlace(
        2,
        name: 'Roti Canai Corner',
        tag: 'Mamak',
        distanceKm: 0.8,
        openNow: true,
        priceFrom: 12,
        hours: _hours('00:00:00', '00:00:00'),
        latitude: 1.4670,
        longitude: 103.7590,
      ),
      testPlace(
        3,
        name: 'Chili Pan Mee 88',
        tag: 'Dry noodles',
        distanceKm: 1.2,
        openNow: false,
        hours: _hours('07:00:00', '15:00:00'),
        latitude: 1.4640,
        longitude: 103.7565,
      ),
    ];
  }

  group('NearbyTab pins', () {
    testWidgets('a pin carries the name, the cuisine and the open line',
        (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      expect(find.text('Banana Leaf House'), findsOneWidget);
      expect(find.text('South Indian'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Open · 24 h'), findsOneWidget);
      // Closed since 3 pm, and opening again tomorrow morning.
      expect(find.text('Closed today'), findsOneWidget);
    });

    testWidgets('an open pin is fresh, a closed one is muted', (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      expect(tester.widget<Text>(find.text('Open')).style?.color, kFresh);
      expect(
        tester.widget<Text>(find.text('Closed today')).style?.color,
        kCreamMuted,
      );
    });

    testWidgets('every pin wears its distance as a badge', (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('800 m'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
    });

    testWidgets('the two closest pins are drawn big, the rest are not',
        (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      final pins = tester
          .widgetList<NearbyPin>(find.byType(NearbyPin))
          .toList();
      expect(pins.length, 3);

      final prominent = {
        for (final pin in pins) pin.place.id: pin.prominent,
      };
      expect(prominent[1], isTrue);
      expect(prominent[2], isTrue);
      expect(prominent[3], isFalse);
    });

    testWidgets('a saved place is bitten, an unsaved one is whole',
        (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      final bites = tester
          .widgetList<BiteNotch>(find.byType(BiteNotch))
          .map((notch) => notch.bitten)
          .toList();
      // Nothing is liked in this fixture, so no pin may be bitten.
      expect(bites, everyElement(isFalse));
    });

    testWidgets('tapping a pin opens that restaurant', (tester) async {
      // One pin only: three of them overlap at map scale, and this test is
      // about the tap target, not about how they are arranged.
      repository.rows = [
        testPlace(1, name: 'Banana Leaf House', distanceKm: 0.45),
      ];
      await pumpTab(tester);

      await tester.tap(find.byType(NearbyPin));
      await tester.pumpAndSettle();

      expect(find.text('detail 1'), findsOneWidget);
    });
  });

  group('NearbyTab radius stepper', () {
    testWidgets('opens at the default radius and names it', (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      expect(find.text('Away from you'), findsOneWidget);
      expect(find.textContaining('3.0'), findsOneWidget);
    });

    testWidgets('plus widens the circle and refetches', (tester) async {
      seedThreePlaces();
      final controller = await pumpTab(tester);

      await tester.tap(find.bySemanticsLabel('Larger radius'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.radiusKm, 5);
      expect(repository.queries.last.radiusKm, 5);
    });

    testWidgets('minus stops at the smallest step and shows metres',
        (tester) async {
      seedThreePlaces();
      final controller = await pumpTab(tester);

      for (var tap = 0; tap < 4; tap++) {
        await tester.tap(find.bySemanticsLabel('Smaller radius'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(controller.radiusKm, kNearbyRadiusSteps.first);
      expect(controller.canNarrow, isFalse);
      expect(find.text('500 m'), findsOneWidget);
    });
  });

  group('NearbyTab results bar', () {
    testWidgets('quotes the cheapest price, the open count and the total',
        (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      expect(find.text('From'), findsOneWidget);
      expect(find.text('RM 8'), findsOneWidget);
      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Swipe all 3'), findsOneWidget);
    });

    testWidgets('hides the price when no result names one', (tester) async {
      repository.rows = [testPlace(1, distanceKm: 0.2, openNow: true)];
      await pumpTab(tester);

      expect(find.text('From'), findsNothing);
      expect(find.text('Open now'), findsOneWidget);
    });

    testWidgets('there is no bar at all when the circle is empty',
        (tester) async {
      await pumpTab(tester);

      expect(find.textContaining('Swipe all'), findsNothing);
      expect(find.textContaining('Widen the circle'), findsOneWidget);
    });

    testWidgets('swipe-all hands every result to the deck', (tester) async {
      seedThreePlaces();
      await pumpTab(tester);

      await tester.tap(find.text('Swipe all 3'));
      await tester.pump();

      expect(handoff.revision, 1);
      expect(handoff.restaurants.map((row) => row.id).toList(), [1, 2, 3]);
      expect(handoff.label, 'Nearby · 3 places');
    });
  });

  group('NearbyTab layout', () {
    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      seedThreePlaces();
      await pumpTab(tester, viewport: _narrow);

      expect(tester.takeException(), isNull);
      expect(find.text('Swipe all 3'), findsOneWidget);
    });

    testWidgets('a long result count still fits the narrow bar',
        (tester) async {
      repository.rows = [
        for (var index = 0; index < 48; index++)
          testPlace(
            index,
            distanceKm: index * 0.05,
            openNow: true,
            priceFrom: 128,
            latitude: 1.4655 + index * 0.0001,
          ),
      ];
      await pumpTab(tester, viewport: _narrow);

      expect(tester.takeException(), isNull);
      expect(find.text('Swipe all 48'), findsOneWidget);
    });
  });

  group('NearbyTab without a location', () {
    testWidgets('asks for one in the design\'s voice', (tester) async {
      await pumpTab(tester, realFix: false);

      expect(find.text('Where are you eating?'), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      // No map, no stepper, no bar: there is nothing to centre any of them on.
      expect(find.byType(NearbyPin), findsNothing);
      expect(find.text('Away from you'), findsNothing);
      expect(find.textContaining('Swipe all'), findsNothing);
    });

    testWidgets('"Use my location" retries the lookup', (tester) async {
      await pumpTab(tester, realFix: false);

      // The device still refuses, so the state stands rather than flickering.
      await tester.tap(find.text('Use my location'));
      await tester.pump();

      expect(find.text('Where are you eating?'), findsOneWidget);
    });
  });

  group('NearbyTab filters', () {
    testWidgets('the filter button carries the active count', (tester) async {
      authController.applyUser(
        const AppUser(
          id: 'user-1',
          name: 'Aisyah',
          email: 'aisyah@example.com',
          filterCuisineIds: [3],
          filterMinRating: 4,
        ),
      );
      seedThreePlaces();
      await pumpTab(tester);

      // The badge count merges into the button's own semantics node, so the
      // label is matched by pattern rather than by equality.
      expect(find.bySemanticsLabel(RegExp('Filters')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });
}
