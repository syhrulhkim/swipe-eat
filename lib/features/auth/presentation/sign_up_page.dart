import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../data/auth_cover_repository.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';
import 'email_auth_form.dart';

/// The one way into an account (design 01b).
///
/// It serves the new user and the returning one with the same buttons —
/// "Continue with…" creates the account or signs into it, and the user is not
/// asked to know which. Which buttons appear depends on what the build can
/// actually do: phone needs an SMS provider (D113), Google needs client ids,
/// Apple needs an Apple device. Email is what is left when none of those are
/// configured (D114).
class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.authController,
    this.loadCovers = loadAuthCovers,
    this.openUrl = launchUrl,
  });

  final AuthController authController;

  /// See [WelcomePage.loadCovers] — the same anonymous catalogue read.
  final AuthCoverLoader loadCovers;

  /// `url_launcher` talks to a platform channel that has no implementation
  /// under `flutter test`, so the legal links are injectable.
  final Future<bool> Function(Uri url, {LaunchMode mode}) openUrl;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  AuthCover? _cover;
  bool _showEmailForm = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _open(AppConfig.termsUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _open(AppConfig.privacyPolicyUrl);
    unawaited(_load());
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final covers = await widget.loadCovers(1);
      if (!mounted) {
        return;
      }
      setState(() => _cover = covers.isEmpty ? null : covers.first);
    } on Object catch (_) {
      // Offline: the hero stays a plain surface and keeps its caption. See
      // [WelcomePage].
      if (!mounted) {
        return;
      }
      setState(() => _cover = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(String url) async {
    final launched = await widget.openUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('Could not open the page.');
  }

  Future<void> _run(Future<bool> Function() action) async {
    final ok = await action();
    if (ok || !mounted) {
      // On success the router redirect takes over.
      return;
    }
    _showMessage(widget.authController.errorMessage ?? 'Sign-in failed.');
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.authController;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.dashboardMaxWidth,
                ),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(context, constraints.maxHeight),
                              _foot(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, double viewportHeight) {
    final controller = widget.authController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          // `spaceBetween` rather than a `Spacer`: a third flex child would
          // take a third of the row and leave the label short of the edge.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Both sides flex: at a large text scale the wordmark and the
            // label are each wide enough to push the other off the screen.
            const Flexible(child: AuthBrand()),
            // Anonymous browsing is not switched on for the project, so the
            // escape hatch only exists in a build that asked for it (D115).
            if (controller.supportsGuestBrowsing)
              Flexible(
                child: AuthTextButton(
                  label: 'Later',
                  onPressed: controller.isBusy
                      ? null
                      : () => _run(controller.continueAsGuest),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: math.max(viewportHeight * kAuthHeroFraction, 150),
          child: AuthCoverCard(
            cover: _cover,
            caption: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save your bites across phones',
                  style: appCoverNameStyle(context),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your likes, plans and wishlist follow you.',
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    color: kTextOnPhotoSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "Let's get you in",
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontFamily: kDisplayFontFamily,
                color: kTextOnPhoto,
                fontSize: kFontSizeH1,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.6,
              ),
        ),
      ],
    );
  }

  Widget _foot(BuildContext context) {
    final controller = widget.authController;
    final busy = controller.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (_showEmailForm)
          EmailAuthForm(
            authController: controller,
            onDismiss: () => setState(() => _showEmailForm = false),
          )
        else ...[
          if (controller.supportsPhoneSignIn) ...[
            AuthProviderButton.primary(
              label: 'Continue with phone number',
              icon: Icons.smartphone_rounded,
              onPressed: busy ? null : () => context.push('/signup/phone'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (controller.supportsAppleSignIn) ...[
            AuthProviderButton.ghost(
              label: 'Continue with Apple',
              icon: Icons.apple,
              onPressed: busy ? null : () => _run(controller.signInWithApple),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (controller.supportsGoogleSignIn) ...[
            AuthProviderButton.ghost(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata_rounded,
              onPressed: busy ? null : () => _run(controller.signInWithGoogle),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Center(
            child: AuthTextButton(
              label: 'Use email instead',
              onPressed:
                  busy ? null : () => setState(() => _showEmailForm = true),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        _legal(context),
      ],
    );
  }

  Widget _legal(BuildContext context) {
    const base = TextStyle(
      fontFamily: kTextFontFamily,
      fontSize: kFontSizeMicro,
      color: kTextOnPhotoMuted,
      height: 1.5,
    );
    // The two links are the only cream in the line: they are the only part of
    // it that does anything.
    final link = base.copyWith(
      color: kTextOnPhoto,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: kTextOnPhotoMuted,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(text: 'Terms', style: link, recognizer: _termsTap),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: _privacyTap,
          ),
          const TextSpan(
            text: '. We never post without asking.',
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
