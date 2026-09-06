import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Asks the OS for the address book and returns **phone numbers only**.
///
/// A typedef rather than a class because that is all the seam needs, and
/// because it is injected everywhere it is used (D60): `flutter test` has no
/// contacts platform channel, so a widget test that could reach the real
/// reader would be a widget test that throws. Every test in this feature runs
/// against a fake list.
///
/// Returns an empty list when permission was refused. That is not an error
/// worth a message of its own — the screen already has a "nobody yet" state,
/// and a user who just tapped Deny does not need to be told what they did.
typedef ContactsReader = Future<List<String>> Function();

/// The real one. Names, emails, photos and everything else stay on the device:
/// the fetch asks for [ContactProperty.phone] and nothing else, so the address
/// book's names are never even in this process's memory.
///
/// The numbers are not held anywhere either. The caller hashes them and drops
/// the list, so the widest the address book is ever in memory is the length of
/// one call.
Future<List<String>> readContactPhoneNumbers() async {
  try {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    // `limited` is iOS 18's "only these contacts", which is a perfectly good
    // answer — it means the user chose who to share, which is more consent
    // than the all-or-nothing prompt asks for.
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      return const [];
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    return [
      for (final contact in contacts)
        for (final phone in contact.phones) phone.number,
    ];
  } on Object catch (error) {
    debugPrint('Reading contacts failed: $error');
    return const [];
  }
}

/// What a test injects when the step must not read anything at all — Skip's
/// contract. Calling it is a bug, and a test that asserts Skip sent nothing
/// asserts on the call count of its own fake rather than on this.
Future<List<String>> noContacts() async => const [];
