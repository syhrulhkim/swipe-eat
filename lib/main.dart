import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/swipe_eat_app.dart';
import 'core/config/app_config.dart';
import 'core/observability/crash_reporting.dart';
import 'core/push/push_service.dart';
import 'dev/calendar_dev_data.dart';
import 'dev/friends_dev_data.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/friends/state/friends_controller.dart';
import 'features/plans/state/plans_controller.dart';

Future<void> main() async {
  // Everything the app does at startup runs inside the reporting zone, so a
  // failure to reach Supabase on launch is a report rather than a silent white
  // screen.
  await runWithCrashReporting(_startApp);
}

const bool _useDevPlans = bool.fromEnvironment('USE_DEV_PLANS');

/// Its own flag, because restaurants are real data and the friend cast is not.
const bool _useDevFriends = bool.fromEnvironment('USE_DEV_FRIENDS');

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  if (_useDevPlans) {
    PlansController.instance = PlansController(
      repository: DevPlansRepository(),
      followAuthChanges: false,
    );
  }

  if (_useDevFriends) {
    FriendsController.instance = FriendsController(
      repository: DevFriendsRepository(),
      followAuthChanges: false,
    );
  }

  // Null on every build made without the five Firebase defines — every test,
  // every local run — so nothing below it exists either (D155).
  final push = await _startPush();

  final controller = AuthController(
    AuthRepository(beforeSignOut: push?.service.forgetDevice),
  );
  // Not awaited: the controller starts in AuthStatus.unknown and the router
  // holds on the splash route until it resolves, so the first frame paints
  // immediately instead of after a network round trip.
  unawaited(controller.bootstrap());

  runApp(
    SwipeEatApp(authController: controller, pushRoute: push?.route),
  );
}

/// Brings Firebase up and starts listening, or returns null when this build
/// has no push.
///
/// A failure here is survivable: the app's own job is dinner, and a phone that
/// cannot register for notifications should still open.
Future<({PushService service, ValueNotifier<String?> route})?>
    _startPush() async {
  if (!AppConfig.hasPush) {
    return null;
  }

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseAppId,
        projectId: AppConfig.firebaseProjectId,
        messagingSenderId: AppConfig.firebaseSenderId,
        // Null rather than empty on an Android-only build: an empty string is
        // a bundle id that matches nothing, and this field has no meaning off
        // iOS.
        iosBundleId: AppConfig.firebaseIosBundleId.isEmpty
            ? null
            : AppConfig.firebaseIosBundleId,
      ),
    );

    final route = ValueNotifier<String?>(null);
    final service = PushService(
      messaging: FirebaseMessagingAdapter(),
      route: route,
    );
    // Not awaited: it asks the OS for permission, and the first frame must not
    // wait behind a system prompt.
    unawaited(service.start());
    return (service: service, route: route);
  } on Object catch (error) {
    debugPrint('Push could not start: $error');
    return null;
  }
}
