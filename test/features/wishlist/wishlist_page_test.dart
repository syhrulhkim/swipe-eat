import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/friends/models/friend.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/wishlist/models/wishlist_item.dart';
import 'package:swipe_eat/features/wishlist/presentation/wishlist_page.dart';
import 'package:swipe_eat/features/wishlist/presentation/wishlist_row.dart';
import 'package:swipe_eat/features/wishlist/state/wishlist_controller.dart';

import '../../support/widget_test_support.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_wishlist_repository.dart';

/// Reference phone viewport used unless a case cares about the size.
const Size _phoneViewport = Size(390, 844);

/// The narrowest phone the design has to survive.
const Size _narrowViewport = Size(320, 568);

const Size _tabletViewport = Size(1024, 1366);

/// Accessibility scale the layout has to survive.
const TextScaler _largeTextScale = TextScaler.linear(1.6);

/// The largest scale the store's accessibility settings can hand the page.
const TextScaler _hugeTextScale = TextScaler.linear(2.0);

/// The list the design's own screenshot shows: six to go, three eaten.
List<WishlistItem> _designList() {
  return [
    testWishlistItem(1, title: 'Warung Kak Ros'),
    testWishlistItem(2,
        title: 'Roti Canai Corner', source: WishlistSource.friend),
    testWishlistItem(3, title: 'Kuey Teow Ah Seng'),
    testWishlistItem(4, title: 'Bakar & Bara Satay'),
    testWishlistItem(5,
        title: 'Banana Leaf House', source: WishlistSource.friend),
    testWishlistItem(6, title: 'Cendol Tepi Jalan'),
    testWishlistItem(7,
        title: 'Kopitiam Heng Kee', eatenAt: DateTime(2026, 8, 24)),
    testWishlistItem(8,
        title: 'Chili Pan Mee 88', eatenAt: DateTime(2026, 8, 12)),
    testWishlistItem(9,
        title: 'Mee Rebus Mak Enon', eatenAt: DateTime(2026, 8, 2)),
  ];
}

