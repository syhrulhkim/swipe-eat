import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../domain/opening_hours.dart';
import 'dish.dart';
import 'restaurant.dart';
import 'restaurant_card.dart';

/// What the detail page needs to paint one restaurant.
///
/// It travels as a plain map through the router's `extra`, so every field has
/// a defensive default: a malformed payload should degrade to a thin page, not
/// crash on the way to it.
class RestaurantDetailData {
  const RestaurantDetailData({
    required this.id,
    required this.title,
    required this.tag,
    required this.details,
    required this.color,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.reviewName,
    required this.reviewText,
    required this.imageUrls,
    this.videoUrl,
    this.hours = OpeningHours.unknown,
    this.priceFrom,
    this.isHalal,
    this.neighbourhood,
    this.dishes = const [],
  });

  factory RestaurantDetailData.fromPayload(Map<String, dynamic> payload) {
    return RestaurantDetailData(
      id: (payload['id'] as num?)?.toInt() ?? 0,
      title: payload['title'] as String? ?? 'Restaurant',
      tag: payload['tag'] as String? ?? '',
      details: payload['details'] as String? ?? '',
      color: payload['color'] is int
          ? Color(payload['color'] as int)
          : kBrandColorFallback,
      rating: (payload['rating'] as num?)?.toDouble() ?? 0,
      latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
      reviewName: payload['reviewName'] as String? ?? '',
      reviewText: payload['reviewText'] as String? ?? '',
      imageUrls: (payload['imageUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      videoUrl: payload['videoUrl'] as String?,
      hours: payload['hours'] is Map<String, dynamic>
          ? OpeningHours.fromJson(payload['hours'] as Map<String, dynamic>)
          : OpeningHours.unknown,
      priceFrom: (payload['priceFrom'] as num?)?.toInt(),
      isHalal: payload['isHalal'] as bool?,
      neighbourhood: payload['neighbourhood'] as String?,
      dishes: (payload['dishes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Dish.fromJson)
          .toList(),
    );
  }

  /// Straight from a database row, for the page opened by id rather than
  /// handed a payload.
  factory RestaurantDetailData.fromRestaurant(Restaurant restaurant) {
    final card = RestaurantCard.fromRestaurant(restaurant);
    return RestaurantDetailData(
      id: card.id,
      title: card.title,
      tag: card.tag,
      details: card.details,
      color: card.color,
      rating: card.rating,
      latitude: card.latitude,
      longitude: card.longitude,
      reviewName: card.reviewName,
      reviewText: card.reviewText,
      imageUrls: card.imageUrls,
      videoUrl: card.videoUrl,
      hours: card.hours,
      priceFrom: card.priceFrom,
      isHalal: card.isHalal,
      neighbourhood: card.neighbourhood,
      dishes: card.dishes,
    );
  }

  final int id;
  final String title;
  final String tag;
  final String details;
  final Color color;
  final double rating;
  final double latitude;
  final double longitude;
  final String reviewName;
  final String reviewText;
  final List<String> imageUrls;
  final String? videoUrl;
  final OpeningHours hours;
  final int? priceFrom;
  final bool? isHalal;
  final String? neighbourhood;
  final List<Dish> dishes;

  String? get priceLabel =>
      priceFrom == null ? null : 'From ${formatRinggit(priceFrom!)}';
}

extension RestaurantCardDetailPayload on RestaurantCard {
  /// The card as the router's `extra` map, so the detail page opens with the
  /// content already on screen instead of refetching it.
  Map<String, dynamic> toDetailPayload() {
    return {
      'id': id,
      'title': title,
      'tag': tag,
      'details': details,
      'color': color.toARGB32(),
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'reviewName': reviewName,
      'reviewText': reviewText,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'hours': hours.toJson(),
      'priceFrom': priceFrom,
      'isHalal': isHalal,
      'neighbourhood': neighbourhood,
      'dishes': dishes.map((dish) => dish.toJson()).toList(),
    };
  }
}
