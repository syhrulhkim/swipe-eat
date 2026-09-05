import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_card.dart';
import 'package:swipe_eat/features/restaurants/presentation/swipe_card.dart';

RestaurantCard card({
  OpeningHours hours = OpeningHours.unknown,
  int? priceFrom,
  bool? isHalal,
  String? neighbourhood,
  String tag = 'Malay',
}) {
  return RestaurantCard(
    id: 1,
    title: 'Warung Kak Ros',
    tag: tag,
    details: '',
    color: kSurfacePanel,
    rating: 0,
    latitude: 0,
    longitude: 0,
    reviewName: '',
    reviewText: '',
    reviews: const [],
    imageUrls: const [],
    hours: hours,
    priceFrom: priceFrom,
    isHalal: isHalal,
    neighbourhood: neighbourhood,
  );
}

// 8 pm on a Monday.
DateTime eightPm() => DateTime(2026, 9, 7, 20);

Future<void> pumpBlock(
  WidgetTester tester,
  RestaurantCard data, {
  VoidCallback? onTap,
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        body: Center(
          child: SizedBox(
            width: width,
            child: RestaurantInfoBlock(
              data: data,
              distanceText: '1.2 km',
              now: eightPm(),
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RestaurantInfoBlock', () {
    testWidgets('shows the open chip, cuisine and halal when known', (tester) async {
      await pumpBlock(
        tester,
        card(
          hours: const OpeningHours(
            opensAtMinutes: 17 * 60 + 30,
            closesAtMinutes: 2 * 60,
          ),
          isHalal: true,
          priceFrom: 8,
          neighbourhood: 'Kampung Baru',
        ),
      );

      expect(find.text('Open till 2 am'), findsOneWidget);
      expect(find.text('Malay'), findsOneWidget);
      expect(find.text('Halal'), findsOneWidget);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
      expect(find.text('From RM 8'), findsOneWidget);
      expect(find.textContaining('Kampung Baru'), findsOneWidget);
    });

    testWidgets('the open chip is the only fresh-tinted thing', (tester) async {
      await pumpBlock(
        tester,
        card(
          hours: const OpeningHours(
            opensAtMinutes: 9 * 60,
            closesAtMinutes: 23 * 60,
          ),
        ),
      );
      final chips = tester.widgetList<AppTagChip>(find.byType(AppTagChip));
      expect(chips.where((chip) => chip.fresh).length, 1);
      expect(chips.where((chip) => !chip.fresh).length, 1);
    });

    testWidgets('hides what it does not know', (tester) async {
      await pumpBlock(tester, card(tag: ''));

      expect(find.byType(AppTagChip), findsNothing);
      expect(find.textContaining('RM'), findsNothing);
      expect(find.textContaining('Open'), findsNothing);
      expect(find.text('1.2 km'), findsOneWidget);
    });

    testWidgets('a closed place carries no open chip', (tester) async {
      await pumpBlock(
        tester,
        card(
          hours: const OpeningHours(
            opensAtMinutes: 9 * 60,
            closesAtMinutes: 17 * 60,
          ),
        ),
      );
      expect(find.textContaining('Open'), findsNothing);
      expect(find.textContaining('Closed'), findsNothing);
    });

    testWidgets('a tap opens the restaurant and reads as one button', (tester) async {
      var taps = 0;
      await pumpBlock(tester, card(priceFrom: 8), onTap: () => taps++);

      await tester.tap(find.text('Warung Kak Ros'));
      expect(taps, 1);

      final semantics = tester.getSemantics(find.byType(RestaurantInfoBlock));
      expect(semantics.label, contains('Warung Kak Ros'));
      expect(semantics.label, contains('From RM 8'));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('does not overflow on a narrow phone with a long name', (tester) async {
      const data = RestaurantCard(
        id: 1,
        title: 'Restoran Nasi Kandar Pelita Kampung Baru Cawangan Utama',
        tag: 'Mamak and North Indian',
        details: '',
        color: kSurfacePanel,
        rating: 0,
        latitude: 0,
        longitude: 0,
        reviewName: '',
        reviewText: '',
        reviews: [],
        imageUrls: [],
        hours: OpeningHours(opensAtMinutes: 0, closesAtMinutes: 0),
        priceFrom: 1200,
        isHalal: true,
        neighbourhood: 'Bandar Baru Permas Jaya Seri Alam',
      );
      await pumpBlock(tester, data, width: 280);
      expect(tester.takeException(), isNull);
    });
  });
}
