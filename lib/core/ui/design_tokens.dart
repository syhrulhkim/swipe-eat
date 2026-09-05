
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for the app's look. Every screen
// (deck, explore, likes, detail, nav) reads from here so colors, radii, type
// and control sizes stay consistent.
//
// The Ngap look. One rule governs the whole palette:
//
//   Black carries the screen. Orange appears in exactly two roles — a radial
//   glow at the top of every screen, and anything the user can act on or has
//   selected. Nothing sits on flat white; nothing decorative is orange.
//
// Blacks stay *warm* (#0B0605, not #111): a grey black under this much orange
// reads as a rendering fault rather than a choice.
//
// See docs/Redesign/NGAP-DESIGN-SYSTEM.md for the source of every value here.
// ---------------------------------------------------------------------------

/// Action + selected: CTAs, active tab, chosen day/chip, time pills.
const Color kAccentEmber = Color(0xFFFF8A3D);

/// The CTA gradient's far end, and the top-of-screen glow's core.
const Color kAccentLava = Color(0xFFE8541C);

/// Where the top-of-screen glow falls off before the background takes over.
const Color kAccentChar = Color(0xFF5A160C);

/// Ink used on top of [kAccentEmber] and [kAccentCream].
const Color kOnAccent = Color(0xFF140A05);

/// Cream: the app's text colour, and the fill of the one primary action on a
/// screen. Deliberately scarce as a fill — two cream buttons on a screen and
/// neither reads as primary.
const Color kAccentCream = Color(0xFFFFF3E8);

/// Cream at reading weights. Secondary lines and muted metadata.
const Color kCreamSecondary = Color(0xB8FFF3E8);
const Color kCreamMuted = Color(0x73FFF3E8);

/// The "open now" indicator, and nothing else. It is the one non-orange accent
/// in the app, so spending it anywhere else costs it its meaning.
const Color kFresh = Color(0xFF9DF2B8);

/// The "open now" chip's fill and outline: fresh at 16 % and 50 %, as the
/// prototype's `.tags span.open`. Nothing else is tinted fresh.
const Color kFreshFill = Color(0x299DF2B8);
const Color kFreshLine = Color(0x809DF2B8);

/// The fill of a fact chip over video — 14 % white, so the clip shows through.
const Color kFillTag = Color(0x24FFFFFF);

/// The gradient every primary action is filled with.
const LinearGradient kCtaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kAccentEmber, kAccentLava],
);

/// The app's signature: orange lives as a glow at the top of every screen, then
/// the screen goes black. Painted behind content, never over it.
///
/// The CSS is `radial-gradient(130% 48% at 50% -6%, lava, char 42%, transparent
/// 72%)`; [RadialGradient] takes a centre in fractional coordinates and one
/// radius, so the ellipse is reproduced by drawing it into a box 130% wide and
/// 96% as tall as it is wide — see [ScreenGlow].
const RadialGradient kScreenGlow = RadialGradient(
  center: Alignment.topCenter,
  radius: 0.5,
  colors: [kAccentLava, kAccentChar, Color(0x005A160C)],
  stops: [0.0, 0.42, 0.72],
);

/// Tints for the three taste preferences. They have to be distinguishable from
/// each other and from [kAccentEmber], which rules out a third orange, so the
/// set runs warm-to-cool inside the same muted family.
const Color kTintMorning = Color(0xFFF6C664);
const Color kTintSpice = Color(0xFFE8613C);
const Color kTintNearby = Color(0xFF9ED8A6);

/// The screen. Warm black, never grey.
const Color kBackgroundDark = Color(0xFF0B0605);

/// Deepest background, used behind the explore map.
const Color kBackgroundDeep = Color(0xFF050302);

/// Base surface: cards, panels, the bottom nav.
const Color kSurfaceDark = Color(0xFF171010);

/// Raised surface: elements sitting on top of a card, list rows, anything that
/// must separate from [kSurfaceDark] without a border.
const Color kSurfacePanel = Color(0xFF221614);

/// Glass fills, for panels laid over photography where an opaque surface would
/// punch a hole in the image.
const Color kGlass = Color(0x12FFFFFF);
const Color kGlassStrong = Color(0x1FFFFFFF);

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
const Color kHairline = Color(0x24FFFFFF);

