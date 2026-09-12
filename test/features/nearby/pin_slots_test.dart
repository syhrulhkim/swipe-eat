import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/nearby/domain/pin_slots.dart';

void main() {
  const area = Rect.fromLTWH(0, 40, 390, 600);

  group('slotBoxTop', () {
    test('a left-anchored slot is measured from the left edge', () {
      const slot = NearbyPinSlot(x: 0.08, y: 0.14);
      final top = slotBoxTop(slot, area, boxWidth: 88);
      expect(top.dx, closeTo(0.08 * 390 + 44, 0.001));
      expect(top.dy, closeTo(40 + 0.14 * 600, 0.001));
    });

    test('a right-anchored slot is measured from the right edge', () {
      const slot = NearbyPinSlot(x: 0.06, y: 0.18, fromRight: true);
      final top = slotBoxTop(slot, area, boxWidth: 88);
      expect(top.dx, closeTo(390 - 0.06 * 390 - 88 + 44, 0.001));
    });
  });

  group('assignPinsToSlots', () {
    final tops = [
      for (final slot in kNearbyPinSlots) slotBoxTop(slot, area, boxWidth: 88),
    ];
    final big = [for (final slot in kNearbyPinSlots) slot.big];

    test('the design\'s slots never collide at a 390 px phone', () {
      Rect boxAt(int i) {
        final blob = big[i] ? kNearbyPinBigSize : kNearbyPinSize;
        return Rect.fromLTWH(
          tops[i].dx - 44,
          tops[i].dy,
          88,
          blob + kNearbyPinCaptionHeight,
        );
      }

      for (var i = 0; i < tops.length; i++) {
        for (var j = i + 1; j < tops.length; j++) {
          final a = boxAt(i);
          final b = boxAt(j);
          expect(a.overlaps(b), isFalse, reason: 'slots $i and $j overlap');
        }
      }
    });

    test('big pins take the big slots, each slot once', () {
      final pins = [
        const SlotCandidate(id: 1, screen: Offset(195, 300), big: true),
        const SlotCandidate(id: 2, screen: Offset(195, 300), big: true),
        const SlotCandidate(id: 3, screen: Offset(195, 300), big: false),
        const SlotCandidate(id: 4, screen: Offset(195, 300), big: false),
        const SlotCandidate(id: 5, screen: Offset(195, 300), big: false),
      ];
      final assignment = assignPinsToSlots(pins, tops, big);
      expect(assignment.length, 5);
      expect(assignment.values.toSet().length, 5);
      expect(big[assignment[1]!], isTrue);
      expect(big[assignment[2]!], isTrue);
      for (final id in [3, 4, 5]) {
        expect(big[assignment[id]!], isFalse);
      }
    });

    test('a pin keeps to its own side of the map', () {
      final pins = [
        // Far north-west and far south-east of the me-dot.
        const SlotCandidate(id: 1, screen: Offset(20, 60), big: false),
        const SlotCandidate(id: 2, screen: Offset(370, 520), big: false),
      ];
      final assignment = assignPinsToSlots(pins, tops, big);
      expect(assignment[1], 0); // left:8% top:14%
      expect(assignment[2], 5); // left:36% top:60%, the lowest ordinary slot
    });

    test('more pins than slots leaves the extras unassigned', () {
      final pins = [
        for (var i = 0; i < 8; i++)
          SlotCandidate(id: i, screen: const Offset(100, 100), big: false),
      ];
      final assignment = assignPinsToSlots(pins, tops, big);
      expect(assignment.length, 6);
      expect(assignment.containsKey(7), isFalse);
    });

    test('no pins, no slots taken', () {
      expect(assignPinsToSlots(const [], tops, big), isEmpty);
    });
  });
}
