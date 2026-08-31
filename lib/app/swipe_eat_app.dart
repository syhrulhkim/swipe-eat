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

/// Text fields, styled once for the whole app.
///
/// Left to the forui-derived approximation the fields kept forui's own
/// neutrals and an underline, which read as a different app from the flat
/// panels around them. Filled panels with a hairline and a warm focus ring
/// match the rest of the surface vocabulary.
InputDecorationTheme _inputDecorationTheme(TextTheme text) {
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusPanel),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecorationTheme(
    filled: true,
    fillColor: kSurfacePanel,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(kHairline, 1),
    enabledBorder: border(kHairline, 1),
    focusedBorder: border(kAccentEmber, 1.5),
    errorBorder: border(kTintSpice, 1),
    focusedErrorBorder: border(kTintSpice, 1.5),
    labelStyle: text.bodyMedium?.copyWith(color: kTextOnPhotoMuted),
    floatingLabelStyle: text.bodySmall?.copyWith(color: kAccentEmber),
    hintStyle: text.bodyMedium?.copyWith(color: kTextOnPhotoMuted),
    errorStyle: text.bodySmall?.copyWith(color: kTintSpice),
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
    final textTheme = _applyAppFonts(baseMaterialTheme.textTheme);
    final materialTheme = baseMaterialTheme.copyWith(
      scaffoldBackgroundColor: kBackgroundDark,
      canvasColor: kBackgroundDark,
      textTheme: textTheme,
      primaryTextTheme: _applyAppFonts(baseMaterialTheme.primaryTextTheme),
      inputDecorationTheme: _inputDecorationTheme(textTheme),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kAccentEmber),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kSurfacePanel,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: kTextOnPhoto),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPanel),
        ),
      ),
      // Material's own defaults for these are rounded and reach the screen
      // without passing through any of the app's widgets, so they are pinned
      // to the app's radii here rather than left to the framework.
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPanel),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPanel),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPanel),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(kRadiusSheet),
          ),
        ),
      ),
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
