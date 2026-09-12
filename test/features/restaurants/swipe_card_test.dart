import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/core/ui/progress_dots.dart';
import 'package:swipe_eat/features/restaurants/data/tiktok_player_factory.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_card.dart';
import 'package:swipe_eat/features/restaurants/presentation/swipe_card.dart';

import '../../support/widget_test_support.dart';

RestaurantCard card({
  OpeningHours hours = OpeningHours.unknown,
  int? priceFrom,
  bool? isHalal,
  String? neighbourhood,
  String tag = 'Malay',
  String? videoUrl,
  List<String> imageUrls = const [],
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
    imageUrls: imageUrls,
    videoUrl: videoUrl,
    hours: hours,
    priceFrom: priceFrom,
    isHalal: isHalal,
    neighbourhood: neighbourhood,
  );
}

// 8 pm on a Monday.
DateTime eightPm() => DateTime(2026, 9, 7, 20);

/// The card's own surface: the one box rounded to the card radius. Everything
/// else it draws is a pill or square.
final Finder cardSurface = find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).borderRadius ==
          BorderRadius.circular(kRadiusCard),
  description: 'Container(borderRadius: kRadiusCard)',
);

/// The [Opacity] a stamp is wrapped in — the nearest one above its word.
double stampOpacity(WidgetTester tester, String label) {
  return tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .first,
      )
      .opacity;
}

