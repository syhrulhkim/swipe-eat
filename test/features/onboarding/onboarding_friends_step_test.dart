import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/app_buttons.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/friends/data/friends_repository.dart';
import 'package:swipe_eat/features/friends/models/friend.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_page.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_steps.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_onboarding_repository.dart';

Position _position() {
  return Position(
    latitude: 1.9,
    longitude: 103.1,
    timestamp: DateTime(2026, 8, 23, 12),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// The six people the design draws on 01f.
List<FriendProfile> _designMatches() => [
      testFriend('u1', name: 'Aiman Zulkifli'),
      testFriend('u2', name: 'Mei Kee Tan'),
      testFriend('u3', name: 'Syafiq Rahman'),
      testFriend('u4', name: 'Priya Raj'),
      testFriend('u5', name: 'Jia Wen Lim'),
      testFriend('u6', name: 'Danial Ng'),
    ];

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeOnboardingRepository onboarding;
  late FakeFriendsRepository friendsRepository;
  late FriendsController friends;
  late List<String> contactBook;
  late int contactReads;

  /// When non-null, the contacts reader hangs on this until the test completes
  /// it — a permission sheet the user has not answered, or a slow phone.
  Completer<void>? contactGate;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authRepository = FakeAuthRepository()
      ..sessionPresent = true
      ..profile = const AppUser(
        id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        name: 'User',
        email: 'demo@swipeeat.test',
      );
    auth = AuthController(authRepository);
    await auth.bootstrap();
    onboarding = FakeOnboardingRepository();
    friendsRepository = FakeFriendsRepository();
    friends = FriendsController(
      repository: friendsRepository,
      followAuthChanges: false,
    );
    contactBook = <String>[];
    contactReads = 0;
    contactGate = null;
  });

  tearDown(() async {
    friends.dispose();
    auth.dispose();
    await authRepository.dispose();
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    Size viewport = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    useViewport(tester, viewport);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: OnboardingPage(
              authController: auth,
              repository: onboarding,
              resolvePosition: () async => _position(),
              resolvePlace: (_) async => 'Peserai, Batu Pahat',
              readContacts: () async {
                contactReads += 1;
                await contactGate?.future;
                return contactBook;
              },
              friends: friends,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder primaryButton(String label) =>
      find.widgetWithText(AppPrimaryButton, label);

  /// Name, taste, rules — then we are standing on the friends step.
  Future<void> reachFriends(
    WidgetTester tester, {
    Size viewport = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await pumpWizard(tester, viewport: viewport, textScaler: textScaler);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Aisyah');
    await tester.pump();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malay'));
    await tester.pump();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  /// From the friends step to the end of the wizard.
  Future<void> finishFromFriends(WidgetTester tester, String label) async {
    await tester.tap(primaryButton(label));
    await tester.pumpAndSettle();
    await tester.tap(primaryButton('Continue')); // location
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  }

  group('the friends step', () {
    testWidgets('sits between the rules and the habits', (tester) async {
      // The position is the whole reason it works: `_skipLocation` calls
      // finish outright, so anything after the location step is invisible to
      // everybody who declines location.
      await reachFriends(tester);

      expect(find.text('Eat with people'), findsOneWidget);
      expect(find.text('How do you eat?'), findsNothing);

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('How do you eat?'), findsOneWidget);
    });

    testWidgets('is step 4 of 7', (tester) async {
      final handle = tester.ensureSemantics();
      await reachFriends(tester);

      expect(find.bySemanticsLabel('Step 4 of 7'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('asks before it reads anything', (tester) async {
      await reachFriends(tester);

      expect(find.text('Find friends from contacts'), findsOneWidget);
      expect(contactReads, 0, reason: 'nothing is read until it is asked for');
      expect(friendsRepository.calls, isEmpty);
    });

    testWidgets('does not repeat the design\'s untrue privacy line',
        (tester) async {
      // The prototype says "We don't upload your contacts. Matching happens on
      // your phone." No scheme that finds friends among strangers can do that,
      // so the line the app ships says what actually happens (D121).
      await reachFriends(tester);

      expect(find.textContaining('Matching happens on your phone'), findsNothing);
      expect(find.text(OnboardingFriendsStep.privacyLine), findsOneWidget);
    });
  });

  group('finding friends', () {
    testWidgets('matches contacts and ticks everybody it found',
        (tester) async {
      contactBook = ['012-345 6789', '+60 19 876 5432'];
      friendsRepository = FakeFriendsRepository(matches: _designMatches());
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(contactReads, 1);
      expect(find.byType(PersonRow), findsNWidgets(6));
      expect(find.text('Aiman Zulkifli'), findsOneWidget);
      // The design's own sentence, with its number read off the result.
      expect(
        find.textContaining('Six of your contacts are already on Ngap'),
        findsOneWidget,
      );
      // The button counts ticks, not matches, and everybody starts ticked.
      expect(primaryButton('Add 6 friends'), findsOneWidget);
    });

    testWidgets('what leaves is a hash, never a number', (tester) async {
      // The one property whose failure is silent: a scheme that sent numbers
      // would work perfectly and be wrong.
      contactBook = ['012-345 6789'];

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(friendsRepository.sentHashes, hasLength(1));
      final sent = friendsRepository.sentHashes.single;
      expect(sent, hasLength(1));
      expect(sent.single, hasLength(64));
      expect(sent.single, isNot(contains('123456789')));
    });

    testWidgets('unticking somebody changes the count on the button',
        (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(matches: _designMatches());
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Danial Ng'));
      await tester.pumpAndSettle();
      expect(primaryButton('Add 5 friends'), findsOneWidget);

      await tester.tap(find.text('Priya Raj'));
      await tester.pumpAndSettle();
      expect(primaryButton('Add 4 friends'), findsOneWidget);
    });

    testWidgets('untick everybody and the button is a plain Continue',
        (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(
        matches: [testFriend('u1', name: 'Aiman Zulkifli')],
      );
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();
      expect(primaryButton('Add 1 friend'), findsOneWidget);

      await tester.tap(find.text('Aiman Zulkifli'));
      await tester.pumpAndSettle();

      // Not "Add 0 friends".
      expect(primaryButton('Continue'), findsOneWidget);
    });

    testWidgets('nobody matched says so and still lets you through',
        (tester) async {
      contactBook = ['012-345 6789'];

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nobody in your contacts is on Ngap yet'),
        findsOneWidget,
      );
      expect(find.byType(PersonRow), findsNothing);
      expect(primaryButton('Continue'), findsOneWidget);
    });

    testWidgets('a refused permission reads as nobody, not as an error',
        (tester) async {
      // The reader returns an empty list when the sheet is declined. Being
      // told you have no friends here because you said no would be a strange
      // thing to read, so the two states are deliberately the same screen.
      contactBook = [];

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nobody in your contacts'), findsOneWidget);
      expect(find.textContaining('Could not check'), findsNothing);
    });

    testWidgets('a failed match says so without blocking the wizard',
        (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository.failMatchWith = StateError('offline');

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not check your contacts'),
          findsOneWidget);
      expect(primaryButton('Continue'), findsOneWidget);
    });
  });

  group('Skip', () {
    testWidgets('sends nothing and reads nothing', (tester) async {
      // The load-bearing assertion of the whole step. Skip is a person saying
      // stay out of my address book; the way to honour that is to not go in,
      // not to go in and send an empty list.
      contactBook = ['012-345 6789'];

      await reachFriends(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(contactReads, 0);
      expect(friendsRepository.calls, isEmpty);
      expect(friendsRepository.sentHashes, isEmpty);
      expect(friendsRepository.actions, isEmpty);
      expect(find.text('How do you eat?'), findsOneWidget);
    });

    testWidgets('after a match, Skip drops the ticks too', (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(matches: _designMatches());
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      await tester.tap(primaryButton('Continue')); // location
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(friendsRepository.actions, isEmpty,
          reason: 'Skip after a match is still a no');
    });

    testWidgets('Skip during a slow search still sends nothing',
        (tester) async {
      // The race the guard exists to stop: tap Find, then tap Skip while the
      // permission sheet is still up. Skip clears the ticks and moves on, and
      // the search lands afterwards. Without the step check in `_findFriends`
      // the late result refills the set and the wizard sends requests to six
      // people who were never agreed to.
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(matches: _designMatches());
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );
      contactGate = Completer<void>();

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('How do you eat?'), findsOneWidget);

      // The address book arrives late.
      contactGate!.complete();
      await tester.pumpAndSettle();

      await tester.tap(primaryButton('Continue')); // location
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(friendsRepository.actions, isEmpty,
          reason: 'a result for a step the user left is not theirs to act on');
    });

    testWidgets('Continue cannot be tapped while contacts are being read',
        (tester) async {
      // Same race from the other side: leaving the step forward mid-search
      // would tick people in behind the user just as leaving it sideways does.
      // Here the button is simply not offered until the search lands.
      contactBook = ['012-345 6789'];
      contactGate = Completer<void>();

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pump();

      final button = tester.widget<AppPrimaryButton>(primaryButton('Continue'));
      expect(button.onPressed, isNull);

      contactGate!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppPrimaryButton>(primaryButton('Continue')).onPressed,
        isNotNull,
      );
    });
  });

  group('sending the requests', () {
    testWidgets('happens after the profile exists, not before', (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(matches: _designMatches());
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      expect(friendsRepository.actions, isEmpty,
          reason: 'ticking somebody sends nothing yet');

      await finishFromFriends(tester, 'Add 6 friends');

      expect(onboarding.sentParams, isNotNull);
      expect(
        friendsRepository.actions.map((a) => a.$1),
        containsAll(['u1', 'u2', 'u3', 'u4', 'u5', 'u6']),
      );
      expect(
        friendsRepository.actions.map((a) => a.$2).toSet(),
        {FriendAction.send},
      );
    });

    testWidgets('a request that will not send does not undo the setup',
        (tester) async {
      contactBook = ['012-345 6789'];
      friendsRepository = FakeFriendsRepository(
        matches: [testFriend('u1', name: 'Aiman Zulkifli')],
      );
      friends.dispose();
      friends = FriendsController(
        repository: friendsRepository,
        followAuthChanges: false,
      );

      await reachFriends(tester);
      await tester.tap(find.text('Find friends from contacts'));
      await tester.pumpAndSettle();

      // Fails every send from here on.
      friendsRepository.failActWith = StateError('offline');

      await finishFromFriends(tester, 'Add 1 friend');

      expect(onboarding.sentParams, isNotNull,
          reason: 'the profile was still written');
      expect(auth.user?.name, 'Aisyah',
          reason: 'and the wizard still handed off');
    });

    testWidgets('nothing ticked sends no requests at all', (tester) async {
      await reachFriends(tester);

      await finishFromFriends(tester, 'Continue');

      expect(onboarding.sentParams, isNotNull);
      expect(friendsRepository.calls, isEmpty);
    });
  });

  group('narrow and large', () {
    testWidgets('the matched step survives 320 px at double text',
        (tester) async {
      useViewport(tester, const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OnboardingFriendsStep(
                    matches: _designMatches(),
                    selectedIds: const {'u1', 'u2', 'u3'},
                    hasSearched: true,
                    isSearching: false,
                    onFindFriends: () {},
                    onToggle: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Eat with people'), findsOneWidget);
    });

    testWidgets('so does the asking state', (tester) async {
      useViewport(tester, const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: OnboardingFriendsStep(
                    matches: [],
                    selectedIds: {},
                    hasSearched: false,
                    isSearching: false,
                    onFindFriends: _nothing,
                    onToggle: _nothingWith,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // At this scale the heading alone fills a 640 pt screen, so the button
      // is below the fold rather than missing.
      await tester.scrollUntilVisible(
        find.text('Find friends from contacts'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Find friends from contacts'), findsOneWidget);
    });
  });
}

void _nothing() {}

void _nothingWith(String _) {}
