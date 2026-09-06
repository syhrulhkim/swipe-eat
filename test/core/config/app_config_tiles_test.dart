import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/config/app_config.dart';

void main() {
  group('AppConfig map tiles', () {
    test('a build with no defines points at OSM and says so', () {
      // The whole point of the flag: a build nobody configured must be
      // detectable as "not shippable" rather than quietly shipping on a tile
      // server whose usage policy forbids released apps.
      expect(
        AppConfig.mapTileUrlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(AppConfig.mapTileAttribution, '© OpenStreetMap');
      expect(AppConfig.usesDevelopmentTiles, isTrue);
    });

    test('the template carries the three tile placeholders', () {
      for (final placeholder in ['{z}', '{x}', '{y}']) {
        expect(AppConfig.mapTileUrlTemplate, contains(placeholder));
      }
    });

    test('the credit is never empty', () {
      // Every tile host requires attribution; an empty string would be a
      // licence breach drawn as blank space.
      expect(AppConfig.mapTileAttribution.trim(), isNotEmpty);
    });
  });
}
