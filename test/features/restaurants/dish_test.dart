import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/models/dish.dart';

void main() {
  test('Dish.fromJson maps a row and round-trips', () {
    final dish = Dish.fromJson({
      'id': 4,
      'name': 'Sambal sotong',
      'description': 'Squid in sweet-hot sambal',
      'price_rm': 15,
      'image_url': 'https://cdn/x.jpg',
      'position': 2,
    });
    expect(dish.name, 'Sambal sotong');
    expect(dish.priceRm, 15);
    expect(dish.priceLabel, 'RM 15');
    expect(Dish.fromJson(dish.toJson()).priceLabel, 'RM 15');
  });

  test('a dish with no price has no price label', () {
    expect(Dish.fromJson({'id': 1, 'name': 'Teh tarik'}).priceLabel, isNull);
  });

  test('formatRinggit keeps cents only when there are some', () {
    expect(formatRinggit(12), 'RM 12');
    expect(formatRinggit(12.0), 'RM 12');
    expect(formatRinggit(12.5), 'RM 12.50');
  });
}
