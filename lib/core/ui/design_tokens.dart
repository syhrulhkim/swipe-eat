
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for the app's look. Every screen
// (deck, explore, likes, detail, nav) reads from here so colors, radii, type
// and control sizes stay consistent.
//
// The look is a near-black canvas with flat, opaque surfaces, one warm ember
// accent for anything live or selected, and a cream fill reserved for the
// single primary action on a screen. Surfaces used to be frosted glass; the
// blur is gone, because flat dark panels read better behind video and cost no
// render passes.
// ---------------------------------------------------------------------------

/// Warm accent: active tabs, selected states, live indicators, eyebrow labels.
const Color kAccentEmber = Color(0xFFFF7A33);

/// Ink used on top of [kAccentEmber] and [kAccentCream].
const Color kOnAccent = Color(0xFF0B0B0B);

/// Cream fill, reserved for the one primary action on a screen (Cook, Continue,
/// Get directions). Deliberately scarce: two cream buttons on a screen and
/// neither reads as primary.
const Color kAccentCream = Color(0xFFF3E3C3);

/// Tints for the three taste preferences. They have to be distinguishable from
/// each other and from [kAccentEmber], which rules out a third orange, so the
/// set runs warm-to-cool inside the same muted family.
const Color kTintMorning = Color(0xFFF6C664);
const Color kTintSpice = Color(0xFFE8613C);
const Color kTintNearby = Color(0xFF9ED8A6);

/// App background behind full-bleed content (deck, likes, detail below-fold).
const Color kBackgroundDark = Color(0xFF0B0B0B);

/// Deepest background, used behind the explore map.
const Color kBackgroundDeep = Color(0xFF050505);

/// Base surface: cards sitting directly on the background.
const Color kSurfaceDark = Color(0xFF141414);

/// Raised surface: panels, list rows, anything that must separate from
/// [kSurfaceDark] without a border. Matches the Figma's panel grey.
const Color kSurfacePanel = Color(0xFF1E1E1E);

/// Stands in for a restaurant's own brand colour when the row has none or the
/// stored value is unreadable. Matches [kSurfacePanel] so an unbranded card is
/// simply a neutral card rather than an obviously wrong one.
const Color kBrandColorFallback = kSurfacePanel;

/// Fill for controls that sit on top of a photo or video, where an opaque
/// surface would punch a hole in the image.
/// Written as a literal alpha so the value can be `const` at call sites.
const Color kFillOnPhoto = Color(0x59000000);

/// Hairline border. Barely visible by design — it separates two dark surfaces
/// rather than drawing a frame.
const Color kHairline = Color(0x14FFFFFF);

/// Fully rounded corners (pills, circles-as-rects).
const double kRadiusPill = 999;

/// Corner radius for the large full-bleed cards (swipe deck bottom corners).
const double kRadiusCard = 32;

/// Corner radius for the large bottom sheets (explore info card, browse-all).
const double kRadiusSheet = 28;

/// Corner radius for panels and cards (info panel, review/detail cards).
const double kRadiusPanel = 18;

/// Corner radius for small image tiles (gallery thumbs, hero strip).
const double kRadiusThumb = 12;

/// Diameter of the primary action circles (like/pass/chat/route…).
const double kActionButtonSize = 58;

/// Diameter of small utility circles (settings, back, more).
const double kUtilityButtonSize = 44;

/// Primary/secondary text on photographic backgrounds.
const Color kTextOnPhoto = Colors.white;
const Color kTextOnPhotoMuted = Color(0x8CFFFFFF);
const Color kTextOnPhotoSecondary = Color(0xE6FFFFFF);

/// Font size for the small uppercase badges (category pills, eyebrows).
const double kOverlineFontSize = 10;

/// The one family the design uses, headlines and body alike. The Figma sets
/// everything in Lexend and differentiates by size and weight only, so the
/// display/text split collapses to a single face.
///
/// Two names are kept because call sites ask "display or text?", which is a
/// role, not a family — if a second face ever returns, only these two lines
/// change.
const String kDisplayFontFamily = 'Lexend';

/// See [kDisplayFontFamily]: same family, different role.
const String kTextFontFamily = 'Lexend';

