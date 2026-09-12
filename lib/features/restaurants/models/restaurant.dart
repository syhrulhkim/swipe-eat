import 'dart:ui';

import '../../../core/ui/hex_color.dart';
import '../domain/opening_hours.dart';
import 'dish.dart';

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
    this.hours = OpeningHours.unknown,
    this.priceFrom,
    this.isHalal,
    this.neighbourhood,
    this.dishes = const [],
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

    final dishes = List<Map<String, dynamic>>.from(
      (json['dishes'] as List<dynamic>? ?? const [])
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
      hours: OpeningHours.fromJson(json),
      priceFrom: (json['price_from'] as num?)?.toInt(),
      isHalal: json['is_halal'] as bool?,
      neighbourhood: json['neighbourhood'] as String?,
      dishes: dishes.map(Dish.fromJson).toList(),
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
      ...hours.toJson(),
      'price_from': priceFrom,
      'is_halal': isHalal,
      'neighbourhood': neighbourhood,
      'dishes': dishes.map((dish) => dish.toJson()).toList(),
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

  /// When it is open. [OpeningHours.unknown] when the caption never said.
  final OpeningHours hours;

  /// The lowest RM figure the caption names — a dish, not a per-person band.
  final int? priceFrom;

  /// True or false only when the caption says so; null is "does not say".
  final bool? isHalal;

  /// The town or suburb from the caption's address, when it had one.
  final String? neighbourhood;

  /// "What people bite", in menu order. Empty until curated.
  final List<Dish> dishes;
}

class RestaurantReview {
  const RestaurantReview({
    required this.author,
    required this.text,
    this.rating,
  });

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    return RestaurantReview(
      author: json['author_name'] as String? ?? 'Reviewer',
      text: json['body'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'author_name': author,
      'body': text,
      if (rating != null) 'rating': rating,
    };
  }

  final String author;
  final String text;

  /// 1–5 when a person left one (D147). Null on the seeded catalogue snippets,
  /// which are a body and nothing else.
  final int? rating;
}
