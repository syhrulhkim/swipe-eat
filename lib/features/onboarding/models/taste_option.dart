/// A pickable row from `public.cuisines` or `public.dietary_tags`.
///
/// Both catalogs have the same shape, so the wizard renders them with one
/// chip widget. Neither carries an emoji: the design forbids emoji as food
/// imagery, so a chip is its label alone (D88).
class TasteOption {
  const TasteOption({
    required this.id,
    required this.slug,
    required this.label,
  });

  final int id;
  final String slug;
  final String label;

  factory TasteOption.fromJson(Map<String, dynamic> json) {
    return TasteOption(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

/// Everything the wizard needs before its first frame, fetched in one go.
class TasteCatalog {
  const TasteCatalog({required this.cuisines, required this.dietaryTags});

  const TasteCatalog.empty()
      : cuisines = const [],
        dietaryTags = const [];

  final List<TasteOption> cuisines;
  final List<TasteOption> dietaryTags;
}
