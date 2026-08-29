import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/auth/data/auth_repository.dart';
import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';

import 'fake_auth_repository.dart';

AppUser _user({DateTime? onboardedAt}) => AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: 'Demo User',
      email: 'demo@swipeeat.test',
      onboardedAt: onboardedAt,
    );

void main() {
  group('AuthController', () {
    late FakeAuthRepository repository;
    late AuthController controller;

    setUp(() {
    // The auth controller caches the profile on the device; without a fake
    // store behind it every resolve logs a missing-plugin failure.
    SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = FakeAuthRepository();
      controller = AuthController(repository);
    });

    tearDown(() async {
      controller.dispose();
      await repository.dispose();
    });

    test('starts unresolved so the router holds instead of guessing', () {
      expect(controller.status, AuthStatus.unknown);
      expect(controller.isResolved, isFalse);
      expect(controller.isAuthenticated, isFalse);
    });

    test('resolves to unauthenticated when there is no session', () async {
      await controller.bootstrap();

      expect(controller.isResolved, isTrue);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
    });

    test('stays unresolved until the profile lands', () async {
      repository
        ..sessionPresent = true
        ..profile = _user()
        ..profileGate = Completer<void>();

      final booting = controller.bootstrap();
      await Future<void>.delayed(Duration.zero);

      // A session exists but `needsOnboarding` is not yet knowable. Reporting
      // "authenticated" here is what makes the wrong screen flash.
      expect(controller.isResolved, isFalse,
          reason: 'must not resolve on a session alone');

      repository.profileGate!.complete();
      await booting;

      expect(controller.isResolved, isTrue);
      expect(controller.isAuthenticated, isTrue);
    });

    test('needsOnboarding follows the profile onboarded_at', () async {
      repository
        ..sessionPresent = true
        ..profile = _user();
      await controller.bootstrap();
      expect(controller.needsOnboarding, isTrue);

      repository.profile = _user(onboardedAt: DateTime(2026, 8, 23));
      await controller.refreshUser();
      expect(controller.needsOnboarding, isFalse);
    });

    test('markOnboarded closes the gate without a round trip', () async {
      repository
        ..sessionPresent = true
        ..profile = _user();
      await controller.bootstrap();
      final before = repository.calls.length;

      controller.markOnboarded(DateTime(2026, 8, 23));

      expect(controller.needsOnboarding, isFalse);
      expect(repository.calls.length, before, reason: 'no extra fetch');
    });

    test('login failure surfaces the mapped message, not a stack trace',
        () async {
      repository.nextFailure =
          const AuthFailure('That email and password do not match an account.');

      final ok = await controller.login(email: 'a@b.com', password: 'nope');

      expect(ok, isFalse);
      expect(controller.errorMessage,
          'That email and password do not match an account.');
      expect(controller.isAuthenticated, isFalse);
    });

    test('register reports confirmation-pending instead of signing in',
        () async {
      final ok = await controller.register(
        name: 'Jane',
        email: 'jane@example.com',
        password: 'password123',
      );

      expect(ok, isTrue);
      expect(controller.notice, contains('jane@example.com'));
      expect(controller.isAuthenticated, isFalse,
          reason: 'sign-up issues no session while confirmation is on');
    });

    test('register that returns a session does not raise a notice', () async {
      repository.signUpOutcome = SignUpOutcome.signedIn;

      await controller.register(
        name: 'Jane',
        email: 'jane@example.com',
        password: 'password123',
      );

      expect(controller.notice, isNull);
    });

    test('a signedOut event from elsewhere drops the session', () async {
      repository
        ..sessionPresent = true
        ..profile = _user(onboardedAt: DateTime(2026, 8, 23));
      await controller.bootstrap();
      expect(controller.isAuthenticated, isTrue);

      repository.sessionPresent = false;
      repository.emit(AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
    });

    test('a signedIn event reloads the profile', () async {
      await controller.bootstrap();
      expect(controller.isAuthenticated, isFalse);

      repository
        ..sessionPresent = true
        ..profile = _user(onboardedAt: DateTime(2026, 8, 23));
      repository.emit(AuthChangeEvent.signedIn);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isAuthenticated, isTrue);
      expect(controller.needsOnboarding, isFalse);
    });

    test('logout clears the user and the error', () async {
      repository
        ..sessionPresent = true
        ..profile = _user();
      await controller.bootstrap();

      await controller.logout();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
      expect(repository.calls, contains('logout'));
    });

    test('provider support is passed through from the repository', () {
      final configured = AuthController(
        FakeAuthRepository(supportsGoogleSignIn: true),
      );
      expect(configured.supportsGoogleSignIn, isTrue);
      expect(configured.supportsAppleSignIn, isFalse);
      configured.dispose();
    });
  });

  group('AppUser.fromProfile', () {
    test('prefers the profile row over the auth metadata', () {
      final user = AppUser.fromProfile(const {
        'id': 'abc',
        'name': 'Profile Name',
        'avatar_url': 'https://example.com/p.png',
        'onboarded_at': '2026-08-23T10:00:00Z',
      });

      expect(user.id, 'abc');
      expect(user.name, 'Profile Name');
      expect(user.avatarUrl, 'https://example.com/p.png');
      expect(user.needsOnboarding, isFalse);
    });

    test('an empty row still yields a usable placeholder', () {
      final user = AppUser.fromProfile(const {});

      expect(user.name, 'User');
      expect(user.email, '');
      expect(user.needsOnboarding, isTrue,
          reason: 'no onboarded_at means the wizard is still owed');
    });

    test('blank strings are treated as missing', () {
      final user = AppUser.fromProfile(const {
        'id': 'abc',
        'name': '   ',
        'avatar_url': '',
      });

      expect(user.name, 'User');
      expect(user.avatarUrl, isNull);
    });
  });
}
