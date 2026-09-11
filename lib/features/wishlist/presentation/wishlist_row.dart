import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/design_tokens.dart';
import '../models/wishlist_item.dart';

/// One line of the wishlist — the design's `.wl`.
///
/// The whole row is the control. There is no separate checkbox to hit and no
/// menu behind a long press: a checklist you cross off by tapping the line is
/// the entire interaction, and adding a second target would only give the user
/// a way to miss.
class WishlistRow extends StatelessWidget {
  const WishlistRow({
    super.key,
    required this.item,
    required this.onTap,
    this.plannedLabel,
  });

  final WishlistItem item;
  final VoidCallback onTap;

  /// "Fri 4" — the day this place is booked for, shown above the date on the
  /// right. Always null today; the plans phase fills it in.
  final String? plannedLabel;

  @override
  Widget build(BuildContext context) {
    final eaten = item.isEaten;

    return Semantics(
      label: item.title,
      button: true,
      // What a screen reader needs from this row is whether it is crossed off,
      // which is exactly what `toggled` says.
      toggled: eaten,
      // The Texts below would each become their own node and the row would be
      // read as four fragments; excluding them keeps it one. Excluding drops
      // the InkWell's tap action, so it is re-declared here (D83).
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusThumb),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                _CheckCircle(eaten: eaten),
                const SizedBox(width: 8),
                _Thumb(url: item.coverUrl, eaten: eaten),
                const SizedBox(width: 8),
                Expanded(child: _Titles(item: item, eaten: eaten)),
                const SizedBox(width: 8),
                _Provenance(item: item, plannedLabel: plannedLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 26 px tick. Empty outline while the place is still to go; ember with a
/// tick once it has been eaten.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.eaten});

  final bool eaten;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMotionDuration,
      curve: kMotionEase,
      width: kCheckCircleSize,
      height: kCheckCircleSize,
      decoration: BoxDecoration(
        color: eaten ? kAccentEmber : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: eaten ? kAccentEmber : kHairline,
          width: 1.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: kMotionDuration,
        curve: kMotionEase,
        opacity: eaten ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 14, color: kOnAccent),
      ),
    );
  }
}

/// The row's photo. Grey and half-faded once eaten — the same "this is done"
/// the strike-through says, in the one place on the row that is not type.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.eaten});

  final String? url;
  final bool eaten;

  @override
  Widget build(BuildContext context) {
    final photo = url;

    Widget image = photo == null || photo.isEmpty
        // A row with no restaurant behind it (a typed-in place) gets a plain
        // panel rather than a stand-in photo of somewhere else.
        ? const ColoredBox(color: kSurfacePanel)
        : Image.network(
            photo,
            cacheWidth: cachePx(context, kWishThumbSize),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: kSurfacePanel),
          );

    if (eaten) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: image,
      );
    }

    return AnimatedOpacity(
      duration: kMotionDuration,
      curve: kMotionEase,
      opacity: eaten ? 0.5 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusWishThumb),
        child: SizedBox(
          width: kWishThumbSize,
          height: kWishThumbSize,
          child: image,
        ),
      ),
    );
  }
}

/// The name and the line under it, with the strike-through that draws itself
/// across the name when the place is crossed off.
class _Titles extends StatelessWidget {
  const _Titles({required this.item, required this.eaten});

  final WishlistItem item;
  final bool eaten;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StrikeThrough(
          struck: eaten,
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appRowTitleStyle(context).copyWith(
              color: eaten ? kCreamMuted : kTextOnPhoto,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              color: eaten ? kCreamMuted : kCreamSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// The ember rule that sweeps across a title as it is crossed off.
///
/// Drawn as a scaling bar rather than [TextDecoration.lineThrough] for one
/// reason: a text decoration is either there or not, and this has to *travel*
/// — left to right, in 260 ms, so the eye reads the crossing-off as something
/// the tap did rather than as a state the row was always in.
class _StrikeThrough extends StatelessWidget {
  const _StrikeThrough({required this.struck, required this.child});

  final bool struck;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              // Left-anchored, so the bar grows out from the start of the
              // name rather than opening from its middle.
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 2,
                child: AnimatedFractionallySizedBox(
                  duration: kStrikeDuration,
                  curve: kMotionEase,
                  alignment: Alignment.centerLeft,
                  widthFactor: struck ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kAccentEmber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The right-hand column: where the row came from, and the date under it.
///
/// Fixed width, as the design's `flex:0 0 58px` — the titles beside it are
/// what should reflow when a name is long, not this.
class _Provenance extends StatelessWidget {
  const _Provenance({required this.item, this.plannedLabel});

  final WishlistItem item;
  final String? plannedLabel;

  /// "24 Aug". Hand-rolled rather than pulled through `intl`: one format, in
  /// one place, is not worth a localisation package.
  static String formatDay(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final planned = plannedLabel;
    final eatenAt = item.eatenAt;

    // Precedence is chronological: a place that has been eaten is done, so
    // that wins over a date now in the past. Otherwise a plan wins over where
    // the row came from, because a date is the more useful thing to see.
    final String label;
    String? detail;

    if (eatenAt != null) {
      label = 'Eaten';
      detail = formatDay(eatenAt);
    } else if (planned != null) {
      label = 'Planned';
      detail = planned;
    } else {
      final sender = item.fromUserName;
      label = switch (item.source) {
        // The name is filled in from the friends cache when the sender is
        // still a friend. When they are not, the row says only what it
        // honestly knows.
        WishlistSource.friend =>
          sender == null ? 'From a friend' : 'From $sender',
        WishlistSource.swiped => 'Swiped',
        WishlistSource.manual => 'Added',
      };
    }

    return SizedBox(
      // `.wl .from { flex: 0 0 58px }`.
      width: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeMicro,
              color: kCreamMuted,
              height: 1.25,
            ),
          ),
          if (detail != null)
            Text(
              detail,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeMicro,
                color: kCreamSecondary,
                height: 1.25,
              ),
            ),
        ],
      ),
    );
  }
}