// Every rounded shape in the app resolves through one of the five radii below
// — nothing hard-codes a corner — so the whole look is one edit away in either
// direction. Set all five to 0 to get the square-cornered app back.

/// Chips, the nav indicator, round buttons. A true pill: the shapes it is
/// applied to clamp it to half their shortest side.
const double kRadiusPill = 999;

/// The large full-bleed cards (swipe deck).
const double kRadiusCard = 28;

/// The large bottom sheets (explore info card, browse-all).
const double kRadiusSheet = 28;

/// Panels, tiles and cards (info panel, review/detail cards, grid tiles).
const double kRadiusPanel = 18;

/// Small image tiles (gallery thumbs, hero strip).
const double kRadiusThumb = 10;

/// The bite notch on a full-size card. Tiles pass something smaller; the notch
/// is a proportion of the surface it marks, not a fixed dot.
const double kBiteNotchRadius = 30;

/// How far the notch's centre sits inside the corner. Shared by every size, so
/// a large bite and a small one are the same shape rather than two shapes.
const double kBiteNotchInset = 6;


/// One duration and one curve for interface motion, so transitions across the
/// app agree. Gestural motion that carries its own physics — the card exit —
/// keeps its longer timing; everything else uses these.
const Duration kMotionDuration = Duration(milliseconds: 220);
const Cubic kMotionEase = Cubic(0.2, 0.8, 0.2, 1);

/// The one shadow in the app: a single deep, warm card shadow. There is no
/// second elevation — surfaces separate by colour, not by stacking shadows.
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x8C3C0C04),
    blurRadius: 48,
    offset: Offset(0, 24),
    spreadRadius: -16,
  ),
];

/// Side of the primary action buttons (like/pass/chat/route…). Square, so it
/// is both the width and the height.
const double kActionButtonSize = 56;

/// The Ngap button: the deck's one primary action, and the largest control in
/// the app. Bigger than the two ghosts flanking it because it is the gesture
/// the product is named after, and the size is the only thing that says so
/// before the word is read.
const double kNgapButtonSize = 72;

/// Side of the small utility buttons (settings, back, more).
const double kUtilityButtonSize = 44;

/// Primary/secondary text on photographic backgrounds. Cream rather than pure
/// white, so overlaid text belongs to the same palette as the rest of the app.
const Color kTextOnPhoto = kAccentCream;
const Color kTextOnPhotoMuted = kCreamMuted;
const Color kTextOnPhotoSecondary = kCreamSecondary;

/// Font size for the small badges (category chips, state labels).
const double kOverlineFontSize = 11;

/// Anything the user reads first: headings, restaurant names, hero copy.
///
/// The design runs two faces, which is why these two names exist — call sites
/// ask "display or text?", which is a role, not a family.
const String kDisplayFontFamily = 'BricolageGrotesque';

/// Everything else: body copy, labels, chips, metadata.
const String kTextFontFamily = 'InstrumentSans';

/// The type scale. Left-aligned everywhere; no all-caps labels, no monospace
/// for data.
const double kFontSizeHero = 44;
const double kFontSizeH1 = 30;
const double kFontSizeH2 = 20;
const double kFontSizeBody = 15;
const double kFontSizeSmall = 13;
const double kFontSizeMicro = 11;

