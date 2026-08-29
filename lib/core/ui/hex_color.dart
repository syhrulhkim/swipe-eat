import 'dart:ui';

/// Matches exactly 6 or 8 hex digits, so signs and surrounding whitespace --
/// both of which `int.tryParse` happily accepts -- are rejected instead of
/// silently parsing as a shorter colour.
final _hexDigits = RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Parses '#RRGGBB' / 'RRGGBB' / '#AARRGGBB' into a [Color], forcing full
/// opacity. Surrounding whitespace is ignored; any other shape (short forms,
/// junk, null) returns [fallback].
Color parseHexColor(String? hex, {Color fallback = const Color(0xFF141922)}) {
  if (hex == null) {
    return fallback;
  }

  final digits = hex.trim().replaceFirst('#', '').trim();
  if (!_hexDigits.hasMatch(digits)) {
    return fallback;
  }

  return Color(0xFF000000 | int.parse(digits, radix: 16));
}
