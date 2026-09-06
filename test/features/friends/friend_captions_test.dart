import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/friends/domain/friend_captions.dart';

void main() {
  group('firstName', () {
    test('names people the way you would out loud', () {
      expect(firstName('Aiman Zulkifli'), 'Aiman');
      expect(firstName('Mei Kee Tan'), 'Mei');
      expect(firstName('Priya'), 'Priya');
    });

    test('survives the whitespace a display name can carry', () {
      expect(firstName('  Danial   Ng '), 'Danial');
      expect(firstName(''), '');
      expect(firstName('   '), '');
    });
  });

  group('avatarInitials', () {
    test('two words give their initials', () {
      expect(avatarInitials('Mei Kee Tan'), 'MK');
      expect(avatarInitials('Aiman Zulkifli'), 'AZ');
    });

    test('one word gives its first two letters', () {
      expect(avatarInitials('Priya'), 'PR');
      expect(avatarInitials('bo'), 'BO');
      expect(avatarInitials('X'), 'X');
    });

    test('an empty name gives nothing, not a placeholder', () {
      // The ground colour alone reads better than a literal "??" on a face.
      expect(avatarInitials(''), '');
      expect(avatarInitials('   '), '');
    });
  });

  group('avatarGroundIndex', () {
    test('one person keeps one colour', () {
      // The property that matters: a face that changed colour between screens
      // would read as a different person.
      const id = 'aaaaaaaa-0000-4000-8000-000000000001';
      expect(
        avatarGroundIndex(id, kAvatarGrounds.length),
        avatarGroundIndex(id, kAvatarGrounds.length),
      );
    });

    test('always lands inside the palette', () {
      for (var i = 0; i < 200; i++) {
        final index = avatarGroundIndex('user-$i', kAvatarGrounds.length);
        expect(index, inInclusiveRange(0, kAvatarGrounds.length - 1));
      }
    });

    test('spreads across the five grounds rather than favouring one', () {
      final seen = {
        for (var i = 0; i < 200; i++)
          avatarGroundIndex('user-$i', kAvatarGrounds.length),
      };
      expect(seen.length, kAvatarGrounds.length);
    });

    test('an empty palette does not divide by zero', () {
      expect(avatarGroundIndex('anyone', 0), 0);
    });
  });

  group('friendsBiteCaption', () {
    test('nobody means no row at all', () {
      expect(friendsBiteCaption(const []), isNull);
      expect(friendsBiteCaption(const ['', '  ']), isNull);
    });

    test('one friend', () {
      expect(friendsBiteCaption(['Aiman Zulkifli']), "Aiman ngap'd this");
    });

    test('two friends are both named', () {
      expect(
        friendsBiteCaption(['Aiman Zulkifli', 'Mei Kee Tan']),
        "Aiman and Mei ngap'd this",
      );
    });

    test('the third friend is a count, not a name', () {
      // The design's own copy would read "and 1 friend", not "and Syafiq":
      // past the second name the sentence's job is to be a number.
      expect(
        friendsBiteCaption(['Aiman Zulkifli', 'Mei Kee Tan', 'Syafiq Rahman']),
        "Aiman, Mei and 1 friend ngap'd this",
      );
    });

    test('the design\'s own line, from six people', () {
      expect(
        friendsBiteCaption([
          'Aiman Zulkifli',
          'Mei Kee Tan',
          'Syafiq Rahman',
          'Priya Raj',
          'Jia Wen Lim',
          'Danial Ng',
        ]),
        "Aiman, Mei and 4 friends ngap'd this",
      );
    });

    test('singular and plural are both spelled correctly', () {
      final one = friendsBiteCaption(['A B', 'C D', 'E F']);
      final two = friendsBiteCaption(['A B', 'C D', 'E F', 'G H']);
      expect(one, contains('1 friend '));
      expect(one, isNot(contains('1 friends')));
      expect(two, contains('2 friends'));
    });

    test('blank names are not counted', () {
      expect(
        friendsBiteCaption(['Aiman Zulkifli', '', 'Mei Kee Tan']),
        "Aiman and Mei ngap'd this",
      );
    });
  });

  group('planPeopleLine', () {
    test('a plan with nobody on it is just you', () {
      expect(planPeopleLine(guests: 0, confirmed: 0), 'Just you');
      // The owner is not a guest on their own plan, so a negative can only be
      // a bug upstream; it still must not print "-1 friends".
      expect(planPeopleLine(guests: -1, confirmed: 0), 'Just you');
    });

    test('the design\'s own line', () {
      expect(planPeopleLine(guests: 3, confirmed: 2), '3 friends · 2 confirmed');
    });

    test('one friend is singular', () {
      expect(planPeopleLine(guests: 1, confirmed: 1), '1 friend · 1 confirmed');
    });

    test('nobody has answered yet, so the count is left off', () {
      // "3 friends · 0 confirmed" reads as a failure; "3 friends" reads as an
      // invitation nobody has answered, which is what it is.
      expect(planPeopleLine(guests: 3, confirmed: 0), '3 friends');
    });
  });

  group('selectedCountLabel', () {
    test('counts people, singular and plural', () {
      expect(selectedCountLabel(0), '0 people selected');
      expect(selectedCountLabel(1), '1 person selected');
      expect(selectedCountLabel(3), '3 people selected');
    });
  });
}
