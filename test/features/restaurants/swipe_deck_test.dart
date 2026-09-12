import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/presentation/swipe_deck.dart';

import '../../support/widget_test_support.dart';

/// The smallest phone the design is asked to survive.
const Size _narrowViewport = Size(320, 640);

/// A location label longer than any real one, for the squeeze test.
const String _longLocation =
    'Bandar Baru Bangi Seksyen 9 Selangor Darul Ehsan, Malaysia';

/// Apple's floor for a touch target, which the deck's controls are the app's
/// most-used examples of.
const double _minTapTarget = 44;

/// The largest system text size the design is asked to survive.
const TextScaler _doubleText = TextScaler.linear(2.0);

/// Hosts a deck widget under the app's scaffold, optionally at a system text
/// size other than the default.
Widget _host(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: Scaffold(backgroundColor: kBackgroundDark, body: child),
      ),
    ),
  );
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  String locationLabel = 'Kampung Baru',
  int? radiusKm,
  String? mealLabel,
  String? stalenessLabel,
  int activeFilterCount = 0,
  VoidCallback? onFilterTap,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    _host(
      DeckHeader(
        locationLabel: locationLabel,
        radiusKm: radiusKm,
        mealLabel: mealLabel,
        stalenessLabel: stalenessLabel,
        activeFilterCount: activeFilterCount,
        onFilterTap: onFilterTap,
      ),
      textScaler: textScaler,
    ),
  );
}

Future<void> _pumpActionBar(
  WidgetTester tester, {
  VoidCallback? onPass,
  VoidCallback? onLike,
  VoidCallback? onLater,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    _host(
      Center(
        child: DeckActionBar(
          onPass: onPass ?? () {},
          onLike: onLike ?? () {},
          onLater: onLater ?? () {},
        ),
      ),
      textScaler: textScaler,
    ),
  );
}

