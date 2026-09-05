import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../domain/json_field.dart';
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
    final hours = jsonMap(payload['hours']);
    return RestaurantDetailData(
      id: jsonInt(payload['id']) ?? 0,
      title: jsonString(payload['title']) ?? 'Restaurant',
      tag: jsonString(payload['tag']) ?? '',
      details: jsonString(payload['details']) ?? '',
      color: payload['color'] is int
          ? Color(payload['color'] as int)
          : kBrandColorFallback,
      rating: jsonDouble(payload['rating']) ?? 0,
      latitude: jsonDouble(payload['latitude']) ?? 0,
      longitude: jsonDouble(payload['longitude']) ?? 0,
      reviewName: jsonString(payload['reviewName']) ?? '',
      reviewText: jsonString(payload['reviewText']) ?? '',
      imageUrls: jsonList(payload['imageUrls'])
          .map((value) => value.toString())
          .toList(),
      videoUrl: jsonString(payload['videoUrl']),
      hours: hours == null ? OpeningHours.unknown : OpeningHours.fromJson(hours),
      priceFrom: jsonInt(payload['priceFrom']),
      isHalal: jsonBool(payload['isHalal']),
      neighbourhood: jsonString(payload['neighbourhood']),
      dishes: jsonList(payload['dishes'])
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
