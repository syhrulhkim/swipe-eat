import 'dart:ui';

import 'design_tokens.dart';

/// Matches exactly 6 or 8 hex digits, so signs and surrounding whitespace --
/// both of which `int.tryParse` happily accepts -- are rejected instead of
/// silently parsing as a shorter colour.
final _hexDigits = RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Parses '#RRGGBB' / 'RRGGBB' / '#AARRGGBB' into a [Color], forcing full
/// opacity. Surrounding whitespace is ignored; any other shape (short forms,
/// junk, null) returns [fallback].
Color parseHexColor(String? hex, {Color fallback = kBrandColorFallback}) {
  if (hex == null) {
    return fallback;
  }

  final digits = hex.trim().replaceFirst('#', '').trim();
  if (!_hexDigits.hasMatch(digits)) {
    return fallback;
  }

  return Color(0xFF000000 | int.parse(digits, radix: 16));
}

/// The inverse of [parseHexColor], for writing a colour back out to a cache
/// entry in the same '#RRGGBB' shape the database stores.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