void main() {
  group('DeckHeader', () {
    testWidgets('says where you are', (tester) async {
      await _pumpHeader(tester);

      expect(find.text('Kampung Baru'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('the subline names the radius and the meal', (tester) async {
      await _pumpHeader(tester, radiusKm: 3, mealLabel: 'dinner');

      expect(find.text('within 3 km · dinner'), findsOneWidget);
    });

    testWidgets('no radius means no limit, not a missing line', (tester) async {
      await _pumpHeader(tester, mealLabel: 'lunch');

      expect(find.text('any distance · lunch'), findsOneWidget);
    });

    testWidgets('the meal is dropped when the caller has none', (tester) async {
      await _pumpHeader(tester, radiusKm: 5);

      expect(find.text('within 5 km'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the discovery control announces itself and fires',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pumpHeader(tester, onFilterTap: () => taps++);

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      // Named for the sheet it opens — radius, cuisines, diet, rating — not
      // for one of its rows.
      expect(find.bySemanticsLabel('Discovery settings'), findsOneWidget);
      expect(find.bySemanticsLabel('Filters'), findsNothing);

      final node = tester.getSemantics(
        find.bySemanticsLabel('Discovery settings'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.value, isEmpty);

      await tester.tap(find.byType(AppIconButton));
      await tester.pump();
      expect(taps, 1);

      handle.dispose();
    });

    testWidgets('a screen reader hears how many filters are on',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHeader(tester, activeFilterCount: 2, onFilterTap: () {});

      final node = tester.getSemantics(
        find.bySemanticsLabel('Discovery settings'),
      );
      expect(node.value, '2 filters on');
      // The word is announced once, by the value — the badge's own "2" does
      // not leak out as a second fragment.
      expect(node.label, 'Discovery settings');

      handle.dispose();
    });

    testWidgets('one filter on is singular', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHeader(tester, activeFilterCount: 1, onFilterTap: () {});

      expect(
        tester.getSemantics(find.bySemanticsLabel('Discovery settings')).value,
        '1 filter on',
      );

      handle.dispose();
    });

    testWidgets('a filter that is on turns the glyph ember', (tester) async {
      await _pumpHeader(tester, activeFilterCount: 1, onFilterTap: () {});

      expect(
        tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color,
        kAccentEmber,
      );
    });

    testWidgets('nothing narrowing the deck leaves the glyph cream',
        (tester) async {
      await _pumpHeader(tester, onFilterTap: () {});

      expect(
        tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color,
        kTextOnPhoto,
      );
    });

    testWidgets('no filter handler, no filter button', (tester) async {
      await _pumpHeader(tester);

      expect(find.byType(AppIconButton), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('the badge counts the filters that are on', (tester) async {
      await _pumpHeader(tester, activeFilterCount: 2, onFilterTap: () {});

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('no filters on, no badge', (tester) async {
      await _pumpHeader(tester, onFilterTap: () {});

      // The badge is the only [Text] inside the button — an [Icon] paints
      // through a [RichText] — so no Text there means no badge.
      expect(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('the staleness chip shows only when there is one',
        (tester) async {
      await _pumpHeader(tester);
      expect(find.byType(AppChip), findsNothing);

      await _pumpHeader(tester, stalenessLabel: 'Saved 2 h ago');
      expect(find.byType(AppChip), findsOneWidget);
      expect(find.text('Saved 2 h ago'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('carries no Settings control — that lives in Profile',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHeader(
        tester,
        stalenessLabel: 'Saved 2 h ago',
        activeFilterCount: 3,
        radiusKm: 3,
        mealLabel: 'dinner',
        onFilterTap: () {},
      );

      expect(find.text('Settings'), findsNothing);
      expect(find.bySemanticsLabel('Settings'), findsNothing);
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      handle.dispose();
    });

    testWidgets('a long location does not overflow a 320 px phone',
        (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpHeader(
        tester,
        locationLabel: _longLocation,
        radiusKm: 3,
        mealLabel: 'dinner',
        stalenessLabel: 'Saved 2 h ago',
        activeFilterCount: 12,
        onFilterTap: () {},
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DeckHeader)).width,
        lessThanOrEqualTo(_narrowViewport.width),
      );
      // The label is cut rather than pushing the filter button off screen.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(AppIconButton)).dx,
        lessThanOrEqualTo(_narrowViewport.width),
      );
    });

    testWidgets('a 320 px phone at double text size still fits the control',
        (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpHeader(
        tester,
        locationLabel: _longLocation,
        radiusKm: 3,
        mealLabel: 'dinner',
        stalenessLabel: 'Saved 2 h ago',
        activeFilterCount: 12,
        onFilterTap: () {},
        textScaler: _doubleText,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopRight(find.byType(AppIconButton)).dx,
        lessThanOrEqualTo(_narrowViewport.width),
      );
    });
  });

  group('DeckActionBar', () {
    testWidgets('offers three moves, no more', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpActionBar(tester);

      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      expect(find.bySemanticsLabel('Ngap'), findsOneWidget);
      expect(find.bySemanticsLabel('Save for later'), findsOneWidget);
      expect(find.byType(AppIconButton), findsNWidgets(2));
      expect(find.byType(AppNgapButton), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the ones that are gone stay gone', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpActionBar(tester);

      // Rewind and the super-like went with the features behind them.
      expect(find.bySemanticsLabel('Rewind'), findsNothing);
      expect(find.bySemanticsLabel('Super like'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.replay_rounded), findsNothing);

      handle.dispose();
    });

    testWidgets('Skip fires only onPass', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect([pass, like, later], [1, 0, 0]);
    });

    testWidgets('Ngap fires only onLike', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byType(AppNgapButton));
      await tester.pump();

      expect([pass, like, later], [0, 1, 0]);
    });

    testWidgets('Save for later fires only onLater', (tester) async {
      var pass = 0;
      var like = 0;
      var later = 0;
      await _pumpActionBar(
        tester,
        onPass: () => pass++,
        onLike: () => like++,
        onLater: () => later++,
      );

      await tester.tap(find.byIcon(Icons.schedule_rounded));
      await tester.pump();

      expect([pass, like, later], [0, 0, 1]);
    });

    testWidgets('every button clears the 44 pt touch target', (tester) async {
      await _pumpActionBar(tester);

      final targets = <Finder>[
        find.byType(AppIconButton).at(0),
        find.byType(AppNgapButton),
        find.byType(AppIconButton).at(1),
      ];
      for (final target in targets) {
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(_minTapTarget));
        expect(size.height, greaterThanOrEqualTo(_minTapTarget));
      }
    });

    testWidgets('Ngap is the biggest thing on the bar', (tester) async {
      await _pumpActionBar(tester);

      final ngap = tester.getSize(find.byType(AppNgapButton)).width;
      expect(ngap,
          greaterThan(tester.getSize(find.byType(AppIconButton).at(0)).width));
      expect(ngap,
          greaterThan(tester.getSize(find.byType(AppIconButton).at(1)).width));
    });

    testWidgets('the ghosts carry the words the primer taught', (tester) async {
      await _pumpActionBar(tester);

      // The Ngap button already says its own word, so only the two ghosts
      // get a caption.
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Ngap!'), findsOneWidget);
      expect(find.text('Ngap'), findsNothing);
    });

    testWidgets('a caption does not make a screen reader say the move twice',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpActionBar(tester);

      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      expect(find.bySemanticsLabel('Later'), findsNothing);
      expect(find.bySemanticsLabel('Save for later'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('Ngap is dead-centre whatever the captions measure',
        (tester) async {
      await _pumpActionBar(tester);

      final bar = tester.getCenter(find.byType(DeckActionBar)).dx;
      final ngap = tester.getCenter(find.byType(AppNgapButton)).dx;
      expect(ngap, closeTo(bar, 0.5));
    });

    testWidgets('survives a 320 px phone at double text size', (tester) async {
      useViewport(tester, _narrowViewport);
      await _pumpActionBar(tester, textScaler: _doubleText);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DeckActionBar)).width,
        lessThanOrEqualTo(_narrowViewport.width),
      );
      // A paragraph clips rather than overflowing, so "no exception" alone
      // would pass with half a word: the word must fit its disc, and each
      // caption its column. Measured as painted — the word is scaled back
      // into the disc, and its own layout size is the unscaled one.
      expect(
        tester.getRect(find.text('Ngap!')).width,
        lessThanOrEqualTo(kNgapButtonSize),
      );
      for (final caption in ['Skip', 'Later']) {
        expect(
          tester.getRect(find.text(caption)).width,
          lessThanOrEqualTo(kNgapButtonSize),
          reason: caption,
        );
      }
      // And the buttons are untouched by the text size.
      expect(
        tester.getSize(find.byType(AppNgapButton)),
        const Size(kNgapButtonSize, kNgapButtonSize),
      );
    });

    testWidgets('sits in the middle, in reading order', (tester) async {
      await _pumpActionBar(tester);

      final skip = tester.getCenter(find.byIcon(Icons.close_rounded)).dx;
      final ngap = tester.getCenter(find.byType(AppNgapButton)).dx;
      final later = tester.getCenter(find.byIcon(Icons.schedule_rounded)).dx;

      expect(skip, lessThan(ngap));
      expect(ngap, lessThan(later));
    });
  });
}
