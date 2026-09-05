import 'package:flutter/material.dart';

import '../domain/opening_hours.dart';
import 'dish.dart';
import 'restaurant.dart';

/// One review as the card shows it: who wrote it and what they said.
class ReviewSnippet {
  const ReviewSnippet({
    required this.author,
    required this.text,
  });

  final String author;
  final String text;
}

/// A restaurant flattened into exactly what the swipe deck paints.
///
/// Kept separate from [Restaurant] so the widgets never reach into the
/// database row shape, and so the detail route can be handed a plain payload.
class RestaurantCard {
  const RestaurantCard({
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
    required this.reviews,
    required this.imageUrls,
    this.videoUrl,
    this.hours = OpeningHours.unknown,
    this.priceFrom,
    this.isHalal,
    this.neighbourhood,
    this.dishes = const [],
  });

  /// Builds a card from a database row, dropping reviews with no body: an
  /// empty review card is worse than no review card.
  factory RestaurantCard.fromRestaurant(Restaurant restaurant) {
    final reviews = restaurant.reviews
        .where((review) => review.text.trim().isNotEmpty)
        .map(
          (review) => ReviewSnippet(author: review.author, text: review.text),
        )
        .toList();

    return RestaurantCard(
      id: restaurant.id,
      title: restaurant.name,
      tag: restaurant.tag,
      details: restaurant.details,
      color: restaurant.brandColor,
      rating: restaurant.rating,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      reviewName: reviews.isNotEmpty ? reviews.first.author : '',
      reviewText: reviews.isNotEmpty ? reviews.first.text : '',
      reviews: reviews,
      imageUrls: restaurant.imageUrls,
      videoUrl: restaurant.videoUrl,
      hours: restaurant.hours,
      priceFrom: restaurant.priceFrom,
      isHalal: restaurant.isHalal,
      neighbourhood: restaurant.neighbourhood,
      dishes: restaurant.dishes,
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
  final List<ReviewSnippet> reviews;
  final List<String> imageUrls;
  final String? videoUrl;
  final OpeningHours hours;
  final int? priceFrom;
  final bool? isHalal;
  final String? neighbourhood;
  final List<Dish> dishes;

  /// "From RM 19" — null when the caption named no price.
  String? get priceLabel =>
      priceFrom == null ? null : 'From ${formatRinggit(priceFrom!)}';
}