Future<void> pumpStamps(
  WidgetTester tester, {
  required double like,
  required double nope,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 26,
              right: 22,
              child: SwipeStamp(
                label: 'Ngap!',
                color: kAccentEmber,
                angle: -12,
                opacity: like,
              ),
            ),
            Positioned(
              top: 26,
              left: 22,
              child: SwipeStamp(
                label: 'Skip',
                color: kAccentCream,
                angle: 12,
                opacity: nope,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pumps a whole [SwipeCard] in a card-shaped box.
///
/// A card with a clip is handed a player future that never completes: the
/// view then paints its spinner and never reaches for a WebView, so the test
/// stays off the platform channels and off the network. Photos are left empty
/// for the same reason — [Image.network] would be a real request.
Future<void> pumpCard(
  WidgetTester tester,
  RestaurantCard data, {
  bool isBehind = false,
  bool videoLent = false,
  bool autoplay = true,
  VoidCallback? onPlay,
  VoidCallback? onTap,
  VoidCallback? onOpenDetail,
}) async {
  // A phone, not the 800x600 default: a 620 pt card does not fit in 600.
  useViewport(tester, const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        body: Center(
          child: SizedBox(
            width: 360,
            height: 620,
            child: SwipeCard(
              data: data,
              distanceText: '1.2 km',
              onTap: onTap ?? () {},
              onOpenDetail: onOpenDetail ?? () {},
              tiktokPlayerFuture: data.videoUrl == null
                  ? null
                  : Completer<TikTokPlayerHandle>().future,
              videoLent: videoLent,
              autoplay: autoplay,
              onPlay: onPlay,
              isBehind: isBehind,
              clock: eightPm,
            ),
          ),
        ),
      ),
    ),
  );
  // Never pumpAndSettle: the pending player leaves a spinner turning forever.
  await tester.pump();
}

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

/// The widths of the dots a [ProgressDots] drew, in order.
///
/// Scoped to the row, because the card paints plenty of other boxes, and read
/// off the constraints rather than the laid-out size, which would include each
/// dot's own right margin.
List<double> dotWidths(WidgetTester tester, Type dot) {
  final dots = find.descendant(
    of: find.byType(ProgressDots),
    matching: find.byType(dot),
  );
  return tester.widgetList<Widget>(dots).map((widget) {
    final constraints = widget is AnimatedContainer
        ? widget.constraints
        : (widget as Container).constraints;
    return constraints!.maxWidth;
  }).toList();
}

void main() {
  // Photos are `Image.network`, and flutter_test answers every request with a
  // 400 unless this is installed (D72).
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());

  group('RestaurantInfoBlock', () {
    testWidgets('shows the open chip, cuisine and halal when known',
        (tester) async {
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

    testWidgets('a tap opens the restaurant and reads as one button',
        (tester) async {
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

    testWidgets('the label reads the chips too, and only an open chip',
        (tester) async {
      await pumpBlock(
        tester,
        card(
          hours: const OpeningHours(
            opensAtMinutes: 9 * 60,
            closesAtMinutes: 17 * 60,
          ),
          isHalal: true,
        ),
      );
      final closed = tester.getSemantics(find.byType(RestaurantInfoBlock));
      expect(closed.label, contains('Malay'));
      expect(closed.label, contains('Halal'));
      expect(closed.label, isNot(contains('Closed')));
      expect(closed.label, isNot(contains('Open')));

      await pumpBlock(
        tester,
        card(
          hours: const OpeningHours(
            opensAtMinutes: 17 * 60,
            closesAtMinutes: 23 * 60,
          ),
        ),
      );
      final open = tester.getSemantics(find.byType(RestaurantInfoBlock));
      expect(open.label, contains('Open till 11 pm'));
    });

    testWidgets('does not overflow at 320 px with accessibility text',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              backgroundColor: kBackgroundDark,
              body: Center(
                child: SizedBox(
                  width: 320 - 40,
                  child: RestaurantInfoBlock(
                    data: card(
                      priceFrom: 1200,
                      neighbourhood: 'Bandar Baru Permas Jaya',
                    ),
                    distanceText: '12.4 km',
                    now: eightPm(),
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a narrow phone with a long name',
        (tester) async {
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

    testWidgets('a caption-length cuisine tag is cut, not spilled',
        (tester) async {
      // The tag comes off a TikTok caption, so nothing bounds its length.
      await pumpBlock(
        tester,
        card(tag: 'Nasi kandar, mamak, North Indian and Penang street food'),
        width: 280,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppTagChip)).width,
        lessThanOrEqualTo(280),
      );
    });
  });

  group('SwipeCard', () {
    testWidgets('is a rounded surface with the info block low on it',
        (tester) async {
      await pumpCard(tester, card(priceFrom: 8, neighbourhood: 'Masai'));

      expect(cardSurface, findsOneWidget);
      final decoration =
          tester.widget<Container>(cardSurface).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(28));
      expect(decoration.color, kSurfaceDark);
      expect(tester.getSize(cardSurface), const Size(360, 620));
      expect(find.byType(RestaurantInfoBlock), findsOneWidget);
    });

    testWidgets('the hairline is drawn over the photo, not under it',
        (tester) async {
      // The media fills the card and the clip runs to the card's outer edge,
      // so a border in the background decoration is painted first and then
      // covered — the outline disappears, most obviously at the corners.
      await pumpCard(tester, card());

      final container = tester.widget<Container>(cardSurface);
      final background = container.decoration! as BoxDecoration;
      expect(background.border, isNull,
          reason: 'a background border would paint behind the photo');

      final foreground = container.foregroundDecoration! as BoxDecoration;
      expect(foreground.border, Border.all(color: kHairline));
      expect(foreground.borderRadius, BorderRadius.circular(kRadiusCard));
    });

    testWidgets('a clip says it is playing silent', (tester) async {
      await pumpCard(tester, card(videoUrl: 'https://tiktok.test/v/1'));

      expect(find.text('Tap for sound'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('the sound hint keeps its tap off the card', (tester) async {
      // The hint sits on top of the media, inside the card's InkWell. If the
      // tap fell through, "Tap for sound" would open the restaurant instead.
      var taps = 0;
      await pumpCard(
        tester,
        card(videoUrl: 'https://tiktok.test/v/1'),
        onTap: () => taps++,
      );

      await tester.tap(find.text('Tap for sound'));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('a card with no clip promises no sound', (tester) async {
      await pumpCard(tester, card());

      expect(find.text('Tap for sound'), findsNothing);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    });

    testWidgets('an empty video url is no clip at all', (tester) async {
      await pumpCard(tester, card(videoUrl: ''));

      expect(find.text('Tap for sound'), findsNothing);
    });

    testWidgets('the card behind gives its player up, and the hint with it',
        (tester) async {
      await pumpCard(
        tester,
        card(videoUrl: 'https://tiktok.test/v/1'),
        isBehind: true,
      );

      expect(find.text('Tap for sound'), findsNothing);
    });

    testWidgets('a lent player takes the clip with it (D150)', (tester) async {
      await pumpCard(
        tester,
        card(videoUrl: 'https://tiktok.test/v/1'),
        videoLent: true,
      );

      // One controller cannot be mounted in two WebViews, so while the detail
      // screen holds this card's player the card shows its photo instead.
      expect(find.text('Tap for sound'), findsNothing);
    });

    testWidgets('autoplay off offers the clip instead of playing it (D146)',
        (tester) async {
      var asked = 0;
      await pumpCard(
        tester,
        card(videoUrl: 'https://tiktok.test/v/1'),
        autoplay: false,
        onPlay: () => asked += 1,
      );

      // The sound control belongs to a clip that is running; this one is not.
      expect(find.text('Tap for sound'), findsNothing);
      expect(find.text('Tap to play'), findsOneWidget);

      await tester.tap(find.text('Tap to play'));
      await tester.pump();

      // The card does not start the player itself — it asks the deck, which
      // owns the cache the player has to come from.
      expect(asked, 1);
    });

    testWidgets('the card itself paints no stamps — the deck does',
        (tester) async {
      await pumpCard(tester, card());

      expect(find.byType(SwipeStamp), findsNothing);
    });

    testWidgets('a stamp follows the opacity it is given, clamped',
        (tester) async {
      await pumpStamps(tester, like: 0.6, nope: 0.2);
      expect(stampOpacity(tester, 'Ngap!'), 0.6);
      expect(stampOpacity(tester, 'Skip'), 0.2);

      await pumpStamps(tester, like: 1.7, nope: -0.4);
      expect(stampOpacity(tester, 'Ngap!'), 1.0);
      expect(stampOpacity(tester, 'Skip'), 0.0);
    });

    testWidgets('the stamps are decoration, not something to read or press',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpStamps(tester, like: 1, nope: 1);

      expect(find.bySemanticsLabel('Ngap!'), findsNothing);
      expect(find.bySemanticsLabel('Skip'), findsNothing);

      handle.dispose();
    });

    testWidgets('a tap on the clip and a tap on the block go different ways',
        (tester) async {
      var opened = 0;
      var detail = 0;
      await pumpCard(
        tester,
        card(),
        onTap: () => opened++,
        onOpenDetail: () => detail++,
      );

      await tester.tap(find.text('Warung Kak Ros'));
      await tester.pump();
      expect([opened, detail], [0, 1]);

      // Well above the info block, on the media itself.
      await tester.tapAt(tester.getCenter(cardSurface) - const Offset(0, 200));
      await tester.pump();
      expect([opened, detail], [1, 1]);
    });

    testWidgets('a card with no photos and no clip still paints',
        (tester) async {
      await pumpCard(tester, card());

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Warung Kak Ros'), findsOneWidget);
    });
  });

  group('ProgressDots', () {
    testWidgets('two photos put two dots on the card, the first one wide',
        (tester) async {
      await pumpCard(
        tester,
        card(imageUrls: const [
          'https://example.test/1.jpg',
          'https://example.test/2.jpg',
        ]),
      );

      expect(find.byType(ProgressDots), findsOneWidget);
      expect(dotWidths(tester, AnimatedContainer), [18, 6]);
    });

    testWidgets('one photo needs no dots at all', (tester) async {
      await pumpCard(
        tester,
        card(imageUrls: const ['https://example.test/1.jpg']),
      );

      expect(find.byType(ProgressDots), findsNothing);
    });

    testWidgets('a card showing a clip counts no photos', (tester) async {
      // The dots mark position among the photos; while the clip is playing
      // there is nothing to be positioned in.
      await pumpCard(
        tester,
        card(
          videoUrl: 'https://tiktok.test/v/1',
          imageUrls: const [
            'https://example.test/1.jpg',
            'https://example.test/2.jpg',
          ],
        ),
      );

      expect(find.byType(ProgressDots), findsNothing);
    });

    testWidgets('the review row draws fatter, unanimated dots',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: ProgressDots(count: 3, activeIndex: 1)),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(ProgressDots),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
      expect(dotWidths(tester, Container), [5, 14, 5]);
    });
  });
}
