/// A pickable row from `public.cuisines` or `public.dietary_tags`.
///
/// Both catalogs have the same shape, so the wizard renders them with one
/// chip widget; only `cuisines` carries an emoji.
class TasteOption {
  const TasteOption({
    required this.id,
    required this.slug,
    required this.label,
    this.emoji,
  });

  final int id;
  final String slug;
  final String label;
  final String? emoji;

  factory TasteOption.fromJson(Map<String, dynamic> json) {
    final emoji = (json['emoji'] as String?)?.trim();
    return TasteOption(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
      emoji: emoji == null || emoji.isEmpty ? null : emoji,
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
