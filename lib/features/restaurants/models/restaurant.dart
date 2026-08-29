import 'dart:ui';

import '../../../core/ui/hex_color.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.tag,
    required this.details,
    required this.brandColor,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.reviews,
    this.videoUrl,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // Copied into a growable list: the `const []` fallback is unmodifiable and
    // sorting the raw payload in place would mutate the caller's row.
    final images = List<Map<String, dynamic>>.from(
      (json['restaurant_images'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
    )..sort(
        (a, b) => ((a['position'] as num?) ?? 0)
            .compareTo((b['position'] as num?) ?? 0),
      );

    return Restaurant(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Restaurant',
      tag: json['tag'] as String? ?? '',
      details: json['details'] as String? ?? '',
      brandColor: parseHexColor(json['brand_color'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      imageUrls: images
          .map((image) => image['url'] as String? ?? '')
          .where((url) => url.isNotEmpty)
          .toList(),
      reviews: (json['reviews'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(RestaurantReview.fromJson)
          .toList(),
      videoUrl: json['video_url'] as String?,
    );
  }

  /// The row shape [Restaurant.fromJson] reads, so a cached deck is parsed by
  /// exactly the same code as a fresh one — a field the parser learns about
  /// cannot silently go missing on the way through the cache.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'tag': tag,
      'details': details,
      'brand_color': hexFromColor(brandColor),
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'video_url': videoUrl,
      'restaurant_images': <Map<String, dynamic>>[
        for (var position = 0; position < imageUrls.length; position++)
          {'url': imageUrls[position], 'position': position},
      ],
      'reviews': reviews.map((review) => review.toJson()).toList(),
    };
  }

  final int id;
  final String name;
  final String tag;
  final String details;
  final Color brandColor;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final List<RestaurantReview> reviews;
  final String? videoUrl;
}

class RestaurantReview {
  const RestaurantReview({
    required this.author,
    required this.text,
  });

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    return RestaurantReview(
      author: json['author_name'] as String? ?? 'Reviewer',
      text: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'author_name': author, 'body': text};
  }

  final String author;
  final String text;
}
