import 'dart:ui';

import '../../../core/ui/design_tokens.dart';

/// A pin waiting for a slot: where its true coordinate projects on screen, and
/// whether it is one of the two the design draws big.
class SlotCandidate {
  const SlotCandidate({
    required this.id,
    required this.screen,
    required this.big,
  });

  final int id;
  final Offset screen;
  final bool big;
}

/// The top-centre of the box a slot describes, inside [area]. The prototype
/// positions a pin by its box's leading edge and top; the box is [boxWidth]
/// wide and the blob is centred in it.
Offset slotBoxTop(NearbyPinSlot slot, Rect area, {required double boxWidth}) {
  final left = slot.fromRight
      ? area.right - slot.x * area.width - boxWidth
      : area.left + slot.x * area.width;
  return Offset(left + boxWidth / 2, area.top + slot.y * area.height);
}

/// Which slot each pin takes.
///
/// Every arrangement of the pins over the slots is scored by how far each pin
/// has to travel from where it truly is, plus [mismatchPenalty] for every big
/// pin in an ordinary slot or ordinary pin in a big slot; the cheapest wins.
/// So the two big pins land in the two big slots, and within each group a pin
/// keeps to its own side of the map — a place to the north-west is drawn to
/// the north-west. Each slot is used at most once; with more pins than slots
/// the pins beyond the slots are left unassigned. Six slots and five pins is
/// 720 arrangements, which is nothing.
Map<int, int> assignPinsToSlots(
  List<SlotCandidate> pins,
  List<Offset> slotTops,
  List<bool> slotBig, {
  double mismatchPenalty = 1e9,
}) {
  assert(slotTops.length == slotBig.length);
  final assignable = pins.length <= slotTops.length
      ? pins
      : pins.sublist(0, slotTops.length);
  if (assignable.isEmpty) {
    return const {};
  }

  var bestCost = double.infinity;
  var best = <int>[];
  final used = List<bool>.filled(slotTops.length, false);
  final current = <int>[];

  void search(int index, double cost) {
    if (cost >= bestCost) {
      return;
    }
    if (index == assignable.length) {
      bestCost = cost;
      best = List<int>.of(current);
      return;
    }
    final pin = assignable[index];
    for (var slot = 0; slot < slotTops.length; slot++) {
      if (used[slot]) {
        continue;
      }
      final travel = (slotTops[slot] - pin.screen).distanceSquared;
      final penalty = pin.big == slotBig[slot] ? 0.0 : mismatchPenalty;
      used[slot] = true;
      current.add(slot);
      search(index + 1, cost + travel + penalty);
      current.removeLast();
      used[slot] = false;
    }
  }

  search(0, 0);
  return {
    for (var i = 0; i < best.length; i++) assignable[i].id: best[i],
  };
}
