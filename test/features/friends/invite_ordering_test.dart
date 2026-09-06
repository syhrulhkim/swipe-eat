import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/domain/invite_ordering.dart';

final DateTime _now = DateTime(2026, 9, 6, 19, 41);

List<String> _order(
  List<(DateTime, List<String>)> plans, {
  Set<String>? among,
}) {
  return recentCompanionIds(
    plans: plans,
    among: among ?? {'a', 'b', 'c'},
    now: _now,
  );
}

void main() {
  group('recentCompanionIds', () {
    test('nobody has eaten with anybody yet', () {
      expect(_order(const []), isEmpty);
    });

    test('the most recent dinner comes first', () {
      expect(
        _order([
          (DateTime(2026, 3, 1), ['a']),
          (DateTime(2026, 9, 1), ['b']),
          (DateTime(2026, 7, 4), ['c']),
        ]),
        ['b', 'c', 'a'],
      );
    });

    test('one dinner last week beats three in March', () {
      // Ordered by the last time, not by how many times: somebody you saw on
      // Friday is a better guess than somebody you saw often in the spring.
      expect(
        _order([
          (DateTime(2026, 3, 1), ['a']),
          (DateTime(2026, 3, 8), ['a']),
          (DateTime(2026, 3, 15), ['a']),
          (DateTime(2026, 9, 1), ['b']),
        ]),
        ['b', 'a'],
      );
    });

    test('a plan that has not happened yet is not somebody you ate with', () {
      // "Ate with recently" is past tense. Tomorrow's guests are already on
      // that plan and inviting them again would be the wrong list entirely.
      expect(
        _order([
          (DateTime(2026, 9, 20), ['a']),
          (DateTime(2026, 9, 6), ['b']),
        ]),
        isEmpty,
      );
    });

    test('somebody who is not your friend is not offered', () {
      // A guest the plan's owner invited can be a stranger to you, and a
      // stranger cannot be sent an invite.
      expect(
        _order(
          [
            (DateTime(2026, 9, 1), ['a', 'stranger']),
          ],
        ),
        ['a'],
      );
    });

    test('one person appears once, however many dinners', () {
      expect(
        _order([
          (DateTime(2026, 8, 1), ['a', 'b']),
          (DateTime(2026, 8, 8), ['a', 'b']),
        ]),
        ['a', 'b'],
      );
    });

    test('two people from the same dinner keep a stable order', () {
      // Otherwise the list reshuffles itself between builds, which reads as a
      // bug even when every name in it is right.
      final first = _order([
        (DateTime(2026, 8, 1), ['c', 'a', 'b']),
      ]);
      final second = _order([
        (DateTime(2026, 8, 1), ['b', 'c', 'a']),
      ]);
      expect(first, second);
    });

    test('an empty friend list offers nobody', () {
      expect(
        _order(
          [
            (DateTime(2026, 8, 1), ['a']),
          ],
          among: const {},
        ),
        isEmpty,
      );
    });
  });

  group('matchesQuery', () {
    test('an empty query matches everybody', () {
      expect(matchesQuery('Aiman Zulkifli', ''), isTrue);
      expect(matchesQuery('Aiman Zulkifli', '   '), isTrue);
    });

    test('matches the half of a name people can spell', () {
      expect(matchesQuery('Aiman Zulkifli', 'zul'), isTrue);
      expect(matchesQuery('Aiman Zulkifli', 'AIM'), isTrue);
    });

    test('a name that is not there does not match', () {
      expect(matchesQuery('Aiman Zulkifli', 'mei'), isFalse);
    });

    test('surrounding spaces are the typist, not the query', () {
      expect(matchesQuery('Mei Kee Tan', '  mei '), isTrue);
    });
  });
}