/// The large overlaid restaurant name, identical on the deck, the Like tab and
/// the detail page so the three screens read as one design.
///
/// These helpers read the Material text theme, which is never null under a
/// [MaterialApp] — `!` rather than a dead fallback style.
TextStyle appTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.headlineMedium!.copyWith(
        fontFamily: kDisplayFontFamily,
        color: kTextOnPhoto,
        // Bricolage is a display grotesk: it wants weight and tight tracking at
        // headline sizes, where the previous face wanted neither.
        fontWeight: FontWeight.w800,
        height: 1.02,
        letterSpacing: -0.5,
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

/// Small badge/label text. Warm by default: it is the line that labels what a
/// card is ("Crispy", "Open now") and reads as an accent, not as body copy.
///
/// Sentence case with no tracking — the design forbids all-caps labels, and
/// letter-spacing exists to make caps readable, so it goes with them.
TextStyle appEyebrowStyle(BuildContext context, {Color color = kAccentEmber}) {
  return Theme.of(context).textTheme.labelSmall!.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        fontSize: kOverlineFontSize,
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

/// The app's signature: a radial ember glow at the top of the screen, falling
/// off to the background before the first third of the page.
///
/// Sits *behind* content — it is the one place orange appears without being
/// tappable, and the exception is only granted because it never touches a
/// control. Put it at the bottom of a [Stack], above the scaffold colour.
///
/// The design's ellipse is 130% of the screen wide and 48% tall, centred on the
/// top edge and lifted 6%. Flutter's [RadialGradient] is circular, so the shape
/// is produced by painting into a box of that aspect and letting it overflow
/// the sides rather than by distorting the gradient.
class ScreenGlow extends StatelessWidget {
  const ScreenGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 1.3;

    return Positioned(
      // Centres the over-wide ellipse: the overhang is split between sides.
      left: -(width - MediaQuery.sizeOf(context).width) / 2,
      width: width,
      // The -6% lift, expressed against the ellipse's own height.
      top: -width * 0.96 * 0.06,
      height: width * 0.96,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: kScreenGlow,
          ),
        ),
      ),
    );
  }
}

/// The bite: a circular notch out of the top-right corner of a restaurant
/// surface the user has saved.
///
/// The app's **only** decorative device, and it means exactly one thing. It
/// replaces the heart, star and badge vocabulary that marked a saved place
/// before — a mark that is part of the card's silhouette cannot be mistaken
/// for a button, which every previous marker could.
///
/// The notch is cut, not drawn: whatever sits behind the surface shows
/// through it. That is what makes it read as a bite rather than as a circle
/// someone put in the corner.
class BiteNotch extends StatelessWidget {
  const BiteNotch({
    super.key,
    required this.child,
    required this.borderRadius,
    this.radius = kBiteNotchRadius,
    this.bitten = true,
  });

  final Widget child;

  /// The corners of the surface being bitten, so the notch composes with a
  /// card, a tile or a sheet without any of them hard-coding the other's
  /// shape.
  final BorderRadius borderRadius;

  /// Scales with the surface: [kBiteNotchRadius] on a card, less on a tile.
  final double radius;

  /// False leaves the surface whole, so a caller can hand the same widget an
  /// unsaved restaurant without branching around it.
  final bool bitten;

  @override
  Widget build(BuildContext context) {
    if (!bitten) {
      return ClipRRect(borderRadius: borderRadius, child: child);
    }

    return ClipPath(
      clipper: _BiteClipper(borderRadius: borderRadius, radius: radius),
      child: child,
    );
  }
}

class _BiteClipper extends CustomClipper<Path> {
  const _BiteClipper({required this.borderRadius, required this.radius});

  final BorderRadius borderRadius;
  final double radius;

  @override
  Path getClip(Size size) {
    final surface = Path()
      ..addRRect(borderRadius.toRRect(Offset.zero & size));
    // Centred just inside the corner rather than on it, so the notch takes a
    // bite out of two edges instead of shaving one.
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width - kBiteNotchInset, kBiteNotchInset),
          radius: radius,
        ),
      );

    return Path.combine(PathOperation.difference, surface, bite);
  }

  @override
  bool shouldReclip(_BiteClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius || oldClipper.radius != radius;
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

/// The wash that keeps a caption legible over a photo *tile*.
///
/// Sized to the tile rather than in pixels, which is the difference from
/// [PhotoBottomScrim]: that one is hundreds of pixels tall for a full-bleed
/// photo screen, so on a tile a couple of hundred pixels high only the
/// near-opaque end of its gradient is ever visible and the whole card goes
/// black. This keeps its ramp in the bottom half of whatever it is given.
class PhotoTileScrim extends StatelessWidget {
  const PhotoTileScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.28, 0.58],
            ),
          ),
        ),
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

