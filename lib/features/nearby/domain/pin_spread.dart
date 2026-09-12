import 'dart:ui';

/// One pin as the spreader sees it: where its blob's centre lands on screen,
/// and the box its marker occupies around that point.
class PinBox {
  const PinBox({
    required this.id,
    required this.anchor,
    required this.width,
    required this.height,
    required this.blobSize,
  });

  final int id;

  /// The blob's centre in screen space — the projected coordinate.
  final Offset anchor;
  final double width;
  final double height;

  /// The blob's diameter; the box hangs below the blob by its caption.
  final double blobSize;

  Rect rectAt(Offset shift) {
    final centre = anchor + shift;
    return Rect.fromLTWH(
      centre.dx - width / 2,
      centre.dy - blobSize / 2,
      width,
      height,
    );
  }
}

/// Pushes overlapping pins apart until none overlap, or gives up after
/// [iterations] passes. Returns each pin's shift from its true position.
///
/// The first pin never moves — it is the closest, and the one the user is
/// most likely looking for — so every later pin yields to the ones before it.
/// Each collision is resolved along whichever axis needs the smaller move, so
/// pins slide sideways past each other rather than stacking into a column.
/// Pure, so a test can hand it any layout and read the answer.
Map<int, Offset> spreadPins(
  List<PinBox> pins, {
  double gap = 4,
  int iterations = 60,
}) {
  final shifts = <int, Offset>{for (final pin in pins) pin.id: Offset.zero};
  if (pins.length < 2) {
    return shifts;
  }

  for (var pass = 0; pass < iterations; pass++) {
    var moved = false;
    for (var i = 1; i < pins.length; i++) {
      final mover = pins[i];
      for (var j = 0; j < i; j++) {
        final fixed = pins[j];
        final a = mover.rectAt(shifts[mover.id]!).inflate(gap / 2);
        final b = fixed.rectAt(shifts[fixed.id]!).inflate(gap / 2);
        if (!a.overlaps(b)) {
          continue;
        }
        // How far to slide on each axis to clear the other box.
        final dxRight = b.right - a.left;
        final dxLeft = a.right - b.left;
        final dyDown = b.bottom - a.top;
        final dyUp = a.bottom - b.top;
        final dx = dxRight < dxLeft ? dxRight : -dxLeft;
        final dy = dyDown < dyUp ? dyDown : -dyUp;
        final shift = dx.abs() <= dy.abs() ? Offset(dx, 0) : Offset(0, dy);
        shifts[mover.id] = shifts[mover.id]! + shift;
        moved = true;
      }
    }
    if (!moved) {
      break;
    }
  }
  return shifts;
}
