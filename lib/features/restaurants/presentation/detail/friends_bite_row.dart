import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';
import '../../../friends/domain/friend_captions.dart';
import '../../../friends/models/friend.dart';
import '../../../friends/presentation/friend_avatar.dart';

/// "Aiman, Mei Kee and 4 friends ngap'd this" — the design's `.friends`.
///
/// Draws nothing when nobody you know has been. That is the common case and it
/// must stay silent: a row saying "0 friends" on a place none of your friends
/// have heard of would be worse than no row.
///
/// The sentence is built here from the names rather than passed in, so no call
/// site can put a different sentence on the same faces. [friendsBiteCaption]
/// owns the commas and the plurals.
class FriendsBiteRow extends StatelessWidget {
  const FriendsBiteRow({super.key, this.people = const []});

  /// The friends who liked this place, in the order the server returned them.
  /// The stack draws the first [kAvatarStackMax]; the sentence counts them all.
  final List<FriendProfile> people;

  @override
  Widget build(BuildContext context) {
    final caption = friendsBiteCaption([
      for (final person in people) person.name,
    ]);
    if (caption == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        FriendAvatarStack(people: people, size: kAvatarSize),
        const SizedBox(width: AppSpacing.sm),
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
