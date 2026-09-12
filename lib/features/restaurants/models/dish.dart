import '../domain/json_field.dart';

/// One thing people order at a restaurant — the "What people bite" list on
/// the detail screen.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    this.description = '',
    this.priceRm,
    this.imageUrl,
    this.position = 0,
  });

  /// Reads a row, or an entry out of a detail payload. Every field falls back
  /// rather than throwing: a dish carried in a map the app did not write is
  /// worth showing thinly, and never worth crashing the page it sits on.
  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: jsonInt(json['id']) ?? 0,
      name: jsonString(json['name']) ?? '',
      description: jsonString(json['description']) ?? '',
      priceRm: jsonDouble(json['price_rm']),
      imageUrl: jsonString(json['image_url']),
      position: jsonInt(json['position']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'price_rm': priceRm,
      'image_url': imageUrl,
      'position': position,
    };
  }

  final int id;
  final String name;
  final String description;

  /// Null when the menu does not say. The row then shows no price rather
  /// than a made-up one.
  final double? priceRm;
  final String? imageUrl;
  final int position;

  /// "RM 12" — whole ringgit when the price is whole, two decimals otherwise.
  String? get priceLabel {
    final price = priceRm;
    if (price == null) {
      return null;
    }
    return formatRinggit(price);
  }
}

/// "RM 12" for 12.0, "RM 12.50" for 12.5. One place, so every price in the
/// app is written the same way.
String formatRinggit(num amount) {
  if (amount == amount.roundToDouble()) {
    return 'RM ${amount.round()}';
  }
  return 'RM ${amount.toStringAsFixed(2)}';
}
