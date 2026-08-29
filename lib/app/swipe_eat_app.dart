import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/state/auth_controller.dart';
import 'app_router.dart';

/// The reference design's neo-grotesque sans. forui already bundles the full
/// Inter family (100-900) as a package font, so there is nothing to download
/// and nothing to declare in pubspec assets.
const String kAppFontFamily = 'packages/forui/Inter';

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

    // Applied over the forui-derived Material theme so every screen that reads
    // Theme.of(context).textTheme inherits Inter, not the platform font.
    final baseMaterialTheme = theme.toApproximateMaterialTheme();
    final materialTheme = baseMaterialTheme.copyWith(
      textTheme: baseMaterialTheme.textTheme.apply(fontFamily: kAppFontFamily),
      primaryTextTheme:
          baseMaterialTheme.primaryTextTheme.apply(fontFamily: kAppFontFamily),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      routerConfig: _router,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
      ],
      theme: materialTheme,
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
