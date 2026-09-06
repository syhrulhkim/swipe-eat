import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/tiktok_thumbnail_placeholder.dart';
import '../data/auth_cover_repository.dart';

/// The wordmark, top-left of the welcome and sign-up screens.
///
/// The full stop is ember. It is the one orange mark in the app that is not a
/// control — the product is named after the bite, and the stop is where the
/// name lands.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final style = appBrandStyle(context);

    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'Ngap'),
          TextSpan(text: '.', style: TextStyle(color: kAccentEmber)),
        ],
      ),
      style: style,
      semanticsLabel: 'Ngap',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The design's `.textbtn`: a quiet label that navigates or reveals — "Later",
/// "Use email instead". Drawn at 13 px, tapped at [kMinTapTarget].
class AuthTextButton extends StatelessWidget {
  const AuthTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;

  /// Null disables it, which is how a screen says "not while that request is
  /// in flight" without swapping the control for something else.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      // The Text inside would merge its own node into this one; excluding it
      // keeps the announced name exactly the label, and excluding drops the
      // InkWell's action, so it is re-declared here (D83).
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusPill),
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  }
                : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // `widthFactor: 1` so the box hugs the label instead of
              // swelling to whatever width a Row hands it — the label has to
              // sit where it is drawn, not adrift in a wide tap area. Under a
              // tight width (a stretched Column) it still fills and centres.
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: kTextOnPhotoSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One sign-in provider — the design's `.su .btn`.
///
/// Left-aligned behind a round mark, and 52 px rather than the app's usual
/// bar height: these are the only buttons on their screen, they stack, and
/// the eye reads a stack down its left edge.
///
/// Two fills only, as everywhere else (D62): [AuthProviderButton.primary] is
/// the ember gradient, [AuthProviderButton.ghost] the panel with a hairline.
class AuthProviderButton extends StatelessWidget {
  const AuthProviderButton.primary({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  }) : _primary = true;

  const AuthProviderButton.ghost({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  }) : _primary = false;

  final String label;

  /// The glyph inside the round mark, drawn in the button's own background so
  /// the mark reads as punched out of the fill.
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool _primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = _primary ? kOnAccent : kTextOnPhoto;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
      side: _primary ? BorderSide.none : const BorderSide(color: kHairline),
    );

    final button = Material(
      color: _primary ? Colors.transparent : kSurfacePanel,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: Container(
          height: kAuthButtonHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (busy)
                SizedBox(
                  width: kAuthProviderMarkSize,
                  height: kAuthProviderMarkSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Container(
                  width: kAuthProviderMarkSize,
                  height: kAuthProviderMarkSize,
                  decoration: BoxDecoration(
                    color: foreground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 13,
                    color: _primary ? kAccentEmber : kBackgroundDark,
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: _primary
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: kCtaGradient,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
                child: button,
              )
            : button,
      ),
    );
  }
}

/// A restaurant cover on a signed-out screen: the picture, a scrim, and the
/// name low over it.
///
/// A null [cover] is the offline case, and it draws as a plain surface with no
/// name — a card with nothing in it still says "a card goes here", where a
/// gap in the stack says the screen is broken.
class AuthCoverCard extends StatelessWidget {
  const AuthCoverCard({
    super.key,
    required this.cover,
    this.bitten = false,
    this.caption,
  });

  final AuthCover? cover;

  /// The middle card of the welcome stack carries the bite, as the prototype
  /// does — the signature is on screen before the word "Ngap" is explained.
  final bool bitten;

  /// Replaces the name with a two-line caption, which is what the sign-up
  /// hero shows instead.
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final url = cover?.imageUrl;
    final name = cover?.name;

    return BiteNotch(
      bitten: bitten,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: kSurfaceDark),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const TikTokThumbnailPlaceholder(),
              )
            else if (cover != null)
              const TikTokThumbnailPlaceholder(),
            if (name != null || caption != null) const PhotoTileScrim(),
            if (caption != null)
              Positioned(left: 16, right: 16, bottom: 16, child: caption!)
            else if (name != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appCoverNameStyle(context),
                ),
              ),
            // Inside the clip, so the notch cuts the outline too — a hairline
            // that survived the bite would draw a ring across it.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(kRadiusCard)),
                  border: Border.fromBorderSide(BorderSide(color: kHairline)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's one shadow, cast behind a card in the welcome stack.
///
/// Separate from [AuthCoverCard] because a shadow cannot live inside the clip
/// that cuts the bite — and the sign-up hero, which the design draws flat
/// against the screen, does not want one at all.
class AuthCardShadow extends StatelessWidget {
  const AuthCardShadow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusCard),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }
}
