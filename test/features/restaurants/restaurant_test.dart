import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/models/restaurant.dart';

void main() {
  group('Restaurant.fromJson', () {
    test('maps a full Supabase row', () {
      final restaurant = Restaurant.fromJson(_fullRow());

      expect(restaurant.id, 7);
      expect(restaurant.name, 'Kopitiam Peserai');
      expect(restaurant.tag, 'Local kopitiam');
      expect(restaurant.details, 'Kaya toast and kopi o.');
      expect(restaurant.brandColor, const Color(0xFFF6D365));
      expect(restaurant.rating, 4.5);
      expect(restaurant.latitude, 1.85);
      expect(restaurant.longitude, 102.933333);
      expect(restaurant.videoUrl, 'https://tiktok.test/v/1');
      expect(restaurant.imageUrls, ['first.jpg', 'second.jpg', 'third.jpg']);
      expect(restaurant.reviews, hasLength(2));
      expect(restaurant.reviews.first.author, 'Aisyah');
      expect(restaurant.reviews.first.text, 'Best kopi in town.');
    });

    test('coerces integer-valued numerics to double', () {
      final restaurant = Restaurant.fromJson(
        _row(rating: 4, latitude: 2, longitude: 103),
      );

      expect(restaurant.rating, 4.0);
      expect(restaurant.latitude, 2.0);
      expect(restaurant.longitude, 103.0);
    });

    group('brand_color', () {
      test('parses a leading-hash hex string', () {
        expect(
          Restaurant.fromJson(_row(brandColor: '#F6D365')).brandColor,
          const Color(0xFFF6D365),
        );
      });

      test('parses a hex string without the leading hash', () {
        expect(
          Restaurant.fromJson(_row(brandColor: 'F6D365')).brandColor,
          const Color(0xFFF6D365),
        );
      });

      test('forces full opacity on a transparent-looking hex', () {
        expect(
          Restaurant.fromJson(_row(brandColor: '#00F6D365')).brandColor,
          const Color(0xFFF6D365),
        );
      });

      test('falls back when brand_color is not valid hex', () {
        expect(
          Restaurant.fromJson(_row(brandColor: 'tomato')).brandColor,
          _fallbackBrandColor,
        );
      });

      test('falls back when brand_color is null', () {
        expect(
          Restaurant.fromJson(_row(brandColor: null)).brandColor,
          _fallbackBrandColor,
        );
      });

      test('falls back when brand_color key is absent', () {
        final row = _fullRow()..remove('brand_color');

        expect(Restaurant.fromJson(row).brandColor, _fallbackBrandColor);
      });
    });

    group('restaurant_images', () {
      test('sorts by position regardless of input order', () {
        final restaurant = Restaurant.fromJson(
          _row(
            images: [
              {'url': 'c.jpg', 'position': 3},
              {'url': 'a.jpg', 'position': 1},
              {'url': 'b.jpg', 'position': 2},
            ],
          ),
        );

        expect(restaurant.imageUrls, ['a.jpg', 'b.jpg', 'c.jpg']);
      });

      test('treats a missing position as 0', () {
        final restaurant = Restaurant.fromJson(
          _row(
            images: [
              {'url': 'positioned.jpg', 'position': 2},
              {'url': 'unpositioned.jpg'},
            ],
          ),
        );

        expect(restaurant.imageUrls, ['unpositioned.jpg', 'positioned.jpg']);
      });

      test('filters out empty and missing urls', () {
        final restaurant = Restaurant.fromJson(
          _row(
            images: [
              {'url': '', 'position': 1},
              {'url': 'kept.jpg', 'position': 2},
              {'position': 3},
            ],
          ),
        );

        expect(restaurant.imageUrls, ['kept.jpg']);
      });

      test('yields an empty list for an empty array', () {
        expect(Restaurant.fromJson(_row(images: [])).imageUrls, isEmpty);
      });

      test('yields an empty list when the key is absent', () {
        final row = _fullRow()..remove('restaurant_images');

        expect(Restaurant.fromJson(row).imageUrls, isEmpty);
      });

      test('yields an empty list when the value is null', () {
        expect(Restaurant.fromJson(_row(images: null)).imageUrls, isEmpty);
      });

      test('does not reorder the caller\'s payload in place', () {
        final row = _fullRow();
        final payload = row['restaurant_images'] as List<dynamic>;

        Restaurant.fromJson(row);

        expect(
          payload.map((image) => (image as Map)['url']),
          ['third.jpg', 'first.jpg', 'second.jpg'],
        );
      });
    });

    group('reviews', () {
      test('yields an empty list for an empty array', () {
        expect(Restaurant.fromJson(_row(reviews: [])).reviews, isEmpty);
      });

      test('yields an empty list when the key is absent', () {
        final row = _fullRow()..remove('reviews');

        expect(Restaurant.fromJson(row).reviews, isEmpty);
      });

      test('yields an empty list when the value is null', () {
        expect(Restaurant.fromJson(_row(reviews: null)).reviews, isEmpty);
      });
    });

    group('missing and null scalars', () {
      test('falls back to defaults when nullable columns are null', () {
        final restaurant = Restaurant.fromJson(<String, dynamic>{
          'id': 1,
          'name': null,
          'tag': null,
          'details': null,
          'brand_color': null,
          'rating': null,
          'latitude': null,
          'longitude': null,
          'video_url': null,
          'restaurant_images': null,
          'reviews': null,
        });

        expect(restaurant.name, 'Restaurant');
        expect(restaurant.tag, '');
        expect(restaurant.details, '');
        expect(restaurant.brandColor, _fallbackBrandColor);
        expect(restaurant.rating, 0);
        expect(restaurant.latitude, 0);
        expect(restaurant.longitude, 0);
        expect(restaurant.videoUrl, isNull);
        expect(restaurant.imageUrls, isEmpty);
        expect(restaurant.reviews, isEmpty);
      });

      test('falls back to defaults on an id-only row', () {
        final restaurant = Restaurant.fromJson(<String, dynamic>{'id': 42});

        expect(restaurant.id, 42);
        expect(restaurant.name, 'Restaurant');
        expect(restaurant.tag, '');
        expect(restaurant.details, '');
        expect(restaurant.brandColor, _fallbackBrandColor);
        expect(restaurant.rating, 0);
        expect(restaurant.latitude, 0);
        expect(restaurant.longitude, 0);
        expect(restaurant.videoUrl, isNull);
        expect(restaurant.imageUrls, isEmpty);
        expect(restaurant.reviews, isEmpty);
      });

      test('video_url stays null when null or absent', () {
        expect(Restaurant.fromJson(_row(videoUrl: null)).videoUrl, isNull);

        final row = _fullRow()..remove('video_url');
        expect(Restaurant.fromJson(row).videoUrl, isNull);
      });
    });
  });

  group('RestaurantReview.fromJson', () {
    test('maps author_name and body', () {
      final review = RestaurantReview.fromJson(<String, dynamic>{
        'author_name': 'Hakim',
        'body': 'Portions are generous.',
      });

      expect(review.author, 'Hakim');
      expect(review.text, 'Portions are generous.');
    });

    test('defaults a null author to Reviewer and a null body to empty', () {
      final review = RestaurantReview.fromJson(<String, dynamic>{
        'author_name': null,
        'body': null,
      });

      expect(review.author, 'Reviewer');
      expect(review.text, '');
    });

    test('defaults when both keys are absent', () {
      final review = RestaurantReview.fromJson(<String, dynamic>{});

      expect(review.author, 'Reviewer');
      expect(review.text, '');
    });
  });
}

