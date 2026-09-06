import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/auth/data/auth_cover_repository.dart';
import 'package:swipe_eat/features/auth/data/auth_repository.dart';
import 'package:swipe_eat/features/auth/presentation/auth_widgets.dart';
import 'package:swipe_eat/features/auth/presentation/sign_up_page.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../support/widget_test_support.dart';
import 'fake_auth_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);
const Size _tabletViewport = Size(1024, 1366);
const TextScaler _hugeTextScale = TextScaler.linear(2);

const AuthCover _hero =
    AuthCover(name: 'Kak Ros', imageUrl: 'https://cdn.test/hero.jpg');

class _Harness {
  _Harness(this.repository, this.controller, this.router, this.openedUrls);

  final FakeAuthRepository repository;
  final AuthController controller;
  final GoRouter router;
  final List<String> openedUrls;
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  bool phone = false,
  bool google = false,
  bool apple = false,
  bool guest = false,
  AuthCoverLoader? loadCovers,
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final repository = FakeAuthRepository(
    supportsGoogleSignIn: google,
    supportsAppleSignIn: apple,
    supportsPhoneSignIn: phone,
    supportsGuestBrowsing: guest,
  );
  final controller = AuthController(repository);
  addTearDown(controller.dispose);
  addTearDown(repository.dispose);

