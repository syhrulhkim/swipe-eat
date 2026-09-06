import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/presentation/friends_page.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';

import '../../support/widget_test_support.dart';
import 'fake_friends_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

class _Harness {
  _Harness(this.repository, this.controller);

  final FakeFriendsRepository repository;
  final FriendsController controller;
}

/// The address book the design's "Friends · 38" implies: one person waiting on
/// an answer, one waiting to hear back, and two friends.
FakeFriendsRepository _fullBook() {
  return FakeFriendsRepository(
    friends: [
      testFriend('u1', name: 'Aiman Zulkifli'),
      testFriend('u2', name: 'Mei Kee Tan'),
    ],
    requests: [
      testRequest('u9', name: 'Syafiq Rahman'),
      testRequest('u8', name: 'Nadia Idris', incoming: false),
    ],
  );
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  FakeFriendsRepository? repository,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  final backing = repository ?? _fullBook();
  final controller = FriendsController(
    repository: backing,
    followAuthChanges: false,
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: FriendsPage(friends: controller),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(backing, controller);
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('FriendsPage lists', () {
    testWidgets('titles itself and offers a way back', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Friends'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('splits the three kinds of person into three sections',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text('Wants to be friends'), findsOneWidget);
      expect(find.text('Syafiq Rahman'), findsOneWidget);

      expect(find.text('Waiting to hear back'), findsOneWidget);
      expect(find.text('Nadia Idris'), findsOneWidget);

      // The count the You tab's button shows, repeated where the names are.
      expect(find.text('Your friends · 2'), findsOneWidget);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
      expect(find.byType(PersonRow), findsNWidgets(4));
    });

    testWidgets('a section with nobody in it is not drawn at all',
        (tester) async {
      await _pumpPage(
        tester,
        repository: FakeFriendsRepository(
          friends: [testFriend('u1', name: 'Aiman Zulkifli')],
        ),
      );

      expect(find.text('Wants to be friends'), findsNothing);
      expect(find.text('Waiting to hear back'), findsNothing);
      expect(find.text('Your friends · 1'), findsOneWidget);
    });

    testWidgets('an empty address book says how one fills up', (tester) async {
      await _pumpPage(tester, repository: FakeFriendsRepository());

      expect(find.byType(PersonRow), findsNothing);
      expect(
        find.textContaining('Nobody yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load is retryable', (tester) async {
      final repository = FakeFriendsRepository()
        ..failWith = StateError('offline');
      final harness = await _pumpPage(tester, repository: repository);

      expect(find.text('Could not load your friends.'), findsOneWidget);

      repository.failWith = null;
      repository.setFriends([testFriend('u1', name: 'Aiman Zulkifli')]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Aiman Zulkifli'), findsOneWidget);
      expect(harness.controller.count, 1);
    });
  });

  group('FriendsPage answering', () {
    testWidgets('Accept moves the person into the friends list',
        (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Accept Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u9', FriendAction.accept)]);
      expect(find.text('Wants to be friends'), findsNothing);
      expect(find.text('Your friends · 3'), findsOneWidget);
    });

    testWidgets('Decline takes the request off the page', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Decline Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u9', FriendAction.decline)]);
      expect(find.text('Syafiq Rahman'), findsNothing);
      // Declining is not befriending.
      expect(find.text('Your friends · 2'), findsOneWidget);
    });

    testWidgets('cancelling a sent request deletes the same row a decline '
        'would', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(
        find.bySemanticsLabel('Cancel the request to Nadia Idris'),
      );
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u8', FriendAction.decline)]);
      expect(find.text('Nadia Idris'), findsNothing);
    });

    testWidgets('a failed answer says so and leaves the row where it was',
        (tester) async {
      final repository = _fullBook()..failActWith = StateError('offline');
      await _pumpPage(tester, repository: repository);

      await tester.tap(find.bySemanticsLabel('Accept Syafiq Rahman'));
      await tester.pumpAndSettle();

      expect(find.text('That did not go through.'), findsOneWidget);
      expect(find.text('Syafiq Rahman'), findsOneWidget);
      expect(find.text('Your friends · 2'), findsOneWidget);
    });
  });

  group('FriendsPage removing', () {
    testWidgets('Remove asks first, and "Keep them" keeps them',
        (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Remove Aiman Zulkifli'));
      await tester.pumpAndSettle();

      // A sheet, not a dialog — the same shape cancelling a plan uses.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Remove Aiman Zulkifli?'), findsOneWidget);

      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();

      expect(harness.repository.actions, isEmpty);
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
    });

    testWidgets('confirming takes them off the list', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Remove Aiman Zulkifli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(harness.repository.actions, [('u1', FriendAction.remove)]);
      expect(find.text('Aiman Zulkifli'), findsNothing);
      expect(find.text('Your friends · 1'), findsOneWidget);
    });
  });

  group('FriendsPage semantics', () {
    testWidgets('every button names the person it acts on', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // Two people can offer the same word, so the word alone is not a label.
      for (final label in [
        'Accept Syafiq Rahman',
        'Decline Syafiq Rahman',
        'Cancel the request to Nadia Idris',
        'Remove Aiman Zulkifli',
        'Remove Mei Kee Tan',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });

    testWidgets('a row with buttons on it is not itself a button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // `PersonRow` drops its own wrapper when something is in `trailing`; a
      // wrapper there would fuse the name and both buttons into one node with
      // nothing to press.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Accept Syafiq Rahman')),
        matchesSemantics(
          label: 'Accept Syafiq Rahman',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('FriendsPage layout', () {
    testWidgets('four rows of people fit the narrowest phone at a doubled '
        'text scale', (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Wants to be friends'), findsOneWidget);
    });

    testWidgets('the empty state survives the same', (tester) async {
      await _pumpPage(
        tester,
        repository: FakeFriendsRepository(),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nobody yet.'), findsOneWidget);
    });
  });
}
