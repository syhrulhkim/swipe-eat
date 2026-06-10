import 'package:flutter/widgets.dart';

import 'app/swipe_eat_app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authController = await _createAuthController();
  runApp(SwipeEatApp(authController: authController));
}

Future<AuthController> _createAuthController() async {
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final authApi = AuthApi(apiClient);
  final tokenStorage = TokenStorage();
  final authRepository = AuthRepository(
    authApi: authApi,
    tokenStorage: tokenStorage,
  );

  final controller = AuthController(authRepository);
  await controller.bootstrap();
  return controller;
}
