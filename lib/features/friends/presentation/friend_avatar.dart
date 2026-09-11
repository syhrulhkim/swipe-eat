import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../domain/friend_captions.dart';
import '../models/friend.dart';

/// The design's `.avatar` — a round face, or two letters on one of the five
/// pastel grounds when there is no photo.
///
/// The initials are not a fallback that shows while the photo loads; they are
/// what a person without a photo *is*. Most accounts here signed in with a
/// phone number and have no picture at all, so the lettered face is the common
/// case and the photo is the exception.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.profile,
    this.size = kAvatarSize,
    this.borderColor,
    this.borderWidth = kAvatarBorder,
  });

  final FriendProfile profile;
  final double size;

  /// The ring that lifts a face off the one behind it in a stack. Null for a
  /// face standing on its own, which needs no separation from anything.
  final Color? borderColor;
  final double borderWidth;

  double get _fontSize {
    if (size <= kAvatarSizeCompact) {
      return kAvatarInitialsFontSizeCompact;
    }
    if (size >= kAvatarSizeRow) {
      return kAvatarInitialsFontSizeRow;
    }
    return kAvatarInitialsFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final ground = kAvatarGrounds[
        avatarGroundIndex(profile.id, kAvatarGrounds.length)];
    final url = profile.avatarUrl;
    final border = borderColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ground,
        shape: BoxShape.circle,
        border: border == null
            ? null
            : Border.all(color: border, width: borderWidth),
        image: url == null
            ? null
            : DecorationImage(
                image: ResizeImage(
                  NetworkImage(url),
                  width: cachePx(context, size),
                ),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: url != null
          ? null
          : Text(
              avatarInitials(profile.name),
              // The face is a fixed circle, so its letters cannot grow with the
              // text scale without spilling out of it. The name is on the row
              // beside it at full scale; this is decoration that happens to be
              // made of letters.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: _fontSize,
                fontWeight: FontWeight.w700,
                color: kAvatarInk,
                height: 1,
              ),
            ),
    );
  }
}

/// The design's `.stack` — faces overlapping by [kAvatarOverlap], the first one
/// flush left.
///
/// Draws at most [kAvatarStackMax] and says nothing about the rest: the
/// sentence beside it carries the count, so a stack that grew a "+4" bubble
/// would be saying the same thing twice.
class FriendAvatarStack extends StatelessWidget {
  const FriendAvatarStack({
    super.key,
    required this.people,
    this.size = kAvatarSize,
    this.borderWidth = kAvatarBorder,
    this.max = kAvatarStackMax,
  });

  final List<FriendProfile> people;
  final double size;
  final double borderWidth;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }

    final step = size - kAvatarOverlap;

    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      // Excluded rather than labelled: the caption beside every stack in this
      // app already names these people. A screen reader that read three faces
      // and then read their names again would be reading the row twice.
      child: ExcludeSemantics(
        child: Stack(
          children: [
            for (var index = 0; index < shown.length; index++)
              Positioned(
                left: step * index,
                child: FriendAvatar(
                  profile: shown[index],
                  size: size,
                  borderColor: kBackgroundDark,
                  borderWidth: borderWidth,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
