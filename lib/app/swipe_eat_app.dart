import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/state/auth_controller.dart';
import 'app_router.dart';

class SwipeEatApp extends StatefulWidget {
  const SwipeEatApp({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<SwipeEatApp> createState() => _SwipeEatAppState();
}

class _SwipeEatAppState extends State<SwipeEatApp> {
  late final GoRouter _router = createRouter(widget.authController);

  @override
  Widget build(BuildContext context) {
    final theme = const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      routerConfig: _router,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
      ],
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) {
        final safeChild = child ?? const SizedBox.shrink();
        return Material(
          type: MaterialType.transparency,
          child: FTheme(
            data: theme,
            child: FToaster(
              child: FTooltipGroup(child: safeChild),
            ),
          ),
        );
      },
    );
  }
}
