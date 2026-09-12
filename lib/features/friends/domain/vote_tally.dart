/// Counting time votes onto the design's five chips (D133).
///
/// Pure, and separate from the screen, because every one of these is an
/// off-by-one waiting to happen: a tie at the top, a vote for an hour that is
/// not one of the five, "1 votes".
library;

import '../../plans/models/plan_slot.dart';
import '../models/friend.dart';

/// The key a vote for [slot] would carry, in [PlanVote.slotKey]'s vocabulary.
///
/// The two formats have to agree exactly — a chip that keyed itself
/// differently would show zero votes forever, which looks like nobody voting
/// rather than like a bug. There is a test that compares the two directly,
/// which is the only thing keeping them honest.
String slotVoteKey(PlanSlot slot) {
  final hour = slot.hour;
  if (hour == null) {
    return 'label:${slot.wireLabel ?? 'none'}';
  }
  return 'time:$hour:${slot.minute ?? 0}';
}

/// How many votes each of [PlanSlot.all] has, in that order.
///
/// A vote for a time that is not one of the five is counted by nobody. That
/// only happens to a plan whose time was written by something other than this
/// app, and dropping it is better than inventing a sixth chip for it.
List<int> slotVoteCounts(Iterable<PlanVote> votes) {
  final tally = <String, int>{};
  for (final vote in votes) {
    tally[vote.slotKey] = (tally[vote.slotKey] ?? 0) + 1;
  }
  return [for (final slot in PlanSlot.all) tally[slotVoteKey(slot)] ?? 0];
}

/// The slot the most people picked, or null when nobody has voted **or** two
/// slots are level at the top.
///
/// Null on a tie rather than the earlier one: the line this feeds says "most
/// votes", and a tie has no most. Breaking it by position would put a thumb on
/// 12:30 for no reason anybody could see.
PlanSlot? leadingSlot(Iterable<PlanVote> votes) {
  final counts = slotVoteCounts(votes);
  var best = 0;
  var bestIndex = -1;
  var tied = false;
  for (var index = 0; index < counts.length; index++) {
    final count = counts[index];
    if (count == 0) {
      continue;
    }
    if (count > best) {
      best = count;
      bestIndex = index;
      tied = false;
    } else if (count == best) {
      tied = true;
    }
  }
  if (bestIndex == -1 || tied) {
    return null;
  }
  return PlanSlot.all[bestIndex];
}

/// The chip one person's own vote sits on, or null when they have not voted.
///
/// Null for a null id too: a page that does not know who it is looking at
/// shows nobody's vote as chosen, which is truer than showing somebody
/// else's.
PlanSlot? voteSlotOf(Iterable<PlanVote> votes, String? userId) {
  if (userId == null) {
    return null;
  }
  for (final vote in votes) {
    if (vote.profile.id != userId) {
      continue;
    }
    for (final slot in PlanSlot.all) {
      if (slotVoteKey(slot) == vote.slotKey) {
        return slot;
      }
    }
    return null;
  }
  return null;
}

/// What a chip says: "20:00" until somebody votes, then "20:00 · 2".
///
/// The count is only drawn once there is one. A row of five chips each
/// carrying "· 0" reads as a screen full of failures rather than a question
/// nobody has answered yet.
String slotChipLabel(PlanSlot slot, int votes) =>
    votes <= 0 ? slot.label : '${slot.label} · $votes';

/// What a screen reader hears instead. "20:00 · 2" is read as a date by some
/// of them, and the plural has to be right either way.
String slotChipSemanticLabel(PlanSlot slot, int votes) {
  if (votes <= 0) {
    return '${slot.label}, no votes yet';
  }
  return '${slot.label}, $votes ${votes == 1 ? 'vote' : 'votes'}';
}

/// The line under a guest's name on a plan: what they said, in words.
String planStatusLabel(String status) {
  return switch (status) {
    'going' => 'Going',
    'declined' => "Can't",
    'requested' => 'Asked to join',
    _ => 'Asked',
  };
}

/// "2 people still to vote", or null when everybody has.
///
/// [voted] counts the votes cast and [asked] everybody the question was put
/// to, the owner included. Null when nothing is outstanding, so the line
/// disappears rather than saying "0 to go" — and null when the numbers
/// disagree the other way, which a declined guest who voted first can cause.
String? votesOutstandingLine({required int voted, required int asked}) {
  final waiting = asked - voted;
  if (waiting <= 0) {
    return null;
  }
  return '$waiting ${waiting == 1 ? 'person' : 'people'} still to vote';
}
