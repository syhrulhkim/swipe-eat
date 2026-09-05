/// Readers for maps whose values cannot be trusted.
///
/// A database row has typed columns, but the same parsers also read the
/// router's `extra` payload and the deck cache on disk — a map that was
/// written by an older build, or hand-edited, or truncated. `as num?` on a
/// String there is a crash on the way to a screen; these ask instead, and
/// answer null when the value is not what the field wanted, so the caller's
/// own default takes over.
library;

int? jsonInt(Object? value) => value is num ? value.toInt() : null;

double? jsonDouble(Object? value) => value is num ? value.toDouble() : null;

String? jsonString(Object? value) => value is String ? value : null;

bool? jsonBool(Object? value) => value is bool ? value : null;

/// The list, or an empty one — never null, because every list-valued field in
/// these models degrades to "nothing here" rather than to a missing default.
List<Object?> jsonList(Object? value) =>
    value is List ? value : const <Object?>[];

Map<String, dynamic>? jsonMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;
