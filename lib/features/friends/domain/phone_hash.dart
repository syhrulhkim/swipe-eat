import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The country a bare local number is assumed to belong to.
///
/// Ngap is a Kuala Lumpur app, so "012-345 6789" written in a Malaysian phone's
/// address book means +60. A number that already carries a country code is
/// left alone, so this default never rewrites somebody's Singaporean cousin.
const String kDefaultCallingCode = '60';

/// "012-345 6789" → "+60123456789". Null when there is no number in there.
///
/// E.164 is the only form both sides of the match agree on, and getting it
/// wrong is the difference between finding your friends and finding nobody —
/// which is why this is a pure function with its own test file rather than
/// three lines inside the controller.
///
/// The rules, in the order they are applied:
///
///   * Everything that is not a digit or a leading `+` goes. Address books are
///     full of spaces, dashes, brackets and the occasional letter.
///   * `00` at the front is the international prefix written the old way; it
///     becomes `+`.
///   * A single leading `0` is a national trunk prefix — Malaysian numbers are
///     written `012…` locally and `+6012…` internationally, so the zero is
///     dropped and the calling code takes its place.
///   * A number that already starts with the calling code and is long enough
///     to be a real number is taken as already international.
///   * Anything under seven digits is not a phone number. Extensions, short
///     codes and half-typed rubbish are dropped rather than hashed into the
///     void, because a short string has few enough possibilities to be worth
///     guessing at.
String? normalizeE164(String raw, {String callingCode = kDefaultCallingCode}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final hadPlus = trimmed.startsWith('+');
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');

  if (digits.isEmpty) {
    return null;
  }

  if (hadPlus) {
    return digits.length < 7 ? null : '+$digits';
  }

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = '$callingCode${digits.substring(1)}';
  } else if (!digits.startsWith(callingCode)) {
    // A local number with no trunk prefix. Short ones are service numbers, not
    // people; a long one is somebody who wrote their mobile without the zero.
    digits = digits.length >= 9 ? '$callingCode$digits' : digits;
  }

  if (digits.length < 7) {
    return null;
  }

  return '+$digits';
}

/// The only thing about a contact that ever leaves the phone: the SHA-256 of
/// its E.164 form, in lowercase hex.
///
/// The server peppers this and hashes it again before comparing, so what is
/// stored is not what is sent and a stolen database does not give up numbers.
/// What is sent is still derived from a contact's number, which is exactly why
/// the onboarding screen says so rather than claiming the matching happens
/// here (D121).
String hashE164(String e164) =>
    sha256.convert(utf8.encode(e164)).toString();

/// Every distinct hash in an address book, ready to post.
///
/// De-duplicated because a person with a mobile and a work number saved twice
/// is one person, and capped because [match_contacts] refuses more than 500 in
/// a call — a cap the client honours rather than discovers.
///
/// Order is not preserved and must not be relied on: the server returns whole
/// people, never "the hash at index 4 matched", so there is nothing to line
/// results back up with. That is a privacy property, not an oversight.
List<String> hashContacts(
  Iterable<String> rawNumbers, {
  String callingCode = kDefaultCallingCode,
  int limit = kMatchContactsLimit,
}) {
  final hashes = <String>{};
  for (final raw in rawNumbers) {
    final e164 = normalizeE164(raw, callingCode: callingCode);
    if (e164 == null) {
      continue;
    }
    hashes.add(hashE164(e164));
    if (hashes.length == limit) {
      break;
    }
  }
  return hashes.toList(growable: false);
}

/// What `public.match_contacts` raises above. Mirrored here so the client stops
/// at the boundary instead of being told about it by a 500.
const int kMatchContactsLimit = 500;
