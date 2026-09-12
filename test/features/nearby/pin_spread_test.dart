import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/nearby/domain/pin_spread.dart';

PinBox box(int id, double x, double y, {double blob = 76}) {
  return PinBox(
    id: id,
    anchor: Offset(x, y),
    width: 88,
    height: blob + 74,
    blobSize: blob,
  );
}

bool anyOverlap(List<PinBox> pins, Map<int, Offset> shifts) {
  for (var i = 0; i < pins.length; i++) {
    for (var j = i + 1; j < pins.length; j++) {
      if (pins[i].rectAt(shifts[pins[i].id]!).overlaps(
            pins[j].rectAt(shifts[pins[j].id]!),
          )) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  test('pins that do not touch are left where they are', () {
    final pins = [box(1, 100, 100), box(2, 400, 100), box(3, 100, 400)];
    final shifts = spreadPins(pins);
    expect(shifts.values.every((s) => s == Offset.zero), isTrue);
  });

  test('two pins on the same spot are pushed apart, the first staying put', () {
    final pins = [box(1, 200, 200), box(2, 200, 200)];
    final shifts = spreadPins(pins);
    expect(shifts[1], Offset.zero);
    expect(shifts[2], isNot(Offset.zero));
    expect(anyOverlap(pins, shifts), isFalse);
  });

  test('five pins in a pile end up with no two overlapping', () {
    final pins = [
      box(1, 200, 200, blob: 96),
      box(2, 210, 205, blob: 90),
      box(3, 190, 215, blob: 80),
      box(4, 205, 190, blob: 60),
      box(5, 200, 200, blob: 52),
    ];
    final shifts = spreadPins(pins);
    expect(shifts[1], Offset.zero);
    expect(anyOverlap(pins, shifts), isFalse);
  });

  test('a slight side-by-side overlap slides sideways, not down', () {
    // Two blobs 60 px apart horizontally with 88 px boxes: the cheaper move
    // is 28 px sideways, not a whole box height down.
    final pins = [box(1, 100, 100), box(2, 160, 100)];
    final shifts = spreadPins(pins, gap: 0);
    expect(shifts[2]!.dy, 0);
    expect(shifts[2]!.dx, greaterThan(0));
    expect(anyOverlap(pins, shifts), isFalse);
  });

  test('a single pin needs no spreading', () {
    expect(spreadPins([box(1, 0, 0)]), {1: Offset.zero});
    expect(spreadPins(const []), isEmpty);
  });
}
