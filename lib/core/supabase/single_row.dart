/// A `returns public.profiles` (or any single-row) RPC comes back as a single
/// object, but PostgREST has shipped it wrapped in an array before; accept
/// either. Anything else throws: silently returning an empty row would build
/// a blank profile — null `onboarded_at` and all — and hand it to the session,
/// kicking a fully onboarded user back into the wizard with no error anywhere.
/// Every caller already treats a throw as "the write did not stick".
Map<String, dynamic> asSingleRow(Object? response) {
  if (response is Map<String, dynamic>) {
    return response;
  }
  if (response is List && response.isNotEmpty) {
    final first = response.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
  }
  throw FormatException(
    'Expected a single row, got ${response.runtimeType}',
  );
}