/// Square icon button — the like/pass/route controls and every small utility
/// button (back, settings, more).
///
/// Shaped by [kRadiusPill] rather than by a [CircleBorder], so it follows the
/// app's corner radius: square today, and a true circle again the moment that
/// token goes back to its pill value, because the box is always a square.
/// The deck's right-swipe action: a gradient circle carrying the **word**.
///
/// Not an icon. The design forbids a bare heart here — "Ngap" is the product's
/// name for the action, and a button that says it teaches the word to a new
/// user in a way no glyph can. It is the app's only circular gradient fill and
/// the only control that is larger than a touch target needs to be, both for
/// the same reason: on this screen it is the only thing worth doing.
class AppNgapButton extends StatelessWidget {
  const AppNgapButton({super.key, required this.onTap, this.enabled = true});

  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onTap != null;

    return Semantics(
      label: 'Ngap',
      button: true,
      enabled: live,
      // The Text inside says "Ngap!" and would merge into this node, so the
      // child's semantics are excluded to keep the announced name exactly
      // one thing. Excluding them drops the InkWell's tap action too, so the
      // action is re-declared here — see D83.
      excludeSemantics: true,
      onTap: live ? onTap : null,
      child: Opacity(
        opacity: live ? 1 : 0.45,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: kCtaGradient,
            boxShadow: kCardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: live
                  ? () {
                      HapticFeedback.mediumImpact();
                      onTap!();
                    }
                  : null,
              child: SizedBox(
                width: kNgapButtonSize,
                height: kNgapButtonSize,
                child: Center(
                  child: Text(
                    'Ngap!',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontFamily: kDisplayFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.15,
                          color: kOnAccent,
                        ),
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

class AppIconButton extends StatelessWidget {
  const AppIconButton({
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadiusPill),
    );

    final button = Material(
      color: background ?? (onPhoto ? kFillOnPhoto : kSurfacePanel),
      shape: shape.copyWith(side: const BorderSide(color: kHairline)),
      child: InkWell(
        customBorder: shape,
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

    Widget result = ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: button,
    );

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

/// Chip with a leading icon: tags, ratings, the location marker.
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

  /// Whether the chip sits on a photo or video. See [AppIconButton.onPhoto].
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

/// A fact chip over a clip: the cuisine, "Halal", or — tinted fresh, with the
/// dot — whether the place is open right now. The prototype's
/// `.card .info .tags span`, 11 px and pill-shaped, smaller than [AppChip].
class AppTagChip extends StatelessWidget {
  const AppTagChip({super.key, required this.label}) : fresh = false;

  /// The one fresh-tinted chip in the app: open now.
  const AppTagChip.fresh({super.key, required this.label}) : fresh = true;

  final String label;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fresh ? kFreshFill : kFillTag,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: fresh ? kFreshLine : kHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fresh) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: kFresh,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeMicro,
              fontWeight: FontWeight.w600,
              color: kTextOnPhoto,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diet & budget controls (first-run step 01e, Settings) and the You tab (S10).
//
// The prototype draws these three controls at fixed sizes, and all three now
// appear on two screens each, so the numbers live here rather than in either
// call site: a switch on Settings that is two pixels off the one in the wizard
// reads as a second control, not the same one.
// ---------------------------------------------------------------------------

/// The `.switch` track and its cream thumb. The thumb sits 4 px inside the
/// track, so its travel is width - height.
const double kSwitchWidth = 50;
const double kSwitchHeight = 30;
const double kSwitchThumbSize = 22;

/// The `.seg` pill: a [kSurfacePanel] track with [kSegmentTrackPadding] around
/// buttons [kSegmentHeight] tall.
const double kSegmentHeight = 36;
const double kSegmentTrackPadding = 4;

/// The `.steps` bar in the first-run topbar: hairline segments, one per step.
const double kStepBarHeight = 3;
const double kStepBarGap = 5;

/// The You tab's portrait, ringed in ember — the one round ember border in the
/// app, and the reason the row reads as "you" rather than as a list item.
const double kProfileAvatarSize = 64;

/// The three numbers on the You tab's stat tiles, the name beside the
/// portrait, and the live read-out over a range control.
const double kFontSizeStatValue = 28;
const double kFontSizeProfileName = 24;
const double kFontSizeRangeOutput = 16;

/// A single spice pip on the You tab's taste list.
const double kSpicePipSize = 8;
