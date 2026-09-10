import '../../restaurants/domain/opening_hours.dart';

/// Where a wishlist row came from. The label on the right of the row is read
/// straight off this, so it is the row's provenance and not a category the
/// user picks.
enum WishlistSource {
  /// Saved with the deck's Later gesture.
  swiped,

  /// Someone sent it. The sender is [WishlistItem.fromUserId]; the page looks
  /// that id up in the friends cache to fill in [WishlistItem.fromUserName].
  friend,

  /// Typed into the "Add a place…" bar. The only source allowed to carry no
  /// restaurant, which is exactly why it exists.
  manual;

  /// The wire value. An unknown one is not an error — a row written by a
  /// newer client should still list, so it falls back to [manual], the source
  /// that assumes the least.
  static WishlistSource fromWire(String? value) {
    return switch (value) {
      'swiped' => WishlistSource.swiped,
      'friend' => WishlistSource.friend,
      _ => WishlistSource.manual,
    };
  }

  String get wire => name;
}

/// One line of the wishlist: a place to try, and whether it has been eaten.
///
/// The title lives on the row rather than only on the joined restaurant
/// because a manual entry has no restaurant to join to — the user typed a
/// name, and that name is all there is.
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.source,
    required this.createdAt,
    this.restaurantId,
    this.fromUserId,
    this.fromUserName,
    this.eatenAt,
    this.coverUrl,
    this.tag,
    this.neighbourhood,
    this.hours = OpeningHours.unknown,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    // Null when the row points at a restaurant the catalog policy hides, or at
    // nothing at all (a manual entry). Either way the row still lists.
    final restaurant = json['restaurants'] as Map<String, dynamic>?;

    final images = <Map<String, dynamic>>[
      ...?(restaurant?['restaurant_images'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
    ]..sort(
        (a, b) => ((a['position'] as num?) ?? 0)
            .compareTo((b['position'] as num?) ?? 0),
      );

    String? cover;
    for (final image in images) {
      final url = image['url'] as String? ?? '';
      if (url.isNotEmpty) {
        cover = url;
        break;
      }
    }

    return WishlistItem(
      id: (json['id'] as num).toInt(),
      // The stored title wins over the joined name: it is what the user saw
      // when they saved the place, and a renamed restaurant should not
      // silently rewrite somebody's list.
      title: json['title'] as String? ??
          restaurant?['name'] as String? ??
          'A place',
      source: WishlistSource.fromWire(json['source'] as String?),
      restaurantId: (json['restaurant_id'] as num?)?.toInt(),
      fromUserId: json['from_user_id'] as String?,
      eatenAt: DateTime.tryParse(json['eaten_at'] as String? ?? '')?.toLocal(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      coverUrl: cover,
      tag: restaurant?['tag'] as String?,
      neighbourhood: restaurant?['neighbourhood'] as String?,
      hours: restaurant == null
          ? OpeningHours.unknown
          : OpeningHours.fromJson(restaurant),
    );
  }

  final int id;
  final String title;
  final WishlistSource source;

  /// Null for a manual entry, and for a row whose restaurant has since gone.
  final int? restaurantId;

  /// Who sent it, when [source] is [WishlistSource.friend].
  final String? fromUserId;

  /// Their display name, filled in by the page from the friends cache. Null
  /// when the sender is not a friend of mine — somebody can send a place and
  /// then be removed — and the row says "From a friend" for those.
  final String? fromUserName;

  /// When the user crossed it off, or null while it is still to go.
  final DateTime? eatenAt;
  final DateTime createdAt;

  /// The restaurant's first photo, when it has one.
  final String? coverUrl;
  final String? tag;
  final String? neighbourhood;
  final OpeningHours hours;

  bool get isEaten => eatenAt != null;

  /// "Nasi lemak · Kampung Baru · open 24 h" — whichever of the three the row
  /// actually knows, joined by the design's separator. Empty when it knows
  /// none, which is the ordinary case for a manual entry.
  String get subtitle {
    final tagLabel = tag;
    final area = neighbourhood;

    return [
      if (tagLabel != null && tagLabel.isNotEmpty) tagLabel,
      if (area != null && area.isNotEmpty) area,
      if (hours.isAllDay) 'open 24 h',
    ].join(' · ');
  }

  WishlistItem copyWith({
    DateTime? eatenAt,
    bool clearEatenAt = false,
    String? fromUserName,
  }) {
    return WishlistItem(
      id: id,
      title: title,
      source: source,
      createdAt: createdAt,
      restaurantId: restaurantId,
      fromUserId: fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      eatenAt: clearEatenAt ? null : (eatenAt ?? this.eatenAt),
      coverUrl: coverUrl,
      tag: tag,
      neighbourhood: neighbourhood,
      hours: hours,
    );
  }
}

/// The list's one order, in one place: still-to-go first, then eaten, and
/// newest first inside each half.
///
/// A pure function rather than an `order by` alone, because the same ordering
/// has to happen client-side the instant a row is crossed off — the row sinks
/// on the tap, not on the next round trip, and both paths must agree.
List<WishlistItem> sortWishlist(Iterable<WishlistItem> items) {
  return List<WishlistItem>.of(items)
    ..sort((a, b) {
      if (a.isEaten != b.isEaten) {
        return a.isEaten ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
}
