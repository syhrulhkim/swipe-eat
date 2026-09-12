import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/domain/vote_tally.dart';
import 'package:swipe_eat/features/friends/models/friend.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';

import 'fake_friends_repository.dart';

/// A vote the way the server sends one, so the round-trip below is a real
/// round-trip rather than two constructors agreeing with each other.
PlanVote voteFor(PlanSlot slot, {String id = 'a'}) {
  return PlanVote.fromJson({
    'id': id,
    'name': 'Friend $id',
    'plan_time': slot.wireTime,
    'time_label': slot.wireLabel,
  });
}

void main() {
  group('the key the chips and the votes must agree on', () {
    test('every slot survives the wire and comes back to its own chip', () {
      for (final slot in PlanSlot.all) {
        expect(
          voteFor(slot).slotKey,
          slotVoteKey(slot),
          reason: '${slot.label} keys itself differently after a round trip',
        );
      }
    });

    test('"Late" does not collide with a real midnight', () {
      expect(slotVoteKey(PlanSlot.supper), isNot(slotVoteKey(PlanSlot.noon)));
      final midnight = PlanVote.fromJson({
        'id': 'a',
        'plan_time': '00:00:00',
      });
      expect(midnight.slotKey, isNot(slotVoteKey(PlanSlot.supper)));
    });
  });

  group('counting', () {
    test('counts land on the right chip, in the design\'s order', () {
      final counts = slotVoteCounts([
        voteFor(PlanSlot.dinner, id: 'a'),
        voteFor(PlanSlot.dinner, id: 'b'),
        voteFor(PlanSlot.supper, id: 'c'),
      ]);

      expect(counts, [0, 0, 2, 0, 1]);
    });

    test('a vote for an hour that is not one of the five is counted by nobody',
        () {
      final stray = PlanVote.fromJson({'id': 'a', 'plan_time': '03:15:00'});

      expect(slotVoteCounts([stray]), [0, 0, 0, 0, 0]);
      expect(leadingSlot([stray]), isNull);
    });
  });

  group('the leader', () {
    test('is the slot the most people picked', () {
      expect(
        leadingSlot([
          voteFor(PlanSlot.early, id: 'a'),
          voteFor(PlanSlot.dinner, id: 'b'),
          voteFor(PlanSlot.dinner, id: 'c'),
        ]),
        same(PlanSlot.dinner),
      );
    });

    test('is nobody when nobody has voted', () {
      expect(leadingSlot(const []), isNull);
    });

    test('is nobody on a tie, rather than whichever comes first', () {
      expect(
        leadingSlot([
          voteFor(PlanSlot.noon, id: 'a'),
          voteFor(PlanSlot.dinner, id: 'b'),
        ]),
        isNull,
      );
    });

    test('a tie broken by a third vote has a leader again', () {
      expect(
        leadingSlot([
          voteFor(PlanSlot.noon, id: 'a'),
          voteFor(PlanSlot.dinner, id: 'b'),
          voteFor(PlanSlot.noon, id: 'c'),
        ]),
        same(PlanSlot.noon),
      );
    });
  });

  group('my own vote', () {
    final votes = [
      voteFor(PlanSlot.noon, id: 'a'),
      voteFor(PlanSlot.supper, id: 'b'),
    ];

    test('is the chip I put it on', () {
      expect(voteSlotOf(votes, 'b'), same(PlanSlot.supper));
    });

    test('is nothing when I have not voted', () {
      expect(voteSlotOf(votes, 'c'), isNull);
    });

    test('is nothing when the page does not know who is looking', () {
      expect(voteSlotOf(votes, null), isNull);
    });
  });

  group('what the chips say', () {
    test('a chip with no votes says only the time', () {
      expect(slotChipLabel(PlanSlot.dinner, 0), '20:00');
      expect(slotChipSemanticLabel(PlanSlot.dinner, 0), '20:00, no votes yet');
    });

    test('one vote is singular', () {
      expect(slotChipLabel(PlanSlot.dinner, 1), '20:00 · 1');
      expect(slotChipSemanticLabel(PlanSlot.dinner, 1), '20:00, 1 vote');
    });

    test('more than one is plural', () {
      expect(slotChipSemanticLabel(PlanSlot.supper, 3), 'Late, 3 votes');
    });
  });

  group('who is still to answer', () {
    test('counts the people who have not voted', () {
      expect(votesOutstandingLine(voted: 1, asked: 3), '2 people still to vote');
    });

    test('one is singular', () {
      expect(votesOutstandingLine(voted: 2, asked: 3), '1 person still to vote');
    });

    test('says nothing once everybody has', () {
      expect(votesOutstandingLine(voted: 3, asked: 3), isNull);
    });

    test('says nothing when more voted than were counted as asked', () {
      expect(votesOutstandingLine(voted: 4, asked: 3), isNull);
    });
  });

  group('what a guest said', () {
    test('reads the three statuses back in words', () {
      expect(planStatusLabel('going'), 'Going');
      expect(planStatusLabel('declined'), "Can't");
      expect(planStatusLabel('invited'), 'Asked');
    });

    test('somebody who asked to join reads differently from somebody asked',
        () {
      // The two words are one letter apart on the wire and opposite in
      // meaning: 'invited' is the owner asking them, 'requested' is them
      // asking the owner (D153).
      expect(planStatusLabel('requested'), 'Asked to join');
    });

    test('an unknown status reads as unanswered rather than as itself', () {
      expect(planStatusLabel('bananas'), 'Asked');
    });
  });

  test('the fake repository speaks the same vote shape', () {
    // Guards the widget tests below this one: a fake whose votes keyed
    // themselves differently would make every chip show zero.
    expect(
      testPlanVote(PlanSlot.dinner, 'a').slotKey,
      slotVoteKey(PlanSlot.dinner),
    );
  });
}