const _fallbackBrandColor = Color(0xFF141922);

Map<String, dynamic> _fullRow() {
  return <String, dynamic>{
    'id': 7,
    'name': 'Kopitiam Peserai',
    'tag': 'Local kopitiam',
    'details': 'Kaya toast and kopi o.',
    'brand_color': '#F6D365',
    'rating': 4.5,
    'latitude': 1.85,
    'longitude': 102.933333,
    'video_url': 'https://tiktok.test/v/1',
    'restaurant_images': <Map<String, dynamic>>[
      {'url': 'third.jpg', 'position': 3},
      {'url': 'first.jpg', 'position': 1},
      {'url': 'second.jpg', 'position': 2},
    ],
    'reviews': <Map<String, dynamic>>[
      {'author_name': 'Aisyah', 'body': 'Best kopi in town.'},
      {'author_name': 'Wei Ling', 'body': 'Cheap and quick.'},
    ],
  };
}

Map<String, dynamic> _row({
  Object? brandColor = '#F6D365',
  Object? rating = 4.5,
  Object? latitude = 1.85,
  Object? longitude = 102.933333,
  Object? videoUrl = 'https://tiktok.test/v/1',
  Object? images = _unset,
  Object? reviews = _unset,
}) {
  return _fullRow()
    ..['brand_color'] = brandColor
    ..['rating'] = rating
    ..['latitude'] = latitude
    ..['longitude'] = longitude
    ..['video_url'] = videoUrl
    ..['restaurant_images'] =
        images == _unset ? _fullRow()['restaurant_images'] : images
    ..['reviews'] = reviews == _unset ? _fullRow()['reviews'] : reviews;
}

const _unset = Object();
