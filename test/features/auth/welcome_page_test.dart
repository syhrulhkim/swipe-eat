import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swipe_eat/features/auth/data/auth_cover_repository.dart';
import 'package:swipe_eat/features/auth/presentation/auth_widgets.dart';
import 'package:swipe_eat/features/auth/presentation/welcome_page.dart';

import '../../support/widget_test_support.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);
const Size _tabletViewport = Size(1024, 1366);
const TextScaler _hugeTextScale = TextScaler.linear(2);

/// The three the design's own stack shows.
List<AuthCover> _covers() => const [
      AuthCover(name: 'Bakar & Bara', imageUrl: 'https://cdn.test/1.jpg'),
      AuthCover(name: 'Kak Ros', imageUrl: 'https://cdn.test/2.jpg'),
      AuthCover(name: 'Chili Pan Mee 88', imageUrl: 'https://cdn.test/3.jpg'),
    ];

Future<GoRouter> _pumpPage(
  WidgetTester tester, {
  AuthCoverLoader? loadCovers,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);

  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomePage(
          loadCovers: loadCovers ?? (limit) async => _covers().take(limit).toList(),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('sign-up screen')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('WelcomePage', () {
    testWidgets('sells the app in the design\'s own words', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Where to eat?\nSwipe it.'), findsOneWidget);
      expect(
        find.textContaining('Fifteen seconds of video per restaurant'),
        findsOneWidget,
      );
      expect(
        find.text('Uses your location to find places nearby'),
        findsOneWidget,
      );
      // The wordmark, announced as the name rather than as "Ngap full stop".
      expect(find.byType(AuthBrand), findsOneWidget);
    });

    testWidgets('the stack carries three real restaurants', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(AuthCoverCard), findsNWidgets(3));
      expect(find.text('Bakar & Bara'), findsOneWidget);
      expect(find.text('Kak Ros'), findsOneWidget);
      expect(find.text('Chili Pan Mee 88'), findsOneWidget);
    });

    testWidgets('a failed load still draws three cards', (tester) async {
      await _pumpPage(
        tester,
        loadCovers: (limit) async => throw const SocketException('offline'),
      );

      // The offline case is the whole point: three plain cards rather than a
      // hole where the deck should be.
      expect(find.byType(AuthCoverCard), findsNWidgets(3));
      expect(find.text('Kak Ros'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short deck fills what it has and leaves the rest plain',
        (tester) async {
      await _pumpPage(tester, loadCovers: (limit) async => [_covers().first]);

      expect(find.byType(AuthCoverCard), findsNWidgets(3));
      expect(find.text('Bakar & Bara'), findsOneWidget);
    });

    testWidgets('both ways in lead to the sign-up screen', (tester) async {
      final router = await _pumpPage(tester);

      await tester.tap(find.text('Start swiping'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/signup');
      expect(find.text('sign-up screen'), findsOneWidget);
    });

    testWidgets('the returning user is offered the same screen',
        (tester) async {
      final router = await _pumpPage(tester);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      // One screen serves both: with phone and Google as the ways in there is
      // no second form to send a returning user to.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/signup');
    });

    testWidgets('a screen reader can reach both actions', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      expect(find.bySemanticsLabel('Start swiping'), findsOneWidget);
      expect(find.bySemanticsLabel('I already have an account'), findsOneWidget);

      handle.dispose();
    });
  });

  group('WelcomePage layout', () {
    testWidgets('does not overflow on the narrowest phone', (tester) async {
      await _pumpPage(tester, viewport: _narrowViewport);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a huge text scale', (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await _pumpPage(tester, viewport: _tabletViewport);
      expect(tester.takeException(), isNull);
    });
  });
}
