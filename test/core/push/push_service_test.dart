import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import 'package:swipe_eat/core/push/push_service.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart'
    show LikesAuthEvents;

import 'fake_push_repository.dart';

/// The auth seam the rest of the app uses, with a stream a test can push a
/// sign-in down. Nothing here touches a Supabase singleton.
class _FakeAuthEvents extends LikesAuthEvents {
  // Lives for the length of one test and dies with it.
  // ignore: close_sinks
  final StreamController<AuthState> events = StreamController.broadcast();

  @override
  Stream<AuthState>? get changes => events.stream;

  @override
  String? get currentUserId => 'me';
}

({
  PushService service,
  FakePushMessaging messaging,
  FakePushRepository repository,
  ValueNotifier<String?> route,
  _FakeAuthEvents auth,
}) build({String? token = 'device-token', Map<String, dynamic>? launched}) {
  final messaging = FakePushMessaging(token: token, launchMessage: launched);
  final repository = FakePushRepository();
  final route = ValueNotifier<String?>(null);
  final auth = _FakeAuthEvents();
  final service = PushService(
    messaging: messaging,
    route: route,
    repository: repository,
    authEvents: auth,
    platform: 'android',
  );

  addTearDown(() async {
    await service.dispose();
    await messaging.dispose();
    route.dispose();
  });

  return (
    service: service,
    messaging: messaging,
    repository: repository,
    route: route,
    auth: auth,
  );
}

void main() {
  group('claiming the device', () {
    test('start asks for permission and saves the token it is given',
        () async {
      final t = build();

      await t.service.start();

      expect(t.messaging.calls, contains('requestPermission'));
      expect(t.repository.saved.single, ('device-token', 'android'));
    });

    test('no token yet saves nothing, and the refresh catches up', () async {
      // iOS has no token until APNs has registered, which can be after
      // launch. Saving a null would be a row with no device in it.
      final t = build(token: null);

      await t.service.start();
      expect(t.repository.saved, isEmpty);

      t.messaging.refreshes.add('late-token');
      await Future<void>.delayed(Duration.zero);

      expect(t.repository.saved.single, ('late-token', 'android'));
    });

    test('a token that changes replaces the row', () async {
      final t = build();
      await t.service.start();

      t.messaging.refreshes.add('second-token');
      await Future<void>.delayed(Duration.zero);

      expect(t.repository.saved, [
        ('device-token', 'android'),
        ('second-token', 'android'),
      ]);
    });

    test('signing in claims the token again', () async {
      // The service starts before the session resolves, so the first save can
      // land with nobody signed in — the repository drops it, and this is the
      // second chance that makes the token reachable.
      final t = build();
      await t.service.start();

      t.auth.events.add(const AuthState(AuthChangeEvent.signedIn, null));
      await Future<void>.delayed(Duration.zero);

      expect(t.repository.saved, hasLength(2));
    });

    test('a refused save does not take the launch down with it', () async {
      final t = build();
      t.repository.failSaveWith = StateError('offline');

      await t.service.start();

      expect(t.repository.saved, isEmpty);
      expect(t.service.deviceToken, 'device-token');
    });
  });

  group('opening a notification', () {
    test('a tapped invite asks the router for that plan', () async {
      final t = build();
      await t.service.start();

      t.messaging.openings.add({'type': 'plan_invite', 'plan_id': '42'});
      await Future<void>.delayed(Duration.zero);

      expect(t.route.value, '/plans/42');
    });

    test('a notification that launched the app is read at start', () async {
      final t = build(
        launched: {'type': 'join_accepted', 'plan_id': '9'},
      );

      await t.service.start();

      expect(t.messaging.calls, contains('initialMessage'));
      expect(t.route.value, '/plans/9');
    });

    test('a message this build cannot read leaves the route alone', () async {
      final t = build();
      await t.service.start();

      t.messaging.openings.add({'type': 'something_new', 'plan_id': '42'});
      await Future<void>.delayed(Duration.zero);

      expect(t.route.value, isNull);
    });
  });

  group('signing out', () {
    test('drops this device row, once', () async {
      final t = build();
      await t.service.start();

      await t.service.forgetDevice();
      await t.service.forgetDevice();

      expect(t.repository.deleted, ['device-token']);
    });

    test('a delete that fails still lets the sign-out through', () async {
      final t = build();
      await t.service.start();
      t.repository.failDeleteWith = StateError('offline');

      await expectLater(t.service.forgetDevice(), completes);
    });

    test('a device that never had a token asks nothing', () async {
      final t = build(token: null);
      await t.service.start();

      await t.service.forgetDevice();

      expect(t.repository.deleted, isEmpty);
    });
  });
}
