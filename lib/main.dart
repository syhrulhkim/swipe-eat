import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/swipe_eat_app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  final controller = AuthController(AuthRepository());
  // Not awaited: the controller starts in AuthStatus.unknown and the router
  // holds on the splash route until it resolves, so the first frame paints
  // immediately instead of after a network round trip.
  unawaited(controller.bootstrap());

  runApp(SwipeEatApp(authController: controller));
}