/// The large overlaid restaurant name, identical on the deck, the Like tab and
/// the detail page so the three screens read as one design.
///
/// These helpers read the Material text theme, which is never null under a
/// [MaterialApp] — `!` rather than a dead fallback style.
TextStyle appTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.headlineMedium!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: kTextOnPhoto,
        fontWeight: FontWeight.w600,
        // The Figma sets Lexend at 105% line height and no tracking; the
        // negative tracking the old grotesk needed would cramp it.
        height: 1.05,
        letterSpacing: 0,
      );
}

/// The muted rating that trails [appTitleStyle].
TextStyle appTitleMutedStyle(BuildContext context) {
  return appTitleStyle(context).copyWith(
    color: kTextOnPhotoMuted,
    fontWeight: FontWeight.w500,
  );
}

/// The location/distance line under a title.
TextStyle appPlaceStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: kTextOnPhotoSecondary,
        fontWeight: FontWeight.w600,
      );
}

/// Heading of a panel or card ("Location", "Top review", …).
TextStyle appPanelTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: kTextOnPhoto,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      );
}

/// Small uppercase badge/eyebrow text. Warm by default: it is the line that
/// labels what a card is ("CRISPY", "OPEN NOW") and reads as an accent, not as
/// body copy.
TextStyle appEyebrowStyle(BuildContext context, {Color color = kAccentEmber}) {
  return Theme.of(context).textTheme.labelSmall!.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        fontSize: kOverlineFontSize,
      );
}

/// The oversized statement line at the top of a screen that is mostly about
/// one subject — currently the Profile masthead. A step above [appTitleStyle],
/// same face and the same zero tracking, so it reads as the loudest size in
/// one type scale rather than as a second design.
TextStyle appDisplayStyle(BuildContext context) {
  return Theme.of(context).textTheme.displaySmall!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: kTextOnPhoto,
        fontWeight: FontWeight.w600,
        // Tighter than [appTitleStyle]: at display size the default leading
        // opens a visible gap between two lines of one name.
        height: 0.98,
        letterSpacing: 0,
      );
}

/// A large standalone number over a small label — the counts in a stat band.
/// The number carries the emphasis, so the label under it stays muted.
TextStyle appNumeralStyle(BuildContext context, {Color color = kTextOnPhoto}) {
  return Theme.of(context).textTheme.headlineLarge!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: color,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: 0,
      );
}

/// A section title above a list ("Nearby", "Your likes"). Display face at a
/// size where the text face would look plain.
TextStyle appSectionTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: kTextOnPhoto,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
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

/// Circular icon button — the like/pass/route controls and every small
/// utility circle (back, settings, more).
class AppCircleButton extends StatelessWidget {
  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = kActionButtonSize,
    this.iconSize,
    this.iconColor = kTextOnPhoto,
    this.background,
    this.semanticLabel,
    this.badgeCount,
    this.onPhoto = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double? iconSize;
  final Color iconColor;
  final Color? background;
  final String? semanticLabel;
  final int? badgeCount;

  /// Whether the button sits directly on a photo or video. On a photo it uses
  /// the translucent [kFillOnPhoto] so the image reads through it; set false
  /// inside an opaque panel, where a translucent fill would show the panel
  /// rather than the image and look like a smudge.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background ?? (onPhoto ? kFillOnPhoto : kSurfacePanel),
      shape: const CircleBorder(side: BorderSide(color: kHairline)),
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

    Widget result = ClipOval(child: button);

    final count = badgeCount;
    if (count != null && count > 0) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          result,
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
        child: result,
      );
    }

    return result;
  }
}

/// Pill chip with a leading icon: tags, ratings, the location marker.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.onPhoto = true,
    this.tint,
  });

  final String label;
  final IconData? icon;

  /// Whether the chip sits on a photo or video. See [AppCircleButton.onPhoto].
  final bool onPhoto;

  /// Colours the icon and label. Null leaves both white, which is the default
  /// for descriptive chips; pass [kAccentEmber] for a chip that reports state
  /// (offline, open now, live).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final foreground = tint ?? kTextOnPhoto;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onPhoto ? kFillOnPhoto : kSurfacePanel,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
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
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