  final opened = <String>[];

  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignUpPage(
          authController: controller,
          loadCovers: loadCovers ?? (limit) async => const [_hero],
          openUrl: (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
            opened.add(url.toString());
            return true;
          },
        ),
      ),
      GoRoute(
        path: '/signup/phone',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('phone screen')),
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

  return _Harness(repository, controller, router, opened);
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('SignUpPage', () {
    testWidgets('says what an account buys, over a real restaurant',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text("Let's get you in"), findsOneWidget);
      expect(find.text('Save your bites across phones'), findsOneWidget);
      expect(
        find.text('Your likes, plans and wishlist follow you.'),
        findsOneWidget,
      );
      expect(find.byType(AuthCoverCard), findsOneWidget);
    });

    testWidgets('a failed cover load leaves the hero and its caption',
        (tester) async {
      await _pumpPage(
        tester,
        loadCovers: (limit) async => throw const SocketException('offline'),
      );

      expect(find.byType(AuthCoverCard), findsOneWidget);
      expect(find.text('Save your bites across phones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SignUpPage provider gating', () {
    testWidgets('phone is offered only when the build enables it',
        (tester) async {
      await _pumpPage(tester, phone: true);
      expect(find.text('Continue with phone number'), findsOneWidget);
    });

    testWidgets('phone is hidden when the SMS provider is not switched on',
        (tester) async {
      await _pumpPage(tester);

      // The define is off by default, and a button that fails on tap is worse
      // than no button (D113).
      expect(find.text('Continue with phone number'), findsNothing);
    });

    testWidgets('Apple appears only where the native sheet exists',
        (tester) async {
      await _pumpPage(tester, apple: true);
      expect(find.text('Continue with Apple'), findsOneWidget);

      await _pumpPage(tester);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('Google appears only when the client ids were built in',
        (tester) async {
      await _pumpPage(tester, google: true);
      expect(find.text('Continue with Google'), findsOneWidget);

      await _pumpPage(tester);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('with nothing configured, email is still a way in',
        (tester) async {
      await _pumpPage(tester);

      // The reason email survives the redesign: a build with no phone, no
      // Google and no Apple would otherwise have no sign-in at all (D114).
      expect(find.text('Use email instead'), findsOneWidget);
    });

    testWidgets('the phone button opens the phone screen', (tester) async {
      await _pumpPage(tester, phone: true);

      await tester.tap(find.text('Continue with phone number'));
      await tester.pumpAndSettle();

      // Pushed, not replaced: the phone screen keeps the platform transition
      // and the swipe back to the ways in.
      expect(find.text('phone screen'), findsOneWidget);
    });

    testWidgets('Google hands the request to the repository', (tester) async {
      final harness = await _pumpPage(tester, google: true);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('google'));
    });

    testWidgets('a refused provider says so instead of failing silently',
        (tester) async {
      final harness = await _pumpPage(tester, apple: true);
      harness.repository.nextFailure =
          const AuthFailure('Apple sign-in was cancelled.');

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.text('Apple sign-in was cancelled.'), findsOneWidget);
    });
  });

  group('SignUpPage guest browsing', () {
    testWidgets('"Later" is hidden unless the build enables it',
        (tester) async {
      await _pumpPage(tester);
      expect(find.text('Later'), findsNothing);
    });

    testWidgets('"Later" signs in anonymously when it is enabled',
        (tester) async {
      final harness = await _pumpPage(tester, guest: true);

      expect(find.text('Later'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('guest'));
    });
  });

  group('SignUpPage email fallback', () {
    testWidgets('"Use email instead" reveals the form in place',
        (tester) async {
      await _pumpPage(tester, google: true);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      // The providers stand aside while the form is open, and come back.
      expect(find.text('Continue with Google'), findsNothing);

      await tester.tap(find.text('More ways in'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('signing in hands both fields to the repository',
        (tester) async {
      final harness = await _pumpPage(tester);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@swipeeat.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('login:demo@swipeeat.test'));
    });

    testWidgets('an empty form is refused before it reaches the network',
        (tester) async {
      final harness = await _pumpPage(tester);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(harness.repository.calls, isEmpty);
    });

    testWidgets('a wrong password is reported in the app\'s own words',
        (tester) async {
      final harness = await _pumpPage(tester);
      harness.repository.nextFailure =
          const AuthFailure('That email and password do not match an account.');

      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@swipeeat.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrong',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('That email and password do not match an account.'),
        findsOneWidget,
      );
    });

    testWidgets('creating an account asks for a name and lands on sign-in',
        (tester) async {
      final harness = await _pumpPage(tester);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Demo User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@swipeeat.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('register:demo@swipeeat.test'));
      // Confirmation is on, so the account exists but cannot sign in yet: the
      // form says so and goes back to sign-in rather than pretending.
      expect(
        find.textContaining('Open the confirmation link'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a short password is refused before the network',
        (tester) async {
      final harness = await _pumpPage(tester);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Demo User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@swipeeat.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );
      expect(harness.repository.calls, isEmpty);
    });

    testWidgets('the reset link is sent to the address on screen',
        (tester) async {
      final harness = await _pumpPage(tester);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // The password field is gone: a reset asks for one thing.
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@swipeeat.test',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('reset:demo@swipeeat.test'));
    });
  });

  group('SignUpPage legal', () {
    testWidgets('the line names both documents', (tester) async {
      await _pumpPage(tester);

      expect(
        find.textContaining('We never post without asking.'),
        findsOneWidget,
      );
    });

    testWidgets('Terms and Privacy Policy open their pages', (tester) async {
      final handle = tester.ensureSemantics();
      final harness = await _pumpPage(tester);

      tester.semantics.tap(find.semantics.byLabel('Terms'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(harness.openedUrls, hasLength(2));
      expect(harness.openedUrls.first, endsWith('/terms'));
      expect(harness.openedUrls.last, endsWith('/privacy'));

      handle.dispose();
    });
  });

  group('SignUpPage accessibility', () {
    testWidgets('every way in is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester, phone: true, google: true, apple: true);

      for (final label in [
        'Continue with phone number',
        'Continue with Apple',
        'Continue with Google',
        'Use email instead',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }

      handle.dispose();
    });

    testWidgets('a screen reader tap opens the email form', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      // Not a gesture: the semantics action itself, which is all an assistive
      // technology has (D83).
      tester.semantics.tap(find.semantics.byLabel('Use email instead'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the provider buttons are at least 44 pt tall',
        (tester) async {
      await _pumpPage(tester, phone: true, google: true);

      for (final label in [
        'Continue with phone number',
        'Continue with Google',
      ]) {
        final size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AuthProviderButton),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });
  });

  group('SignUpPage layout', () {
    testWidgets('does not overflow on the narrowest phone', (tester) async {
      await _pumpPage(
        tester,
        phone: true,
        google: true,
        apple: true,
        guest: true,
        viewport: _narrowViewport,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a huge text scale', (tester) async {
      await _pumpPage(
        tester,
        phone: true,
        google: true,
        apple: true,
        guest: true,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with the email form open', (tester) async {
      await _pumpPage(tester, viewport: _narrowViewport);
      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();
      // The longest form of the three, and on this viewport it is below the
      // fold — which is the point: the screen scrolls rather than overflowing.
      await tester.ensureVisible(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a tablet', (tester) async {
      await _pumpPage(tester, phone: true, viewport: _tabletViewport);
      expect(tester.takeException(), isNull);
    });
  });
}
