import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/domain/meal_label.dart';

void main() {
  DateTime at(int hour) => DateTime(2026, 9, 7, hour);

  test('names the meal the hour is closest to', () {
    expect(mealLabel(at(2)), 'supper');
    expect(mealLabel(at(8)), 'breakfast');
    expect(mealLabel(at(12)), 'lunch');
    expect(mealLabel(at(16)), 'tea');
    expect(mealLabel(at(19)), 'dinner');
    expect(mealLabel(at(23)), 'supper');
  });
}
