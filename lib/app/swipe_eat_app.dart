import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/ui/design_tokens.dart';
import '../features/auth/state/auth_controller.dart';
import 'app_router.dart';

/// Applies the app's two faces to a Material text theme: the display face on
/// everything from `titleLarge` up, the text face on the rest.
///
/// Split here rather than per-widget so a screen that reaches for
/// `textTheme.headlineSmall` gets the display face without knowing it exists.
TextTheme _applyAppFonts(TextTheme base) {
  final display = base
      .copyWith(
        displayLarge: base.displayLarge,
        displayMedium: base.displayMedium,
        displaySmall: base.displaySmall,
        headlineLarge: base.headlineLarge,
        headlineMedium: base.headlineMedium,
        headlineSmall: base.headlineSmall,
        titleLarge: base.titleLarge,
      )
      .apply(fontFamily: kDisplayFontFamily);

  return base.apply(fontFamily: kTextFontFamily).copyWith(
        displayLarge: display.displayLarge,
        displayMedium: display.displayMedium,
        displaySmall: display.displaySmall,
        headlineLarge: display.headlineLarge,
        headlineMedium: display.headlineMedium,
        headlineSmall: display.headlineSmall,
        titleLarge: display.titleLarge,
      );
}

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
    // Theme.of(context).textTheme inherits the app's faces and near-black
    // canvas rather than forui's own neutrals and the platform font.
    final baseMaterialTheme = theme.toApproximateMaterialTheme();
    final materialTheme = baseMaterialTheme.copyWith(
      scaffoldBackgroundColor: kBackgroundDark,
      canvasColor: kBackgroundDark,
      textTheme: _applyAppFonts(baseMaterialTheme.textTheme),
      primaryTextTheme: _applyAppFonts(baseMaterialTheme.primaryTextTheme),
      colorScheme: baseMaterialTheme.colorScheme.copyWith(
        primary: kAccentEmber,
        onPrimary: kOnAccent,
        secondary: kAccentCream,
        onSecondary: kOnAccent,
        surface: kSurfaceDark,
      ),
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
