/// The sentences that count people, in one place because every one of them is
/// a plural-and-comma problem and getting "Aiman and 1 friends" on screen is
/// the kind of bug nobody files.
///
/// All pure, all tested directly. No widget in this feature builds a sentence
/// of its own.
library;

/// The first word of a name — "Aiman Zulkifli" → "Aiman".
///
/// The captions name people the way you would out loud, and out loud nobody
/// says the surname. A single-word name is already the first word.
String firstName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final space = trimmed.indexOf(RegExp(r'\s'));
  return space == -1 ? trimmed : trimmed.substring(0, space);
}

/// Two letters for a face with no photo. "Mei Kee Tan" → "MK", "Priya" → "PR".
///
/// Two words give their initials; one word gives its first two letters, upper
/// cased. An empty name gives nothing rather than a placeholder, because the
/// ground colour alone reads better than a literal "??" on a face.
String avatarInitials(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) {
    return '';
  }
  if (words.length == 1) {
    final word = words.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// Which of [kAvatarGrounds] a person gets, by index.
///
/// Hashed off the id rather than off the list position, so one person is the
/// same colour on the detail screen, on their plan card and in the invite list.
/// A face that changed colour between screens would read as a different person.
int avatarGroundIndex(String userId, int groundCount) {
  if (groundCount <= 0) {
    return 0;
  }
  var hash = 0;
  for (final unit in userId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % groundCount;
}

/// "Aiman, Mei Kee and 4 friends ngap'd this" — the detail screen's row.
///
/// [names] is every friend who liked the place, in the order the server
/// returned them; [named] is how many are called by name before the rest
/// become a number. The design names two and draws three faces.
///
/// The shapes, all of which appear in the wild:
///
///   * nobody          → null, and the row does not draw at all
///   * one             → "Aiman ngap'd this"
///   * two             → "Aiman and Mei Kee ngap'd this"
///   * three           → "Aiman, Mei Kee and 1 friend ngap'd this"
///   * more            → "Aiman, Mei Kee and 4 friends ngap'd this"
///
/// The three case is the one worth stating: the design's own copy would read
/// "and 1 friend", not "and Syafiq", because the sentence's job past the second
/// name is to be a count.
String? friendsBiteCaption(List<String> names, {int named = 2}) {
  final people = names.where((name) => name.trim().isNotEmpty).toList();
  if (people.isEmpty) {
    return null;
  }

  final firsts = people.map(firstName).toList();

  if (firsts.length == 1) {
    return "${firsts[0]} ngap'd this";
  }
  if (firsts.length <= named) {
    final head = firsts.take(firsts.length - 1).join(', ');
    return "$head and ${firsts.last} ngap'd this";
  }

  final rest = firsts.length - named;
  final head = firsts.take(named).join(', ');
  return "$head and $rest ${rest == 1 ? 'friend' : 'friends'} ngap'd this";
}

/// "Just you", "3 friends · 2 confirmed" — the line under a plan card's title,
/// and the line the invite screen reads back.
///
/// [guests] counts everybody invited; [confirmed] counts the ones who said yes.
/// The owner is not a guest on their own plan, which is why one person on a
/// plan is "Just you" rather than "1 friend".
///
/// The confirmed half is dropped when nobody has answered yet: "3 friends · 0
/// confirmed" reads as a failure, and "3 friends" reads as an invitation that
/// has not been answered, which is what it is.
String planPeopleLine({required int guests, required int confirmed}) {
  if (guests <= 0) {
    return 'Just you';
  }
  final friends = '$guests ${guests == 1 ? 'friend' : 'friends'}';
  if (confirmed <= 0) {
    return friends;
  }
  return '$friends · $confirmed confirmed';
}

/// "3 selected" — the invite foot's own count, and the label a screen reader
/// hears when the number beside "Send invites" changes.
String selectedCountLabel(int count) =>
    '$count ${count == 1 ? 'person' : 'people'} selected';
