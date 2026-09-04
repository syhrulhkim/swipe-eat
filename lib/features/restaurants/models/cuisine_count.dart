/// One row of `get_cuisine_counts`: a cuisine and how many active restaurants
/// carry it, with the best-rated restaurant's photo as the tile cover.
///
/// `cuisines.emoji` is deliberately **not** read. The design forbids emoji as
/// food imagery; a cuisine is shown as a photo, or as its name on a chip when
/// there is no photo yet (D88).
class CuisineCount {
  const CuisineCount({
    required this.id,
    required this.slug,
    required this.label,
    required this.restaurantCount,
    this.coverUrl,
  });

  final int id;
  final String slug;
  final String label;

  /// Counted over the whole catalog, not the user's radius — the grid is a
  /// menu of cravings, and a craving does not stop existing out of range.
  final int restaurantCount;

  /// Null when no restaurant in the cuisine has a photo yet.
  final String? coverUrl;

  factory CuisineCount.fromJson(Map<String, dynamic> json) {
    return CuisineCount(
      id: (json['cuisine_id'] as num).toInt(),
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
      restaurantCount: (json['restaurant_count'] as num?)?.toInt() ?? 0,
      coverUrl: json['cover_url'] as String?,
    );
  }
}
