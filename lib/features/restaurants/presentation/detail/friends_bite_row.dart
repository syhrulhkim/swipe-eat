import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';

/// "Aiman, Mei Kee and 4 friends ngap'd this" — the design's `.friends`.
///
/// Built empty on purpose. The social graph is a later phase, so today every
/// call site passes no avatars and no caption and the row renders nothing:
/// the shape is here for the friends work to fill, and until then the screen
/// does not claim anybody has been.
class FriendsBiteRow extends StatelessWidget {
  const FriendsBiteRow({
    super.key,
    this.avatars = const [],
    this.caption,
  });

  /// Portrait URLs, in the order the stack overlaps them.
  final List<String> avatars;

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    if (avatars.isEmpty && (caption == null || caption.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (avatars.isNotEmpty) ...[
          _AvatarStack(avatars: avatars),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (caption != null)
          Expanded(
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeSmall,
                color: kTextOnPhotoSecondary,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// `.avatar{width:32px}` and `.stack .avatar{margin-left:-10px}`. Private to
/// this file rather than tokens: the friends phase owns this vocabulary and
/// will place it properly when it has faces to put in it.
const double _avatarSize = 32;
const double _avatarOverlap = 10;

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});

  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    const step = _avatarSize - _avatarOverlap;

    return SizedBox(
      width: _avatarSize + step * (avatars.length - 1),
      height: _avatarSize,
      // A Stack, not negative margins: Flutter's EdgeInsets cannot be
      // negative, so overlap is expressed as position.
      child: Stack(
        children: [
          for (var i = 0; i < avatars.length; i++)
            Positioned(
              left: step * i,
              child: ClipOval(
                child: SizedBox(
                  width: _avatarSize,
                  height: _avatarSize,
                  child: Image.network(
                    avatars[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(color: kSurfacePanel);
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
