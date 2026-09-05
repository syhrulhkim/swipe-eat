import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/restaurants/domain/opening_hours.dart';
import 'package:swipe_eat/features/restaurants/models/dish.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_card.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant_detail_data.dart';

/// A card carrying every fact the commit added, so the round-trip below has
/// something to lose.
RestaurantCard _card() {
  return const RestaurantCard(
    id: 12,
    title: 'Ikan Bakar Medan',
    tag: 'Seafood',
    details: 'Charcoal-grilled, sambal on the side.',
    color: kBrandColorFallback,
    rating: 4.6,
    latitude: 3.16,
    longitude: 101.7,
    reviewName: 'Ben',
    reviewText: 'Worth the queue.',
    reviews: [ReviewSnippet(author: 'Ben', text: 'Worth the queue.')],
    imageUrls: ['https://example.com/a.jpg'],
    videoUrl: 'https://tiktok.test/v/1',
    hours: OpeningHours(
      opensAtMinutes: 17 * 60 + 30,
      closesAtMinutes: 2 * 60,
      closedWeekdays: {DateTime.monday},
      text: '5:30PM - 2AM (Closed on Monday)',
    ),
    priceFrom: 19,
    isHalal: true,
    neighbourhood: 'Kampung Baru',
    dishes: [
      Dish(id: 2, name: 'Ikan pari', priceRm: 25, position: 1),
      Dish(id: 1, name: 'Sotong goreng', priceRm: 12.5),
    ],
  );
}

void main() {
  group('toDetailPayload → fromPayload', () {
    test('carries the facts the card was dealt', () {
      final data = RestaurantDetailData.fromPayload(_card().toDetailPayload());

      expect(data.id, 12);
      expect(data.title, 'Ikan Bakar Medan');
      expect(data.tag, 'Seafood');
      expect(data.details, 'Charcoal-grilled, sambal on the side.');
      expect(data.color, kBrandColorFallback);
      expect(data.rating, 4.6);
      expect(data.latitude, 3.16);
      expect(data.longitude, 101.7);
      expect(data.reviewName, 'Ben');
      expect(data.reviewText, 'Worth the queue.');
      expect(data.imageUrls, ['https://example.com/a.jpg']);
      expect(data.videoUrl, 'https://tiktok.test/v/1');
    });

    test('carries the hours, price, halal and neighbourhood', () {
      final data = RestaurantDetailData.fromPayload(_card().toDetailPayload());

      expect(data.hours.opensAtMinutes, 17 * 60 + 30);
      expect(data.hours.closesAtMinutes, 2 * 60);
      expect(data.hours.closedWeekdays, {DateTime.monday});
      expect(data.hours.text, '5:30PM - 2AM (Closed on Monday)');
      expect(data.hours.isOvernight, isTrue);
      expect(data.priceFrom, 19);
      expect(data.priceLabel, 'From RM 19');
      expect(data.isHalal, isTrue);
      expect(data.neighbourhood, 'Kampung Baru');
    });

    test('carries the dishes, in the order the card held them', () {
      final data = RestaurantDetailData.fromPayload(_card().toDetailPayload());

      expect(data.dishes.map((dish) => dish.name), ['Ikan pari', 'Sotong goreng']);
      expect(data.dishes.first.id, 2);
      expect(data.dishes.first.position, 1);
      expect(data.dishes.first.priceLabel, 'RM 25');
      expect(data.dishes.last.priceLabel, 'RM 12.50');
    });

    test('survives being written and read as JSON', () {
      // go_router hands the map straight over today, but a payload that has
      // been through a string is the same payload — nothing in it may be a
      // type only Dart knows about.
      final encoded = jsonEncode(_card().toDetailPayload());
      final data = RestaurantDetailData.fromPayload(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(data.hours.closedWeekdays, {DateTime.monday});
      expect(data.dishes.map((dish) => dish.name), ['Ikan pari', 'Sotong goreng']);
      expect(data.priceFrom, 19);
      expect(data.isHalal, isTrue);
    });

    test('a card that knows nothing round-trips to a card that knows nothing',
        () {
      const bare = RestaurantCard(
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
        reviews: [],
        imageUrls: [],
      );
      final data = RestaurantDetailData.fromPayload(bare.toDetailPayload());

      expect(data.hours.isKnown, isFalse);
      expect(data.priceFrom, isNull);
      expect(data.priceLabel, isNull);
      expect(data.isHalal, isNull);
      expect(data.neighbourhood, isNull);
      expect(data.dishes, isEmpty);
    });
  });

  group('fromPayload degrades instead of throwing', () {
    test('hours that are not a map', () {
      final data =
          RestaurantDetailData.fromPayload(const {'hours': 'every day'});

      expect(data.hours.isKnown, isFalse);
      expect(data.hours.text, isNull);
    });

    test('hours that are a map of junk', () {
      final data = RestaurantDetailData.fromPayload(const {
        'hours': <String, dynamic>{
          'opens_at': 930,
          'closes_at': <String>['20:00:00'],
          'closed_dow': 'Mondays',
          'hours_text': 7,
        },
      });

      expect(data.hours.isKnown, isFalse);
      expect(data.hours.closedWeekdays, isEmpty);
      expect(data.hours.text, isNull);
    });

    test('dishes that are not a list', () {
      final data =
          RestaurantDetailData.fromPayload(const {'dishes': 'nasi lemak'});

      expect(data.dishes, isEmpty);
    });

    test('dishes holding things that are not dishes', () {
      final data = RestaurantDetailData.fromPayload(const {
        'dishes': <dynamic>[
          'nasi lemak',
          7,
          null,
          <String, dynamic>{'id': 3, 'name': 'Roti canai'},
        ],
      });

      expect(data.dishes.single.name, 'Roti canai');
    });

    test('a dish map whose every value is the wrong type', () {
      final data = RestaurantDetailData.fromPayload(const {
        'dishes': <dynamic>[
          <String, dynamic>{
            'id': 'three',
            'name': 7,
            'description': false,
            'price_rm': 'twelve',
            'image_url': 42,
            'position': 'first',
          },
        ],
      });

      final dish = data.dishes.single;
      expect(dish.id, 0);
      expect(dish.name, isEmpty);
      expect(dish.description, isEmpty);
      expect(dish.priceRm, isNull);
      expect(dish.priceLabel, isNull);
      expect(dish.imageUrl, isNull);
      expect(dish.position, 0);
    });

    test('imageUrls that are not a list', () {
      final data =
          RestaurantDetailData.fromPayload(const {'imageUrls': 'a.jpg'});

      expect(data.imageUrls, isEmpty);
    });

    test('scalars of the wrong type', () {
      final data = RestaurantDetailData.fromPayload(const {
        'id': 'twelve',
        'title': 7,
        'tag': 1,
        'details': false,
        'color': '#FF0000',
        'rating': 'good',
        'latitude': 'north',
        'longitude': 'east',
        'reviewName': 3,
        'reviewText': 3,
        'videoUrl': 9,
        'priceFrom': '19',
        'isHalal': 'yes',
        'neighbourhood': 4,
      });

      expect(data.id, 0);
      expect(data.title, 'Restaurant');
      expect(data.tag, isEmpty);
      expect(data.details, isEmpty);
      expect(data.color, kBrandColorFallback);
      expect(data.rating, 0);
      expect(data.latitude, 0);
      expect(data.longitude, 0);
      expect(data.reviewName, isEmpty);
      expect(data.reviewText, isEmpty);
      expect(data.videoUrl, isNull);
      expect(data.priceFrom, isNull);
      expect(data.isHalal, isNull);
      expect(data.neighbourhood, isNull);
    });
  });
}
