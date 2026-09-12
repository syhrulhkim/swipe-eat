import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipe_eat/core/location/user_location.dart';
import 'package:swipe_eat/core/ui/app_buttons.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_page.dart';
import 'package:swipe_eat/features/friends/state/friends_controller.dart';
import 'package:swipe_eat/features/onboarding/presentation/onboarding_steps.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import '../friends/fake_friends_repository.dart';
import 'fake_onboarding_repository.dart';

Position _position({double latitude = 1.9, double longitude = 103.1}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
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

void main() {
  late FakeAuthRepository authRepository;
  late AuthController auth;
  late FakeOnboardingRepository onboarding;
  late FakeFriendsRepository friendsRepository;
  late FriendsController friends;

  /// The address book the wizard is given. Empty here — these tests walk past
  /// the friends step; `onboarding_friends_step_test.dart` is the one that
  /// stops on it.
  late List<String> contactBook;

  setUp(() async {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
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
  });

  tearDown(() async {
    friends.dispose();
    auth.dispose();
    await authRepository.dispose();
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    Future<Position> Function()? resolvePosition,
    Future<String?> Function(Position)? resolvePlace,
    Size viewport = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    // A phone-sized viewport, not the 800x600 default: the wizard's steps are
    // lazily built lists, and on a short surface the buttons at the bottom of
    // a step are never built at all.
    useViewport(tester, viewport);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: OnboardingPage(
              authController: auth,
              repository: onboarding,
              resolvePosition: resolvePosition ?? () async => _position(),
              resolvePlace: resolvePlace ?? (_) async => 'Peserai, Batu Pahat',
              readContacts: () async => contactBook,
              friends: friends,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The primary button carries the step's action label, so finding it by text
  /// also asserts which step we are on.
  Finder primaryButton(String label) =>
      find.widgetWithText(AppPrimaryButton, label);

  bool isEnabled(WidgetTester tester, Finder finder) =>
      tester.widget<AppPrimaryButton>(finder).onPressed != null;

  Future<void> completeNameStep(WidgetTester tester) async {
    // The step is a lazily built list: on a short screen at a large text size
    // the field starts below the fold, so it has to be scrolled to before it
    // exists at all.
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
  }

  Future<void> completeTasteStep(WidgetTester tester) async {
    await tester.tap(find.text('Malay'));
    await tester.pump();
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  /// The rules step sits between taste and habits and is skippable; most of
  /// the tests below are not about it, so they walk past it with Continue.
  Future<void> completeRulesStep(WidgetTester tester) async {
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  /// The friends step sits between the rules and the habits, and is skippable.
  /// Tests that are not about it walk past with Continue, which — with nobody
  /// matched and so nobody ticked — is what the button says.
  Future<void> completeFriendsStep(WidgetTester tester) async {
    await tester.tap(primaryButton('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
  }

  group('onboarding wizard', () {
    testWidgets('cannot leave step one without a name', (tester) async {
      await pumpWizard(tester);

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);

      await tester.enterText(find.byType(TextField), 'Aisyah');
      await tester.pump();

      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('does not prefill the handle_new_user placeholder name',
        (tester) async {
      // Every profile is seeded with 'User'; treating that as an answer would
      // let people through step one without ever naming themselves.
      await pumpWizard(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);
    });

    testWidgets('prefills the name an OAuth sign-in already knows',
        (tester) async {
      auth.applyUser(const AppUser(
        id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
        name: 'Aisyah',
        email: 'demo@swipeeat.test',
      ));

      await pumpWizard(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Aisyah');
      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('cannot leave the taste step without a cuisine',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);

      expect(find.text('What do you like to eat?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isFalse);

      await tester.tap(find.text('Malay'));
      await tester.pump();

      expect(isEnabled(tester, primaryButton('Continue')), isTrue);
    });

    testWidgets('the habits step edits the tiles and the radius',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);

      expect(find.text('How do you eat?'), findsOneWidget);
      expect(find.text('Any distance'), findsWidgets);

      await tester.tap(find.text('On').first); // morning mode
      await tester.pump();

      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('the habits step does not ask about spice a second time',
        (tester) async {
      // The rules step already took the answer on its four-step control and
      // `complete_onboarding` derives the bias from it (D104). A second tile
      // here would be a question whose answer is thrown away.
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);

      expect(find.text('How do you eat?'), findsOneWidget);
      expect(find.text('Spice bias'), findsNothing);
      expect(find.text('Morning mode'), findsOneWidget);
      expect(find.text('Nearby focus'), findsOneWidget);
    });

    testWidgets('a granted location is written with its place name',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Where are you eating?'), findsOneWidget);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(find.text('Peserai, Batu Pahat'), findsOneWidget);

      // Location is no longer the last step: the gesture primer sits after it,
      // and its button names what comes next rather than saying "Finish".
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Three moves'), findsOneWidget);

      await tester.tap(primaryButton('Show me dinner'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams, isNotNull);
      expect(onboarding.sentParams!['p_location_source'], 'gps');
      expect(onboarding.sentParams!['p_latitude'], 1.9);
      expect(onboarding.sentParams!['p_place_name'], 'Peserai, Batu Pahat');
      expect(onboarding.sentParams!['p_name'], 'Aisyah');
      expect(onboarding.sentParams!['p_cuisine_ids'], [1]);
      expect(auth.needsOnboarding, isFalse);
    });

    testWidgets('a fallback fix counts as no location, not a real one',
        (tester) async {
      // The fallback is a hardcoded Batu Pahat coordinate. Storing it would
      // tell the ranking the user is somewhere they have never been.
      await pumpWizard(tester,
          resolvePosition: () async => fallbackUserPosition());
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Location is off'), findsOneWidget);
      // Wait the snack bar out — it sits over the primary button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(primaryButton('Show me dinner'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams!['p_location_source'], 'denied');
      expect(onboarding.sentParams!['p_latitude'], isNull);
    });

    testWidgets('"Not now" records denied and finishes the wizard',
        (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(onboarding.completeCalls, 1);
      expect(onboarding.sentParams!['p_location_source'], 'denied');
      expect(auth.needsOnboarding, isFalse);
    });

    testWidgets('a failed write keeps the user in the wizard', (tester) async {
      onboarding.failComplete = true;
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);
      await completeRulesStep(tester);
      await completeFriendsStep(tester);
      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save your setup. Please try again.'),
          findsOneWidget);
      expect(auth.needsOnboarding, isTrue,
          reason: 'the gate must not open on a failed write');
      expect(find.text('Where are you eating?'), findsOneWidget);
    });

    testWidgets('going back keeps the answers already given', (tester) async {
      await pumpWizard(tester);
      await completeNameStep(tester);
      await completeTasteStep(tester);

      await tapBack(tester);

      expect(find.text('What do you like to eat?'), findsOneWidget);
      expect(isEnabled(tester, primaryButton('Continue')), isTrue,
          reason: 'the cuisine picked before Back is still selected');
    });

    testWidgets('an unreachable catalog offers a retry', (tester) async {
      onboarding.failCatalog = true;
      await pumpWizard(tester);

      expect(
          find.textContaining('Could not load the taste list'), findsOneWidget);

      onboarding.failCatalog = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsOneWidget);
    });
  });

  group('the rules step', () {
    Future<void> reachRules(
      WidgetTester tester, {
      Size? viewport,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      await pumpWizard(
        tester,
        viewport: viewport ?? const Size(390, 844),
        textScaler: textScaler,
      );
      await completeNameStep(tester);
      await completeTasteStep(tester);
    }

    /// Walks the rest of the wizard so the RPC payload can be inspected.
    Future<void> finishFromRules(WidgetTester tester) async {
      await tester.tap(primaryButton('Continue')); // friends
      await tester.pumpAndSettle();
      await tester.tap(primaryButton('Continue')); // habits
      await tester.pumpAndSettle();
      await tester.tap(primaryButton('Continue')); // location
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }

    testWidgets('sits between taste and the friends step', (tester) async {
      await reachRules(tester);

      expect(find.text('Any rules?'), findsOneWidget);
      expect(
        find.text("So we never show you somewhere you can't eat."),
        findsOneWidget,
        reason: 'every first-run step says why it is asking',
      );
      expect(find.text('Eat with people'), findsNothing);

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Eat with people'), findsOneWidget);
    });

    testWidgets('opens on the range the prototype shows, spice unset',
        (tester) async {
      await reachRules(tester);

      expect(find.text('RM 10–40'), findsOneWidget);
      expect(find.text('RM 5'), findsOneWidget);
      expect(find.text('RM 100+'), findsOneWidget);
      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the answers on screen reach the RPC', (tester) async {
      await reachRules(tester);

      await tester.tap(find.text('Halal only'));
      await tester.pump();
      await tester.tap(find.text('Pedas'));
      await tester.pump();
      await finishFromRules(tester);

      expect(onboarding.sentParams!['p_halal_only'], isTrue);
      expect(onboarding.sentParams!['p_vegetarian'], isFalse);
      expect(onboarding.sentParams!['p_spice_level'], 3);
      expect(onboarding.sentParams!['p_budget_min'], 10);
      expect(onboarding.sentParams!['p_budget_max'], 40);
      expect(onboarding.sentParams!['p_clear_budget'], isFalse);
    });

    testWidgets('Skip advances without writing any rule', (tester) async {
      await reachRules(tester);

      // Answer everything first, so a Skip that merely moved on would be
      // visible in the payload.
      await tester.tap(find.text('Halal only'));
      await tester.pump();
      await tester.tap(find.text('Bring it'));
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Eat with people'), findsOneWidget);

      await completeFriendsStep(tester);
      expect(find.text('How do you eat?'), findsOneWidget);

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams!['p_halal_only'], isFalse);
      expect(onboarding.sentParams!['p_spice_level'], isNull);
      expect(onboarding.sentParams!['p_budget_min'], isNull);
      expect(onboarding.sentParams!['p_clear_budget'], isTrue);
    });

    testWidgets('Skip is offered here and on the friends step', (tester) async {
      // Two of the seven steps are optional, and they are next to each other:
      // the rules, whose answers hide restaurants, and the friends step, which
      // asks for the address book. Everywhere else the slot is empty so the
      // topbar never shifts.
      await pumpWizard(tester);
      expect(find.text('Skip'), findsNothing);

      await completeNameStep(tester);
      expect(find.text('Skip'), findsNothing);

      await completeTasteStep(tester);
      expect(find.text('Skip'), findsOneWidget, reason: 'the rules step');

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsOneWidget, reason: 'the friends step');

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Skip'), findsNothing, reason: 'the habits step');
    });

    testWidgets('reads each switch and segment out as one control',
        (tester) async {
      final handle = tester.ensureSemantics();
      await reachRules(tester);

      expect(find.bySemanticsLabel('Halal only'), findsOneWidget);
      expect(find.bySemanticsLabel('Vegetarian options'), findsOneWidget);
      expect(find.bySemanticsLabel('Pedas'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('does not overflow at 320 px', (tester) async {
      await reachRules(tester, viewport: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('is step 3 of 7', (tester) async {
      // The wizard is seven steps, and the bar is the only thing that says how
      // many are left. A screen reader gets the same count in words.
      final handle = tester.ensureSemantics();
      await reachRules(tester);

      expect(find.bySemanticsLabel('Step 3 of 7'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('draws two steps done, this one on, and four ahead',
        (tester) async {
      // The bar has three states, not two (§7e): a bar that only fills says
      // "this much is done"; this one says "you are here, and there are four
      // more", which is the question a first run actually raises.
      await reachRules(tester);

      final colours = _stepBarColours(tester);

      expect(colours, hasLength(7));
      expect(colours.sublist(0, 2), everyElement(kCreamMuted),
          reason: 'name and taste are behind us');
      expect(colours[2], kAccentEmber, reason: 'the rules step is current');
      expect(colours.sublist(3), everyElement(kHairline),
          reason: 'friends, habits, location and the primer are ahead');
    });

    testWidgets('the spice segment starts with nothing chosen', (tester) async {
      // "Not answered" has to look different from "Mild": the step is
      // skippable, so a segment that defaulted to the first option would put
      // an answer on the profile that nobody gave.
      final handle = tester.ensureSemantics();
      await reachRules(tester);

      for (final label in const ['Mild', 'Medium', 'Pedas', 'Bring it']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
          ),
          reason: label,
        );
      }

      handle.dispose();
    });

    for (final (label, level) in const [
      ('Mild', 1),
      ('Medium', 2),
      ('Pedas', 3),
      ('Bring it', 4),
    ]) {
      testWidgets('"$label" reaches the RPC as $level', (tester) async {
        await reachRules(tester);

        await tester.tap(find.text(label));
        await tester.pump();
        await finishFromRules(tester);

        expect(onboarding.sentParams!['p_spice_level'], level);
      });
    }

    testWidgets('the top stop sends a floor with no ceiling', (tester) async {
      // The one path the draft tests cannot reach: the slider's own callback
      // turns "RM 100" into "no ceiling". A stored 100 would hide every place
      // priced above it rather than none of them.
      await reachRules(tester);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(
        100,
      );
      await tester.pumpAndSettle();
      expect(find.text('RM 10+'), findsOneWidget);

      await finishFromRules(tester);

      expect(onboarding.sentParams!['p_budget_min'], 10);
      expect(onboarding.sentParams!['p_budget_max'], isNull);
      expect(onboarding.sentParams!['p_clear_budget'], isFalse,
          reason: 'a floor with no ceiling is an answer, not a blank');
    });

    testWidgets('a chosen ceiling reaches the RPC as itself', (tester) async {
      await reachRules(tester);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(
        60,
      );
      await tester.pumpAndSettle();
      expect(find.text('RM 10–60'), findsOneWidget);

      await finishFromRules(tester);

      expect(onboarding.sentParams!['p_budget_min'], kBudgetDefaultMin,
          reason: 'the design draws one thumb over a fixed RM 10 floor');
      expect(onboarding.sentParams!['p_budget_max'], 60);
    });

    testWidgets('Skip sends nulls and falses, not the defaults on screen',
        (tester) async {
      await reachRules(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(primaryButton('Continue')); // friends
      await tester.pumpAndSettle();
      await tester.tap(primaryButton('Continue')); // location
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(onboarding.sentParams!['p_halal_only'], isFalse);
      expect(onboarding.sentParams!['p_vegetarian'], isFalse);
      expect(onboarding.sentParams!['p_spice_level'], isNull);
      expect(onboarding.sentParams!['p_budget_min'], isNull);
      expect(onboarding.sentParams!['p_budget_max'], isNull);
      expect(onboarding.sentParams!['p_clear_budget'], isTrue);
    });

    testWidgets('Back to taste and forward again keeps the answers',
        (tester) async {
      // The steps are a PageView, so the rules step is not rebuilt from
      // scratch on the way back — but the draft is the only thing that
      // remembers, and an answer lost between two taps is invisible until
      // the deck comes back wrong.
      await reachRules(tester);

      await tester.tap(find.text('Halal only'));
      await tester.pump();
      await tester.tap(find.text('Pedas'));
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(
        60,
      );
      await tester.pumpAndSettle();

      await tapBack(tester);
      expect(find.text('What do you like to eat?'), findsOneWidget);

      await tester.tap(primaryButton('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Any rules?'), findsOneWidget);
      expect(find.text('RM 10–60'), findsOneWidget);

      await finishFromRules(tester);

      expect(onboarding.sentParams!['p_halal_only'], isTrue);
      expect(onboarding.sentParams!['p_spice_level'], 3);
      expect(onboarding.sentParams!['p_budget_min'], kBudgetDefaultMin);
      expect(onboarding.sentParams!['p_budget_max'], 60);
    });

    testWidgets('survives 320 px at double text size', (tester) async {
      // Pumped on its own, the way the gesture primer is: walking the wizard
      // at this scale is a test of the two steps before it, and the layout
      // under test is this step's.
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
                  child: OnboardingRulesStep(
                    draft: OnboardingDraft(name: 'Aisyah'),
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Any rules?'), findsOneWidget);
      expect(find.text('Halal only'), findsOneWidget);

      // The step is a list, so the budget card starts below the fold at this
      // scale; scrolling to it is what lays it out.
      await tester.scrollUntilVisible(
        find.byType(Slider),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('RM 10\u201340'), findsOneWidget,
          reason: 'the read-out has to stay readable, not just fit');
    });
  });

  group('the gesture primer', () {
    Future<void> pumpPrimer(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: OnboardingHowToSwipeStep(),
            ),
          ),
        ),
      );
    }

    testWidgets('names all three moves and what each means', (tester) async {
      // The screen exists to teach the words. If the words are not on it, it
      // has no reason to be a step.
      await pumpPrimer(tester);

      expect(find.text('Three moves'), findsOneWidget);
      for (final pair in const [
        ('Ngap!', 'I want this'),
        ('Skip', 'Not tonight'),
        ('Later', 'Save without deciding'),
      ]) {
        expect(find.text(pair.$1), findsOneWidget, reason: pair.$1);
        expect(find.text(pair.$2), findsOneWidget, reason: pair.$2);
      }
    });

    testWidgets('reads each move as one sentence, not three fragments',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPrimer(tester);

      // One node per row: an arrow glyph announced on its own tells a screen
      // reader user nothing.
      expect(find.bySemanticsLabel('Ngap! — I want this'), findsOneWidget);
      expect(find.bySemanticsLabel('Skip — Not tonight'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Later — Save without deciding'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('says where a bite ends up', (tester) async {
      await pumpPrimer(tester);

      expect(
        find.textContaining('land in Your bites'),
        findsOneWidget,
      );
    });

    testWidgets('promises no super like', (tester) async {
      // Up is Later now. A primer that still taught a super like would be
      // teaching a gesture the app no longer has.
      await pumpPrimer(tester);

      expect(find.textContaining('Super'), findsNothing);
      expect(find.textContaining('Must try'), findsNothing);
    });
  });
}

/// The colour of each `.steps` segment, left to right.
///
/// Picked out by height: the step bar's segments are the only
/// [kStepBarHeight]-tall boxes on the screen, which keeps the segment pills
/// (36) and the switch tracks (30) out of the way.
List<Color?> _stepBarColours(WidgetTester tester) {
  return [
    for (final container
        in tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)))
      if (container.constraints?.maxHeight == kStepBarHeight)
        (container.decoration as BoxDecoration?)?.color,
  ];
}
