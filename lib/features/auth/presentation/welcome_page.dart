import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../data/auth_cover_repository.dart';
import 'auth_widgets.dart';

/// The first screen of the app (design S1).
///
/// It sells the product in one sentence and shows three real restaurants
/// behind it. Both buttons lead to the same place: the sign-up screen serves
/// the returning user and the new one, because with phone and Google as the
/// ways in there is no separate "sign in" form to send anybody to.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, this.loadCovers = loadAuthCovers});

  /// Injected so a widget test can hand the stack three covers — or a
  /// failure — without a network. Signed-out reads are anonymous, so this is
  /// the one query the app makes before anybody has an account.
  final AuthCoverLoader loadCovers;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  /// The design's stack is three cards, so three is what is asked for.
  static const _cardCount = 3;

  List<AuthCover> _covers = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final covers = await widget.loadCovers(_cardCount);
      if (!mounted) {
        return;
      }
      setState(() => _covers = covers);
    } on Object catch (_) {
      // Offline, or a build with no Supabase behind it. The stack keeps its
      // three cards as plain surfaces — a hole where the deck should be would
      // say the app is broken before it has said anything else.
      if (!mounted) {
        return;
      }
      setState(() => _covers = const []);
    }
  }

  AuthCover? _coverAt(int index) =>
      index < _covers.length ? _covers[index] : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const WelcomeGlow(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.dashboardMaxWidth,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                          child: Column(
                            // No flex children: the column is as tall as the
                            // viewport or as tall as its content, whichever is
                            // more, and the gap between the two groups is
                            // whatever is left over.
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StackPreview(
                                height:
                                    constraints.maxHeight * kAuthHeroFraction,
                                covers: [
                                  for (var i = 0; i < _cardCount; i++)
                                    _coverAt(i),
                                ],
                              ),
                              const _WelcomeCopy(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wordmark and the three-card deck under it.
class _StackPreview extends StatelessWidget {
  const _StackPreview({required this.height, required this.covers});

  final double height;
  final List<AuthCover?> covers;

  /// The design's `.card` transforms, in the order the prototype stacks them:
  /// back-left, back-right (the bitten one), then the front card square on.
  static const _angles = [-12.0, 9.0, -2.0];
  static const _offsets = [-38.0, 40.0, 0.0];
  static const _scales = [0.92, 0.96, 1.0];
  static const _opacities = [0.75, 0.85, 1.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthBrand(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          // The design gives the stack 38% of the screen. Scaled to fit rather
          // than clipped, so the three cards still read as a deck on a small
          // phone and at a large text scale.
          height: math.max(height, kWelcomeCardHeight * 0.5),
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              // Wide enough for the two translated cards and their rotation.
              width: kWelcomeCardWidth + 150,
              height: kWelcomeCardHeight + 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < covers.length; i++)
                    Transform.rotate(
                      angle: _angles[i] * math.pi / 180,
                      child: Transform.translate(
                        offset: Offset(_offsets[i], 0),
                        child: Transform.scale(
                          scale: _scales[i],
                          child: Opacity(
                            opacity: _opacities[i],
                            child: SizedBox(
                              width: kWelcomeCardWidth,
                              height: kWelcomeCardHeight,
                              child: AuthCardShadow(
                                child: AuthCoverCard(
                                  cover: covers[i],
                                  // The middle card carries the bite, as the
                                  // prototype does: the signature is on
                                  // screen before the word is explained.
                                  bitten: i == 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The headline, the promise, the two ways in, and the location line.
class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          // Two lines, as the design sets it: the question, then the answer.
          'Where to eat?\nSwipe it.',
          style: appWelcomeHeroStyle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            "Fifteen seconds of video per restaurant. Bite the ones you want, "
            "pick a day, bring whoever's hungry.",
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: kTextOnPhotoSecondary,
                  fontSize: kFontSizeBody,
                  height: 1.45,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Start swiping',
          expand: true,
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppSecondaryButton(
          label: 'I already have an account',
          expand: true,
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: AppSpacing.sm),
        const SizedBox(
          width: double.infinity,
          child: Text(
            'Uses your location to find places nearby',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeMicro,
              color: kTextOnPhotoMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
