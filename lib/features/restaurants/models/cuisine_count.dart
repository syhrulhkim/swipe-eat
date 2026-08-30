/// One row of `get_cuisine_counts`: a cuisine and how many active restaurants
/// carry it, with the best-rated restaurant's photo as the tile cover.
class CuisineCount {
  const CuisineCount({
    required this.id,
    required this.slug,
    required this.label,
    required this.emoji,
    required this.restaurantCount,
    this.coverUrl,
  });

  final int id;
  final String slug;
  final String label;
  final String emoji;

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
      emoji: json['emoji'] as String? ?? '',
      restaurantCount: (json['restaurant_count'] as num?)?.toInt() ?? 0,
      coverUrl: json['cover_url'] as String?,
    );
  }
}
