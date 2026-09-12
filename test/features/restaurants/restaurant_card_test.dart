import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/models/dish.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_card.dart';

/// A row with every fact the captions now carry.
Map<String, dynamic> _row() {
  return <String, dynamic>{
    'id': 7,
    'name': 'Ikan Bakar Medan',
    'tag': 'Seafood',
    'details': 'Charcoal-grilled.',
    'brand_color': '#F6D365',
    'rating': 4.6,
    'latitude': 3.16,
    'longitude': 101.7,
    'video_url': 'https://tiktok.test/v/1',
    'opens_at': '17:30:00',
    'closes_at': '02:00:00',
    'closed_dow': [1],
    'hours_text': '5:30PM - 2AM (Closed on Monday)',
    'price_from': 19,
    'is_halal': true,
    'neighbourhood': 'Kampung Baru',
    'dishes': <Map<String, dynamic>>[
      {'id': 2, 'name': 'Ikan pari', 'price_rm': 25, 'position': 2},
      {'id': 1, 'name': 'Sotong goreng', 'price_rm': 12.5, 'position': 1},
    ],
    'restaurant_images': <Map<String, dynamic>>[
      {'url': 'first.jpg', 'position': 1},
      {'url': 'second.jpg', 'position': 2},
    ],
    'reviews': <Map<String, dynamic>>[
      {'author_name': 'Aisyah', 'body': 'Sambal is the point.'},
    ],
  };
}

void main() {
  group('RestaurantCard.fromRestaurant', () {
    test('carries what the deck paints', () {
      final card = RestaurantCard.fromRestaurant(Restaurant.fromJson(_row()));

      expect(card.id, 7);
      expect(card.title, 'Ikan Bakar Medan');
      expect(card.tag, 'Seafood');
      expect(card.details, 'Charcoal-grilled.');
      expect(card.color, const Color(0xFFF6D365));
      expect(card.rating, 4.6);
      expect(card.latitude, 3.16);
      expect(card.longitude, 101.7);
      expect(card.imageUrls, ['first.jpg', 'second.jpg']);
      expect(card.videoUrl, 'https://tiktok.test/v/1');
    });

    test('carries the facts the captions now read', () {
      final card = RestaurantCard.fromRestaurant(Restaurant.fromJson(_row()));

      expect(card.hours.opensAtMinutes, 17 * 60 + 30);
      expect(card.hours.closesAtMinutes, 2 * 60);
      expect(card.hours.closedWeekdays, {DateTime.monday});
      expect(card.hours.text, '5:30PM - 2AM (Closed on Monday)');
      expect(card.priceFrom, 19);
      expect(card.isHalal, isTrue);
      expect(card.neighbourhood, 'Kampung Baru');
      // Menu order, as the row was sorted — not the order it arrived in.
      expect(
          card.dishes.map((dish) => dish.name), ['Sotong goreng', 'Ikan pari']);
    });

    test('says nothing the row did not', () {
      final card = RestaurantCard.fromRestaurant(
        Restaurant.fromJson(<String, dynamic>{'id': 1}),
      );

      expect(card.hours.isKnown, isFalse);
      expect(card.hours.isOpenAt(DateTime(2026, 9, 7, 20)), isNull);
      expect(card.priceFrom, isNull);
      expect(card.priceLabel, isNull);
      expect(card.isHalal, isNull);
      expect(card.neighbourhood, isNull);
      expect(card.dishes, isEmpty);
    });

    test('an explicit "not halal" is not the same as "does not say"', () {
      final card = RestaurantCard.fromRestaurant(
        Restaurant.fromJson(_row()..['is_halal'] = false),
      );

      expect(card.isHalal, isFalse);
      expect(card.isHalal, isNotNull);
    });

    test('drops reviews with no body and keeps the first as the headline', () {
      final card = RestaurantCard.fromRestaurant(
        Restaurant.fromJson(
          _row()
            ..['reviews'] = <Map<String, dynamic>>[
              {'author_name': 'Empty', 'body': '   '},
              {'author_name': 'Aisyah', 'body': 'Sambal is the point.'},
              {'author_name': 'Ben', 'body': 'Queue moves fast.'},
            ],
        ),
      );

      expect(card.reviews.map((review) => review.author), ['Aisyah', 'Ben']);
      expect(card.reviewName, 'Aisyah');
      expect(card.reviewText, 'Sambal is the point.');
    });

    test('a restaurant with no usable review has no headline review', () {
      final card = RestaurantCard.fromRestaurant(
        Restaurant.fromJson(_row()..['reviews'] = const <dynamic>[]),
      );

      expect(card.reviews, isEmpty);
      expect(card.reviewName, isEmpty);
      expect(card.reviewText, isEmpty);
    });
  });

  group('priceLabel', () {
    test('writes the ringgit the design shows', () {
      expect(_cardWithPrice(19).priceLabel, 'From RM 19');
      expect(_cardWithPrice(1200).priceLabel, 'From RM 1200');
      expect(_cardWithPrice(0).priceLabel, 'From RM 0');
      expect(_cardWithPrice(null).priceLabel, isNull);
    });

    test('a dish writes its own price the same way', () {
      expect(const Dish(id: 1, name: 'a', priceRm: 12).priceLabel, 'RM 12');
      expect(
          const Dish(id: 1, name: 'a', priceRm: 12.5).priceLabel, 'RM 12.50');
      expect(const Dish(id: 1, name: 'a').priceLabel, isNull);
    });
  });
}

RestaurantCard _cardWithPrice(int? priceFrom) {
  return RestaurantCard(
    id: 1,
    title: 'Warung',
    tag: '',
    details: '',
    color: kBrandColorFallback,
    rating: 0,
    latitude: 0,
    longitude: 0,
    reviewName: '',
    reviewText: '',
    reviews: const [],
    imageUrls: const [],
    priceFrom: priceFrom,
  );
}
