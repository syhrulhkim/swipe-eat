import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';
import 'package:swipe_eat/features/dashboard/presentation/likes_tab_view.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';
import 'package:swipe_eat/features/restaurants/presentation/restaurant_grid_card.dart';

import '../../support/widget_test_support.dart';

/// Reference phone viewport used unless a case cares about the size.
const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 568);

const Size _tabletViewport = Size(1024, 1366);

/// Accessibility scale the layout has to survive.
const TextScaler _largeTextScale = TextScaler.linear(1.6);

/// The largest scale the store's accessibility settings can hand the tab.
const TextScaler _hugeTextScale = TextScaler.linear(2.0);

/// A restaurant photo URL. Every image request is answered by the fake HTTP
/// client with a real (transparent) PNG, so these never hit the network.
String _photo(int id) => 'https://example.com/photo-$id.jpg';

Restaurant _restaurant({
  required int id,
  String? name,
  String tag = 'Grilled chicken',
  double rating = 4.5,
  List<String>? imageUrls,
  List<RestaurantReview> reviews = const [],
  String? videoUrl,
  bool? isHalal,
  String? neighbourhood,
}) {
  return Restaurant(
    id: id,
    name: name ?? 'Restaurant $id',
    tag: tag,
    details: 'A tiny shophouse stall with a very big charcoal grill.',
    brandColor: kBrandColorFallback,
    rating: rating,
    latitude: 1.85,
    longitude: 102.933333,
    imageUrls: imageUrls ?? [_photo(id)],
    reviews: reviews,
    videoUrl: videoUrl,
    isHalal: isHalal,
    neighbourhood: neighbourhood,
  );
}

List<Restaurant> _restaurants(int count) {
  return List<Restaurant>.generate(
    count,
    (index) => _restaurant(id: index + 1),
  );
}

