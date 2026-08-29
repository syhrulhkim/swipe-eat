import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for the glassmorphic reference
// design. Every screen (deck, explore, likes, detail, nav) reads from here so
// colors, radii, blur strength and control sizes stay consistent.
// ---------------------------------------------------------------------------

/// Lime accent from the reference design: active/selected states.
const Color kAccentLime = Color(0xFFB4E33D);

/// Ink used on top of the lime accent (dark, near-black).
const Color kOnAccentLime = Color(0xFF10141B);

/// App background behind full-bleed content (deck, likes, detail below-fold).
const Color kBackgroundDark = Color(0xFF0C0F14);

/// Deepest background, used behind the explore map.
const Color kBackgroundDeep = Color(0xFF07090D);

/// Base tint of frosted panels/cards before the white glass fill.
const Color kSurfaceDark = Color(0xFF12161D);

/// Opaque card/panel surface used below the fold and on non-photo screens.
const Color kSurfacePanel = Color(0xFF141922);

/// White fill painted over the blur inside glass surfaces.
/// Written as a literal alpha so the value can be `const` at call sites.
const Color kGlassFill = Color(0x1FFFFFFF);

/// Hairline border on every glass surface.
const Color kGlassBorder = Color(0x1FFFFFFF);

/// Blur strength for frosted surfaces.
const double kGlassBlurSigma = 16;

/// Fully rounded corners (pills, circles-as-rects).
const double kRadiusPill = 999;

/// Corner radius for the large full-bleed cards (swipe deck bottom corners).
const double kRadiusCard = 40;

/// Corner radius for the large bottom sheets (explore info card, browse-all).
const double kRadiusSheet = 28;

/// Corner radius for glass panels and cards (info panel, review/detail cards).
const double kRadiusPanel = 20;

/// Corner radius for small image tiles (gallery thumbs, hero strip).
const double kRadiusThumb = 14;

/// Diameter of the primary frosted action circles (like/pass/chat/route…).
const double kActionButtonSize = 58;

/// Diameter of small utility circles (settings, back, more).
const double kUtilityButtonSize = 44;

/// Primary/secondary text on photographic backgrounds.
const Color kTextOnPhoto = Colors.white;
const Color kTextOnPhotoMuted = Color(0x8CFFFFFF);
const Color kTextOnPhotoSecondary = Color(0xE6FFFFFF);

/// Font size for the small uppercase badges (category pills, overlines).
const double kOverlineFontSize = 10;

/// The large overlaid restaurant name, identical on the deck, the Like tab and
/// the detail page so the three screens read as one design.
///
/// These helpers read the Material text theme, which is never null under a
/// [MaterialApp] — `!` rather than a dead fallback style.
TextStyle glassTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.headlineMedium!.copyWith(
        color: kTextOnPhoto,
        fontWeight: FontWeight.w700,
        height: 1.08,
      );
}

/// The muted rating that trails [glassTitleStyle].
TextStyle glassTitleMutedStyle(BuildContext context) {
  return glassTitleStyle(context).copyWith(
    color: kTextOnPhotoMuted,
    fontWeight: FontWeight.w500,
  );
}

/// The location/distance line under a title.
TextStyle glassPlaceStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: kTextOnPhotoSecondary,
        fontWeight: FontWeight.w600,
      );
}

/// Heading of a glass panel or card ("Location", "Top review", …).
TextStyle glassPanelTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium!.copyWith(
        color: kTextOnPhoto,
        fontWeight: FontWeight.w700,
      );
}

/// Small uppercase badge/overline text.
TextStyle glassOverlineStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall!.copyWith(
        color: const Color(0xF2FFFFFF),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontSize: kOverlineFontSize,
      );
}

/// A flat wash over a full-bleed photo. TikTok stills usually carry burnt-in
/// captions; without this, white overlay text lands on white caption text.
class PhotoWash extends StatelessWidget {
  const PhotoWash({super.key, this.opacity = 0.26});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
      ),
    );
  }
}

/// The dark wash under content overlaid on a photo. The ramp stays dark
/// through the whole band where the title, chips and controls sit.
class PhotoBottomScrim extends StatelessWidget {
  const PhotoBottomScrim({super.key, this.height = 620});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.95),
                Colors.black.withValues(alpha: 0.90),
                Colors.black.withValues(alpha: 0.74),
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.42, 0.66, 0.86, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// The matching wash behind the status bar and top controls.
class PhotoTopScrim extends StatelessWidget {
  const PhotoTopScrim({super.key, this.height = 190});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.40),
                Colors.black.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted circular icon button from the reference design.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = kActionButtonSize,
    this.iconSize,
    this.iconColor = kTextOnPhoto,
    this.background,
    this.semanticLabel,
    this.badgeCount,
    this.frosted = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double? iconSize;
  final Color iconColor;
  final Color? background;
  final String? semanticLabel;
  final int? badgeCount;

  /// Set to false to skip the [BackdropFilter] where the blur cannot be seen
  /// (e.g. buttons above another blurred surface) — it costs a render pass.
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background ?? kGlassFill,
      shape: const CircleBorder(side: const BorderSide(color: kGlassBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize ?? size * 0.44,
          ),
        ),
      ),
    );

    if (frosted) {
      button = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        child: button,
      );
    }
    button = ClipOval(child: button);

    final count = badgeCount;
    if (count != null && count > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  borderRadius: BorderRadius.all(Radius.circular(kRadiusPill)),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrapped last so the badge count falls inside the semantics node and is
    // announced along with the label ("Reviews, 3"), not dropped.
    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        button: true,
        child: button,
      );
    }

    return button;
  }
}

/// Frosted pill chip with a leading icon, as on the reference info cards.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.frosted = true,
  });

  final String label;
  final IconData? icon;

  /// Set to false inside an opaque panel, where there is no photo behind the
  /// chip to blur and the [BackdropFilter] is a wasted render pass.
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    Widget body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kGlassFill,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: kTextOnPhoto),
            const SizedBox(width: 6),
          ],
          // Flexible, or the Row hands the label unbounded width and the
          // ellipsis below never engages — a long tag overflows instead.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: kTextOnPhoto,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );

    if (frosted) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: kGlassBlurSigma,
          sigmaY: kGlassBlurSigma,
        ),
        child: body,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: body,
    );
  }
}