Future<WishlistController> _pumpPage(
  WidgetTester tester, {
  List<WishlistItem> rows = const [],
  FakeWishlistRepository? repository,
  Size viewport = _phoneViewport,
  double dpr = 1.0,
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function(String text)? onShare,
  List<FriendProfile> friends = const [],
}) async {
  useViewport(tester, viewport, dpr: dpr);
  final backing = repository ?? FakeWishlistRepository(rows: rows);
  final controller = WishlistController(repository: backing);

  // Injected even when it is empty: the page reads the shared instance
  // otherwise, and the shared instance talks to Supabase.
  final friendsController = FriendsController(
    repository: FakeFriendsRepository(friends: friends),
    followAuthChanges: false,
  );
  addTearDown(friendsController.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: WishlistPage(
        controller: controller,
        onShare: onShare,
        friends: friendsController,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return controller;
}

/// The vertical position of one row's title, for ordering assertions.
double _titleTop(WidgetTester tester, String title) {
  return tester.getTopLeft(find.text(title)).dy;
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('WishlistPage header', () {
    testWidgets('carries the design\'s two-line title', (tester) async {
      await _pumpPage(tester, rows: _designList());

      expect(find.text('Places to\ntry'), findsOneWidget);
    });

    testWidgets('counts both halves', (tester) async {
      await _pumpPage(tester, rows: _designList());

      expect(find.text('6'), findsOneWidget);
      expect(find.text('to go'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('eaten'), findsOneWidget);
    });

    testWidgets('the counts follow a toggle', (tester) async {
      await _pumpPage(tester, rows: _designList());

      await tester.tap(find.text('Warung Kak Ros'));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('reads the counts as one phrase for a screen reader',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester, rows: _designList());

      expect(find.bySemanticsLabel('6 to go'), findsOneWidget);
      expect(find.bySemanticsLabel('3 eaten'), findsOneWidget);
      handle.dispose();
    });
  });

  group('WishlistPage list', () {
    testWidgets('heads the list with the instruction', (tester) async {
      await _pumpPage(tester, rows: _designList());

      expect(
        find.text("Tap a place once you've eaten there"),
        findsOneWidget,
      );
    });

    testWidgets('shows cuisine and neighbourhood under the name',
        (tester) async {
      await _pumpPage(tester, rows: [testWishlistItem(1, title: 'Kak Ros')]);

      expect(find.text('Nasi lemak · Kampung Baru'), findsOneWidget);
    });

    testWidgets('names where each row came from', (tester) async {
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Swiped One'),
        testWishlistItem(2, title: 'Sent One', source: WishlistSource.friend),
        testWishlistItem(3, title: 'Typed One', source: WishlistSource.manual),
        testWishlistItem(4, title: 'Eaten One', eatenAt: DateTime(2026, 8, 24)),
      ]);

      expect(find.text('Swiped'), findsOneWidget);
      // Nobody sent it that I am still friends with, so the row says only
      // what it knows.
      expect(find.text('From a friend'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Eaten'), findsOneWidget);
      expect(find.text('24 Aug'), findsOneWidget);
    });

    testWidgets('an eaten row keeps its date over any plan', (tester) async {
      // Chronological precedence: a place already eaten is done, so that wins
      // over a date now in the past.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WishlistRow(
              item: testWishlistItem(1,
                  title: 'Already Been', eatenAt: DateTime(2026, 8, 24)),
              plannedLabel: 'Fri 4',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eaten'), findsOneWidget);
      expect(find.text('24 Aug'), findsOneWidget);
      expect(find.text('Planned'), findsNothing);
      expect(find.text('Fri 4'), findsNothing);
    });

    testWidgets('a planned label wins over the row\'s source', (tester) async {
      // The plans phase will pass this; the row already knows what to do.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WishlistRow(
              item: testWishlistItem(1, title: 'Booked'),
              plannedLabel: 'Fri 4',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Fri 4'), findsOneWidget);
      expect(find.text('Swiped'), findsNothing);
    });
  });

  group('WishlistPage crossing off', () {
    testWidgets('a tap sinks the row to the bottom', (tester) async {
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Alpha'),
        testWishlistItem(2, title: 'Beta'),
        testWishlistItem(3, title: 'Gamma'),
      ]);

      // Newest first: Gamma, Beta, Alpha.
      expect(_titleTop(tester, 'Gamma'), lessThan(_titleTop(tester, 'Alpha')));

      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(
        _titleTop(tester, 'Gamma'),
        greaterThan(_titleTop(tester, 'Alpha')),
      );
    });

    testWidgets('the strike-through draws itself across the name',
        (tester) async {
      await _pumpPage(tester, rows: [testWishlistItem(1, title: 'Alpha')]);

      Finder strike() => find.descendant(
            of: find.byType(WishlistRow),
            matching: find.byType(AnimatedFractionallySizedBox),
          );

      expect(
        tester.widget<AnimatedFractionallySizedBox>(strike()).widthFactor,
        0,
      );

      await tester.tap(find.text('Alpha'));
      // Halfway through the 260 ms sweep: the bar is drawn, and not yet whole.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));

      final midway = tester.getSize(strike()).width;
      expect(midway, greaterThan(0));

      await tester.pumpAndSettle();
      expect(tester.getSize(strike()).width, greaterThan(midway));
      expect(
        tester.widget<AnimatedFractionallySizedBox>(strike()).widthFactor,
        1,
      );
    });

    testWidgets('the photo greys and fades once the place is eaten',
        (tester) async {
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Alpha', coverUrl: 'https://x/1.jpg'),
      ]);

      Finder inRow(Type type) => find.descendant(
            of: find.byType(WishlistRow),
            matching: find.byType(type),
          );
      // The row's other AnimatedOpacity belongs to the tick, so the thumb's
      // is reached through the clip only it draws.
      Finder thumbFade() => find.ancestor(
            of: inRow(ClipRRect),
            matching: find.byType(AnimatedOpacity),
          );

      // Still to go: full colour, full opacity.
      expect(inRow(ColorFiltered), findsNothing);
      expect(tester.widget<AnimatedOpacity>(thumbFade()).opacity, 1);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      final filter = tester.widget<ColorFiltered>(inRow(ColorFiltered));
      expect(
        filter.colorFilter,
        const ColorFilter.mode(Colors.grey, BlendMode.saturation),
      );
      expect(tester.widget<AnimatedOpacity>(thumbFade()).opacity, 0.5);
    });

    testWidgets('a typed row with no photo still greys when eaten',
        (tester) async {
      // No Image to filter, but the panel that stands in for one has to read
      // as done just the same.
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Typed', source: WishlistSource.manual),
      ]);

      await tester.tap(find.text('Typed'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(WishlistRow),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a second tap puts the row back', (tester) async {
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Alpha'),
        testWishlistItem(2, title: 'Beta'),
      ]);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(
          _titleTop(tester, 'Beta'), greaterThan(_titleTop(tester, 'Alpha')));

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(_titleTop(tester, 'Beta'), lessThan(_titleTop(tester, 'Alpha')));
    });

    testWidgets('no dialog and no confetti stand between the tap and the tick',
        (tester) async {
      await _pumpPage(tester, rows: [testWishlistItem(1, title: 'Alpha')]);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('WishlistPage add', () {
    testWidgets('the plus button files a typed place', (tester) async {
      final controller = await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Alpha'),
      ]);

      await tester.enterText(find.byType(TextField), 'Line Clear');
      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Line Clear'), findsOneWidget);
      expect(controller.toGoCount, 2);
      // The field is emptied, so a second place can be typed straight away.
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
    });

    testWidgets('the keyboard\'s done key files it too', (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField), 'Line Clear');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Line Clear'), findsOneWidget);
    });

    testWidgets('a refused add keeps the typing and says so', (tester) async {
      final repository = FakeWishlistRepository();
      await _pumpPage(tester, repository: repository);
      repository.failWrite = true;

      await tester.enterText(find.byType(TextField), 'Sup Kambing Haji Samuri');
      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pumpAndSettle();

      // The row did not land, so the words the user typed are still there to
      // try again with.
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Sup Kambing Haji Samuri');
      expect(find.text('Could not add that place.'), findsOneWidget);
    });

    testWidgets('a failed toggle says so once the list is up', (tester) async {
      final repository = FakeWishlistRepository(
        rows: [testWishlistItem(1, title: 'Alpha')],
      );
      await _pumpPage(tester, repository: repository);
      repository.failWrite = true;

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.text('Could not update that place.'), findsOneWidget);
    });

    testWidgets('an empty field files nothing', (tester) async {
      final repository = FakeWishlistRepository();
      await _pumpPage(tester, repository: repository);

      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pumpAndSettle();

      expect(repository.calls.any((call) => call.startsWith('addManual')),
          isFalse);
    });

    testWidgets('a typed place shows the panel instead of a stranger\'s photo',
        (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField), 'Line Clear');
      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
    });
  });

  group('WishlistPage footer', () {
    testWidgets('explains where eaten rows go', (tester) async {
      await _pumpPage(tester, rows: _designList());

      expect(find.text('Eaten ones sink to the bottom'), findsOneWidget);
    });

    testWidgets('Clear eaten empties that half only', (tester) async {
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Still To Go'),
        testWishlistItem(2, title: 'Eaten One', eatenAt: DateTime(2026, 8, 24)),
      ]);

      await tester.tap(find.text('Clear eaten'));
      await tester.pumpAndSettle();

      expect(find.text('Eaten One'), findsNothing);
      expect(find.text('Still To Go'), findsOneWidget);
    });

    testWidgets('Clear eaten is dead while nothing is eaten', (tester) async {
      await _pumpPage(tester, rows: [testWishlistItem(1)]);

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Clear eaten'),
          matching: find.byType(TextButton),
        ),
      );

      expect(button.onPressed, isNull);
    });
  });

  group('WishlistPage empty and failed states', () {
    testWidgets('an empty list says what to do about it', (tester) async {
      await _pumpPage(tester);

      expect(find.text('No places to try yet'), findsOneWidget);
      expect(
        find.textContaining('Swipe up on the deck'),
        findsOneWidget,
      );
      // The add bar is still there — it is the way out of the state.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a failed load offers a retry that recovers', (tester) async {
      final repository = FakeWishlistRepository(rows: [testWishlistItem(1)])
        ..failList = true;
      await _pumpPage(tester, repository: repository);

      expect(find.text('Something went wrong'), findsOneWidget);

      repository.failList = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Place 1'), findsOneWidget);
    });
  });

  group('WishlistPage typing before the list arrives', () {
    testWidgets('a place typed over a failed load does not become the list',
        (tester) async {
      // The add bar is live in the error state, so this is a real path: the
      // fetch failed, the user typed somewhere anyway. The typed row must not
      // stand in for the places already saved.
      final repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'Already Saved'),
      ])
        ..failList = true;
      await _pumpPage(tester, repository: repository);

      expect(find.text('Something went wrong'), findsOneWidget);

      repository.failList = false;
      await tester.enterText(find.byType(TextField), 'Line Clear');
      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Line Clear'), findsOneWidget);
      expect(find.text('Already Saved'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'two still to go');
    });
  });

  group('WishlistPage sharing', () {
    testWidgets('hands the to-go places to the share sheet', (tester) async {
      String? shared;
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(1, title: 'Still To Go'),
          testWishlistItem(2,
              title: 'Eaten One', eatenAt: DateTime(2026, 8, 1)),
        ],
        onShare: (text) async => shared = text,
      );

      await tester.tap(find.bySemanticsLabel('Share wishlist'));
      await tester.pumpAndSettle();

      expect(shared, contains('Still To Go'));
      // A list of where to eat should not carry the places already eaten.
      expect(shared, isNot(contains('Eaten One')));
    });

    testWidgets('shares nothing when there is nothing to go', (tester) async {
      var called = false;
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(1,
              title: 'Eaten One', eatenAt: DateTime(2026, 8, 1)),
        ],
        onShare: (text) async => called = true,
      );

      await tester.tap(find.bySemanticsLabel('Share wishlist'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });
  });

  group('WishlistPage accessibility', () {
    testWidgets('every row is one button, and says whether it is crossed off',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester, rows: [
        testWishlistItem(1, title: 'Still To Go'),
        testWishlistItem(2, title: 'Eaten One', eatenAt: DateTime(2026, 8, 24)),
      ]);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Still To Go')),
        matchesSemantics(
          label: 'Still To Go',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Eaten One')),
        matchesSemantics(
          label: 'Eaten One',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a row\'s own tap action reaches the controller',
        (tester) async {
      // D83: the row excludes its children's semantics and re-declares onTap,
      // so the claim is proved by driving the action, not by reading the flag.
      final handle = tester.ensureSemantics();
      final repository = FakeWishlistRepository(rows: [
        testWishlistItem(1, title: 'Still To Go'),
      ]);
      await _pumpPage(tester, repository: repository);

      tester.semantics.tap(find.semantics.byLabel('Still To Go'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('markEaten:1:true'));
      handle.dispose();
    });

    testWidgets('the Add button\'s own tap action files the place',
        (tester) async {
      final handle = tester.ensureSemantics();
      final repository = FakeWishlistRepository();
      await _pumpPage(tester, repository: repository);

      await tester.enterText(find.byType(TextField), 'Line Clear');
      tester.semantics.tap(find.semantics.byLabel('Add'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('addManual:Line Clear'));
      handle.dispose();
    });

    testWidgets('the Add button is hit at 44 pt, not just measured at it',
        (tester) async {
      // Drawn 36 px inside a 44 px box. A finger landing in the outer ring has
      // to reach the button, or the target is 44 for a screen reader only.
      final repository = FakeWishlistRepository();
      await _pumpPage(tester, repository: repository);

      await tester.enterText(find.byType(TextField), 'Line Clear');
      final rect = tester.getRect(find.bySemanticsLabel('Add'));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('addManual:Line Clear'));
    });

    testWidgets('the topbar buttons are labelled and 44 pt', (tester) async {
      await _pumpPage(tester, rows: _designList());

      for (final label in const ['Back', 'Share wishlist', 'Add']) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget, reason: label);
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: label,
        );
      }
    });

    testWidgets('a row is a tall enough target to hit', (tester) async {
      await _pumpPage(tester, rows: [testWishlistItem(1, title: 'Alpha')]);

      expect(
        tester.getSize(find.byType(WishlistRow)).height,
        greaterThanOrEqualTo(kMinTapTarget),
      );
    });
  });

  group('WishlistPage navigation', () {
    testWidgets('the back button leaves the page', (tester) async {
      // Pushed from the Bites tab, so the page owns its own way out.
      useViewport(tester, _phoneViewport);
      final controller = WishlistController(
        repository: FakeWishlistRepository(rows: [testWishlistItem(1)]),
      );
      addTearDown(controller.dispose);
      final friends = FriendsController(
        repository: FakeFriendsRepository(),
        followAuthChanges: false,
      );
      addTearDown(friends.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => WishlistPage(
                        controller: controller,
                        friends: friends,
                      ),
                    ),
                  ),
                  child: const Text('Open wishlist'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Places to\ntry'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Places to\ntry'), findsNothing);
      expect(find.text('Open wishlist'), findsOneWidget);
    });
  });

  group('WishlistPage senders', () {
    testWidgets('a row somebody sent names them', (tester) async {
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(
            1,
            title: 'Roti Canai Corner',
            source: WishlistSource.friend,
            fromUserId: 'u1',
          ),
        ],
        friends: [testFriend('u1', name: 'Aiman Zulkifli')],
      );

      expect(find.text('From Aiman Zulkifli'), findsOneWidget);
      expect(find.text('From a friend'), findsNothing);
    });

    testWidgets('a sender I am no longer friends with keeps the old wording',
        (tester) async {
      // The name can only come from the friends cache, and somebody removed
      // is not in it. The row still came from a person, so it still says so.
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(
            1,
            title: 'Roti Canai Corner',
            source: WishlistSource.friend,
            fromUserId: 'u9',
          ),
        ],
        friends: [testFriend('u1', name: 'Aiman Zulkifli')],
      );

      expect(find.text('From a friend'), findsOneWidget);
    });

    testWidgets('only a sent row gets a name, however many friends there are',
        (tester) async {
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(1, title: 'Swiped One', fromUserId: 'u1'),
          testWishlistItem(2, title: 'Typed One',
              source: WishlistSource.manual, fromUserId: 'u1'),
        ],
        friends: [testFriend('u1', name: 'Aiman Zulkifli')],
      );

      expect(find.textContaining('From'), findsNothing);
      expect(find.text('Swiped'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('the name arrives when the address book does', (tester) async {
      // The two loads are independent, and the wishlist usually wins. The row
      // has to redraw when the names land rather than keeping the placeholder
      // until the next visit.
      final friendsRepository = FakeFriendsRepository()
        ..failWith = StateError('offline');
      useViewport(tester, _phoneViewport);
      final controller = WishlistController(
        repository: FakeWishlistRepository(rows: [
          testWishlistItem(
            1,
            title: 'Roti Canai Corner',
            source: WishlistSource.friend,
            fromUserId: 'u1',
          ),
        ]),
      );
      final friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );
      addTearDown(friends.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: WishlistPage(controller: controller, friends: friends),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From a friend'), findsOneWidget);

      friendsRepository.failWith = null;
      friendsRepository.setFriends([testFriend('u1', name: 'Aiman Zulkifli')]);
      await friends.refresh();
      await tester.pumpAndSettle();

      expect(find.text('From Aiman Zulkifli'), findsOneWidget);
    });

    testWidgets('a long sender name does not overflow the narrowest phone',
        (tester) async {
      await _pumpPage(
        tester,
        rows: [
          testWishlistItem(
            1,
            title: 'Roti Canai Corner',
            source: WishlistSource.friend,
            fromUserId: 'u1',
          ),
        ],
        friends: [
          testFriend('u1', name: 'Nurul Syafiqah binti Abdul Rahman'),
        ],
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('WishlistPage layout', () {
    /// A name long enough to need the row's ellipsis.
    const longName =
        'Restoran Nasi Kandar Pelita Simpang Empat Batu Pahat Cawangan Dua';

    List<WishlistItem> busyList() => [
          testWishlistItem(1, title: longName, neighbourhood: 'Simpang Empat'),
          testWishlistItem(2,
              title: 'Sent By Somebody', source: WishlistSource.friend),
          ..._designList().skip(2),
        ];

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await _pumpPage(tester, rows: busyList(), viewport: _narrowViewport);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await _pumpPage(
        tester,
        rows: busyList(),
        viewport: _tabletViewport,
        dpr: 2.0,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await _pumpPage(
        tester,
        rows: busyList(),
        textScaler: _largeTextScale,
      );

      expect(tester.takeException(), isNull);

      // Guard against a vacuous pass: the scaler really did grow the text.
      final scaledHeight = tester.getSize(find.text('to go')).height;
      await _pumpPage(tester, rows: busyList());
      expect(tester.getSize(find.text('to go')).height, lessThan(scaledHeight));
    });

    testWidgets('keeps the design\'s header on one line when it fits',
        (tester) async {
      // Title left, both counts right — the wrapping that rescues the narrow
      // case must not fire wherever there is room for the design's own
      // composition.
      await _pumpPage(tester, rows: busyList(), viewport: _tabletViewport);

      expect(_titleTop(tester, 'to go'), _titleTop(tester, 'eaten'));
      expect(
        tester.getRect(find.text('to go')).left,
        greaterThan(tester.getRect(find.text('Places to\ntry')).right),
      );
    });

    testWidgets('drops the second count onto its own line when it must',
        (tester) async {
      await _pumpPage(
        tester,
        rows: busyList(),
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(
        _titleTop(tester, 'eaten'),
        greaterThan(_titleTop(tester, 'to go')),
      );
      // And the list is still on screen rather than squeezed out of it.
      expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
    });

    testWidgets('does not overflow at 320 px and twice the text size',
        (tester) async {
      await _pumpPage(
        tester,
        rows: busyList(),
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps every row inside a 320 px viewport', (tester) async {
      await _pumpPage(tester, rows: busyList(), viewport: _narrowViewport);

      final viewport = logicalViewport(tester);
      for (final row in find.byType(WishlistRow).evaluate()) {
        final rect = tester.getRect(find.byWidget(row.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
      }
    });
  });
}
