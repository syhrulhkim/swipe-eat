import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/friends/domain/phone_hash.dart';

void main() {
  group('normalizeE164', () {
    test('strips the punctuation an address book is full of', () {
      expect(normalizeE164('012-345 6789'), '+60123456789');
      expect(normalizeE164('(012) 345-6789'), '+60123456789');
      expect(normalizeE164('012.345.6789'), '+60123456789');
    });

    test('a leading zero is a trunk prefix, and the calling code replaces it',
        () {
      expect(normalizeE164('0123456789'), '+60123456789');
    });

    test('00 is the international prefix written the old way', () {
      expect(normalizeE164('0060123456789'), '+60123456789');
    });

    test('a number that already carries a + is left alone', () {
      // The whole point of the default country is that it never rewrites
      // somebody who wrote their number properly.
      expect(normalizeE164('+6591234567'), '+6591234567');
      expect(normalizeE164('+1 415 555 0132'), '+14155550132');
    });

    test('a bare local number long enough to be a mobile gets the code', () {
      expect(normalizeE164('123456789'), '+60123456789');
    });

    test('a number already starting with the calling code is international',
        () {
      expect(normalizeE164('60123456789'), '+60123456789');
    });

    test('the calling code is a parameter, not a constant', () {
      expect(normalizeE164('0123456789', callingCode: '65'), '+65123456789');
    });

    test('anything too short to be a phone number is dropped', () {
      // Short codes, extensions and half-typed rubbish. A six-digit string has
      // few enough possibilities to be worth guessing at, so it is never sent.
      for (final short in ['999', '1300', '12345', '123456', '']) {
        expect(normalizeE164(short), isNull, reason: short);
      }
    });

    test('a string with no digits at all is dropped', () {
      expect(normalizeE164('call the shop'), isNull);
      expect(normalizeE164('   '), isNull);
      expect(normalizeE164('+'), isNull);
    });
  });

  group('hashE164', () {
    test('is SHA-256 hex, and stable', () {
      final hash = hashE164('+60123456789');
      expect(hash.length, 64);
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(hash, hashE164('+60123456789'));
    });

    test('two different numbers do not collide', () {
      expect(hashE164('+60123456789'), isNot(hashE164('+60123456780')));
    });

    test('agrees with the database, byte for byte', () {
      // The one property no unit test on either side can prove alone, and the
      // one whose failure is silent: if Dart and Postgres disagreed about how
      // to hash a number, matching would simply find nobody and never say why.
      //
      // This value was read back from the live project as
      //   select public.e164_phone_digest('60123456789')
      // which is the expression the `on_auth_user_phone_verified` trigger
      // hashes a verified number with. Changing either side must break here.
      expect(
        hashE164('+60123456789'),
        '88030e91922da507d9b1ffa68d9896f94313acc33ec5b15c72eca420a6fe775b',
      );
    });

    test('the number itself never appears in the hash', () {
      // Stated as a test because it is the property the whole scheme rests on:
      // what leaves the phone must not contain what it was made from.
      expect(hashE164('+60123456789'), isNot(contains('60123456789')));
    });
  });

  group('hashContacts', () {
    test('hashes every usable number and drops the rest', () {
      final hashes = hashContacts(['012-345 6789', 'not a number', '999']);
      expect(hashes, [hashE164('+60123456789')]);
    });

    test('one person saved twice is one hash', () {
      // A mobile and a work number that normalise the same is the ordinary
      // shape of a contacts list, and sending the duplicate tells the server
      // one more thing than it needs.
      final hashes =
          hashContacts(['012-345 6789', '+60123456789', '0123456789']);
      expect(hashes, hasLength(1));
    });

    test('stops at the server cap rather than being told about it', () {
      final many = [for (var i = 0; i < 600; i++) '+601234$i'];
      expect(hashContacts(many), hasLength(kMatchContactsLimit));
    });

    test('an address book of rubbish sends nothing', () {
      expect(hashContacts(['', 'x', '123']), isEmpty);
    });
  });
}