Future<void> _pumpLikesTab(
  WidgetTester tester, {
  required List<Restaurant> liked,
  Set<int> plannedIds = const {},
  Map<int, String> plannedLabels = const {},
  Size viewport = _phoneViewport,
  double dpr = 1.0,
  TextScaler textScaler = TextScaler.noScaling,
  void Function(Restaurant restaurant)? onOpenRestaurant,
  VoidCallback? onOpenWishlist,
  Future<void> Function()? onRefresh,
}) async {
  useViewport(tester, viewport, dpr: dpr);
  await tester.pumpWidget(
    MaterialApp(
      // The scaler has to be applied below MaterialApp: its own
      // MediaQuery.fromView would otherwise overwrite an ancestor's data.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: kBackgroundDark,
        body: LikesTabView(
          liked: liked,
          plannedIds: plannedIds,
          plannedLabels: plannedLabels,
          onOpenRestaurant: onOpenRestaurant ?? (_) {},
          onOpenWishlist: onOpenWishlist ?? () {},
          onRefresh: onRefresh,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a filter chip, scrolling the row sideways first.
///
/// The row is wider than any phone by design — that is what `.chiprow`'s
/// overflow means — so the last chips start off screen and a bare tap would
/// miss them.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Drags [target] down far enough to arm the RefreshIndicator, then lets it
/// run.
///
/// Not `pumpAndSettle`: the indicator's own animation and the callback are
/// scheduled across several frames, and settling in one go can outrun the
/// arming.
Future<void> _pullDown(WidgetTester tester, Finder target) async {
  await tester.drag(target, const Offset(0, 320), touchSlopY: 0);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// The names of the tiles currently on screen, in grid order.
List<String> _tileNames(WidgetTester tester) {
  return tester
      .widgetList<RestaurantGridCard>(find.byType(RestaurantGridCard))
      .map((card) => card.restaurant.name)
      .toList();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = ImageHttpOverrides();
  });

  group('LikesTabView pull to refresh', () {
    testWidgets('a pull on the grid refreshes', (tester) async {
      var pulls = 0;
      await _pumpLikesTab(
        tester,
        liked: _restaurants(6),
        onRefresh: () async => pulls++,
      );

      await _pullDown(tester, find.byType(GridView));

      expect(pulls, 1);
    });

    testWidgets('a pull works with nothing saved yet', (tester) async {
      // The state a user pulls in: they saved something on another device and
      // want it here. An empty state that cannot be pulled is the one place
      // the gesture is most needed and least likely to have been wired.
      var pulls = 0;
      await _pumpLikesTab(
        tester,
        liked: const [],
        onRefresh: () async => pulls++,
      );

      await _pullDown(tester, find.text('No bites yet'));

      expect(pulls, 1);
    });
  });

  group('LikesTabView empty state', () {
    testWidgets('shows the no-bites copy for an empty list', (tester) async {
      await _pumpLikesTab(tester, liked: const []);

      expect(find.text('No bites yet'), findsOneWidget);
      expect(
        find.text('Ngap the places you want and they land here.'),
        findsOneWidget,
      );
      expect(find.byType(RestaurantGridCard), findsNothing);
    });
  });

  group('LikesTabView grid', () {
    testWidgets('renders one tile per saved restaurant', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Newest Warung'),
          _restaurant(id: 2, name: 'Older Kopitiam'),
        ],
      );

      expect(find.byType(RestaurantGridCard), findsNWidgets(2));
      expect(_tileNames(tester), ['Newest Warung', 'Older Kopitiam']);
    });

    testWidgets('every tile carries the saved check, and no bookmark',
        (tester) async {
      // Bites only holds saved places, so the check is on all of them. The
      // wishlist bookmark that used to share the corner is gone (D125).
      await _pumpLikesTab(tester, liked: _restaurants(2));

      final cards =
          tester.widgetList<RestaurantGridCard>(find.byType(RestaurantGridCard));
      expect(cards.every((card) => card.isSaved), isTrue);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
    });

    testWidgets('the tile subtitle is cuisine and neighbourhood',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(
            id: 1,
            tag: 'Nasi lemak',
            neighbourhood: 'Kampung Baru',
          ),
        ],
      );

      expect(find.text('Nasi lemak · Kampung Baru'), findsOneWidget);
    });

    testWidgets('falls back to the TikTok placeholder without a photo',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(
            id: 1,
            imageUrls: const [],
            videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
          ),
        ],
      );

      expect(find.byType(TikTokThumbnailPlaceholder), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
    });

    testWidgets('carries none of the retired per-tile controls',
        (tester) async {
      // The design's tile is one tap target. The heart and the
      // mark-visited check went with the segments (D96).
      await _pumpLikesTab(tester, liked: _restaurants(2));

      expect(find.bySemanticsLabel('Remove from likes'), findsNothing);
      expect(find.bySemanticsLabel('Mark visited'), findsNothing);
      expect(find.bySemanticsLabel('Filters'), findsNothing);
    });
  });

  group('LikesTabView callbacks', () {
    testWidgets('tapping a tile opens the restaurant', (tester) async {
      final opened = <int>[];
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 4, name: 'Warung Empat')],
        onOpenRestaurant: (value) => opened.add(value.id),
      );

      await tester.tap(find.text('Warung Empat'));
      await tester.pump();

      expect(opened, [4]);
    });
  });

  group('LikesTabView chip row', () {
    testWidgets('shows the design\'s five chips in order', (tester) async {
      await _pumpLikesTab(tester, liked: _restaurants(2));

      for (final label in const [
        'All',
        'Not planned yet',
        'Planned',
        'Wishlist →',
        'Halal',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The segments they replaced are gone.
      expect(find.text('Liked'), findsNothing);
      expect(find.text('Visited'), findsNothing);
      expect(find.text('Reviewed'), findsNothing);
    });

    testWidgets('All is selected to begin with', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLikesTab(tester, liked: _restaurants(2));

      expect(
        tester.getSemantics(find.bySemanticsLabel('All')),
        matchesSemantics(
          label: 'All',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Halal keeps only the places that say they are',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Halal Stall', isHalal: true),
          _restaurant(id: 2, name: 'Pork Noodles', isHalal: false),
          // Null is "the caption never said", which is not a yes.
          _restaurant(id: 3, name: 'Unknown Stall'),
        ],
      );

      await _tapChip(tester, 'Halal');

      expect(_tileNames(tester), ['Halal Stall']);
    });

    testWidgets('Halal toggles back off', (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Halal Stall', isHalal: true),
          _restaurant(id: 2, name: 'Other Stall'),
        ],
      );

      await _tapChip(tester, 'Halal');
      await _tapChip(tester, 'Halal');

      expect(_tileNames(tester).length, 2);
    });

    testWidgets('Planned and Not planned yet split the grid on the ids',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Booked Stall'),
          _restaurant(id: 2, name: 'Loose Stall'),
        ],
        plannedIds: const {1},
      );

      await _tapChip(tester, 'Planned');
      expect(_tileNames(tester), ['Booked Stall']);

      await _tapChip(tester, 'Not planned yet');
      expect(_tileNames(tester), ['Loose Stall']);
    });

    testWidgets('with no planned ids, Planned is empty and Not planned is all',
        (tester) async {
      // Today's real state: the plans phase has not landed, so nothing is
      // planned. The chips still have to behave.
      await _pumpLikesTab(tester, liked: _restaurants(3));

      await _tapChip(tester, 'Not planned yet');
      expect(find.byType(RestaurantGridCard), findsNWidgets(3));

      await _tapChip(tester, 'Planned');
      expect(find.byType(RestaurantGridCard), findsNothing);
      expect(find.text('Nothing matches those chips'), findsOneWidget);
    });

    testWidgets('a filter that hides everything offers a way back',
        (tester) async {
      await _pumpLikesTab(tester, liked: _restaurants(2));

      await _tapChip(tester, 'Planned');
      expect(find.text('Nothing matches those chips'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      expect(find.byType(RestaurantGridCard), findsNWidgets(2));
    });

    testWidgets('tapping the chosen plan chip again returns to All',
        (tester) async {
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Loose Stall')],
      );

      final handle = tester.ensureSemantics();
      await _tapChip(tester, 'Not planned yet');
      await _tapChip(tester, 'Not planned yet');

      // Scrolled back to the head of the row: a chip off screen reports
      // itself hidden, which is true but not what this case is asking.
      await tester.ensureVisible(find.text('All'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('All')),
        matchesSemantics(
          label: 'All',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('only one plan chip is pressed at a time', (tester) async {
      // The three plan chips are one question asked three ways, so two of them
      // lit at once would be a contradiction on screen.
      final handle = tester.ensureSemantics();
      await _pumpLikesTab(
        tester,
        liked: [_restaurant(id: 1, name: 'Booked Stall')],
        plannedIds: const {1},
      );

      // The chip row is wider than the phone, so each one is scrolled into
      // view before its state is read — an off-screen node reports itself
      // hidden, which is true but not what this is asking.
      Future<void> expectPressed(String label, {required bool lit}) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: lit,
            hasTapAction: true,
          ),
          reason: label,
        );
      }

      await _tapChip(tester, 'Planned');
      await expectPressed('Planned', lit: true);
      await expectPressed('All', lit: false);
      await expectPressed('Not planned yet', lit: false);

      await _tapChip(tester, 'Not planned yet');
      await expectPressed('Not planned yet', lit: true);
      await expectPressed('Planned', lit: false);
      await expectPressed('All', lit: false);
      handle.dispose();
    });

    testWidgets('Halal narrows a plan chip rather than replacing it',
        (tester) async {
      // Halal is the one chip that composes: it is a second question, not a
      // fourth answer to the first.
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Booked Halal', isHalal: true),
          _restaurant(id: 2, name: 'Booked Other'),
          _restaurant(id: 3, name: 'Loose Halal', isHalal: true),
        ],
        plannedIds: const {1, 2},
      );

      await _tapChip(tester, 'Planned');
      await _tapChip(tester, 'Halal');

      expect(_tileNames(tester), ['Booked Halal']);
    });

    testWidgets('Wishlist → navigates and never stays pressed',
        (tester) async {
      var opened = 0;
      final handle = tester.ensureSemantics();
      await _pumpLikesTab(
        tester,
        liked: _restaurants(2),
        onOpenWishlist: () => opened++,
      );

      await _tapChip(tester, 'Wishlist →');

      expect(opened, 1);
      // It filtered nothing…
      expect(find.byType(RestaurantGridCard), findsNWidgets(2));
      // …and it is not lit.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Wishlist →')),
        matchesSemantics(
          label: 'Wishlist →',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a chip\'s own tap action filters the grid', (tester) async {
      // D83: AppFilterChip excludes its Text and re-declares onTap, so the
      // claim is proved by driving the action rather than reading the flag.
      final handle = tester.ensureSemantics();
      await _pumpLikesTab(
        tester,
        liked: [
          _restaurant(id: 1, name: 'Halal Stall', isHalal: true),
          _restaurant(id: 2, name: 'Other Stall'),
        ],
      );

      await tester.ensureVisible(find.text('Halal'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Halal'));
      await tester.pumpAndSettle();

      expect(_tileNames(tester), ['Halal Stall']);
      handle.dispose();
    });

    testWidgets('every chip is a button of at least 44 pt', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLikesTab(tester, liked: _restaurants(2));

      for (final label in const [
        'All',
        'Not planned yet',
        'Planned',
        'Wishlist →',
        'Halal',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        final finder = find.bySemanticsLabel(label);
        expect(
          tester.getSemantics(finder),
          matchesSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: label == 'All',
            hasTapAction: true,
          ),
          reason: label,
        );
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: label,
        );
      }
      handle.dispose();
    });
  });

  group('LikesTabView layout', () {
    /// A name long enough to need the tile's ellipsis.
    const longName = 'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat';

    Future<void> pumpBusyGrid(
      WidgetTester tester, {
      required Size viewport,
      double dpr = 1.0,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return _pumpLikesTab(
        tester,
        viewport: viewport,
        dpr: dpr,
        textScaler: textScaler,
        plannedIds: const {1},
        plannedLabels: const {1: 'Fri 4'},
        liked: [
          _restaurant(
            id: 1,
            name: longName,
            tag: 'Charcoal-grilled chicken and sambal',
            neighbourhood: 'Simpang Empat',
            videoUrl: 'https://www.tiktok.com/@johorfoodie/video/12345',
          ),
          ..._restaurants(5).map(
            (restaurant) => _restaurant(id: restaurant.id + 1),
          ),
        ],
      );
    }

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await pumpBusyGrid(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await pumpBusyGrid(tester, viewport: _tabletViewport, dpr: 2.0);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await pumpBusyGrid(
        tester,
        viewport: _phoneViewport,
        textScaler: _largeTextScale,
      );

      expect(tester.takeException(), isNull);

      // Guard against a vacuous pass: the scaler really did grow the text.
      final scaledHeight = tester.getSize(find.text('Halal')).height;
      await pumpBusyGrid(tester, viewport: _phoneViewport);
      expect(tester.getSize(find.text('Halal')).height, lessThan(scaledHeight));
    });

    testWidgets('does not overflow at 320 px and twice the text size',
        (tester) async {
      await pumpBusyGrid(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the chip row scrolls rather than overflowing at 320 px',
        (tester) async {
      await pumpBusyGrid(tester, viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
      // The row is wider than the phone by design, so the last chip starts
      // off screen and is reached by scrolling — which is the point: it
      // scrolls rather than overflowing.
      final viewport = logicalViewport(tester);
      expect(tester.getRect(find.text('All')).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(find.text('Halal')).right,
          greaterThan(viewport.width));

      await tester.ensureVisible(find.text('Halal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Halal')).right,
        lessThanOrEqualTo(viewport.width),
      );
    });
  });
}
