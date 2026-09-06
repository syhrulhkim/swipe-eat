import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../models/friend.dart';
import 'friend_avatar.dart';

/// The design's `.person` — a face, a name, a line about them, and a tick.
///
/// The whole row is the control, the same way a wishlist row is: a list you
/// pick from by tapping the line needs no second target, and adding one only
/// gives the user somewhere to miss.
///
/// Used by both screens that show people in a list — the onboarding friends
/// step and the invite screen — because they are the same row with a different
/// subtitle, and two copies would drift.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final FriendProfile profile;
  final bool selected;
  final VoidCallback onTap;

  /// "142 bites · Bangsar", "Ngap'd Kak Ros too". Null when there is nothing
  /// true to say — the design fills this from data no catalogue has yet, so
  /// most rows in the running app draw the name alone rather than a made-up
  /// fact.
  final String? subtitle;

  /// Replaces the tick, for a row that is not a choice — the friends page's
  /// Accept and Decline sit here.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = _content();

    // A row that carries its own buttons — Accept and Decline on the friends
    // page — is not itself a control, and neither the `Semantics` wrapper nor
    // the `InkWell` belongs on it. Both merge the subtree beneath them into a
    // single semantics node, which fuses the name, the subtitle and both
    // buttons into one unpressable sentence: a screen reader is told
    // "AI Aiman Wants to be friends Accept Aiman" and given nothing to press.
    // (The `InkWell` does this even with a null `onTap`, which is what made it
    // worth finding out.) Left bare, the texts read as texts and each button
    // keeps its own node.
    if (trailing != null) {
      return content;
    }

    return Semantics(
      label: profile.name,
      value: subtitle,
      button: true,
      // What a screen reader needs from a row in a multi-select is whether it
      // is picked, which is exactly what `selected` says.
      selected: selected,
      // The Texts below would each become their own fragment; excluding them
      // keeps the row one sentence. Excluding drops the InkWell's tap action,
      // so it is re-declared here (D83).
      excludeSemantics: true,
      onTap: onTap,
      child: content,
    );
  }

  Widget _content() {
    final body = _body();
    if (trailing != null) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusThumb),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: body,
      ),
    );
  }

  Widget _body() {
    final line = subtitle;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          FriendAvatar(profile: profile, size: kAvatarSizeRow),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: kAccentCream,
                  ),
                ),
                if (line != null && line.isNotEmpty)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeSmall,
                      color: kCreamSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? _Check(selected: selected),
        ],
      ),
    );
  }
}

/// `.person .check` — a hairline ring that fills with ember and shows a tick
/// once the row is picked.
class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMotionDuration,
      curve: kMotionEase,
      width: kPersonCheckSize,
      height: kPersonCheckSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? kAccentEmber : Colors.transparent,
        border: Border.all(
          color: selected ? kAccentEmber : kHairline,
          width: 1.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: kMotionDuration,
        curve: kMotionEase,
        opacity: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 14, color: kOnAccent),
      ),
    );
  }
}
