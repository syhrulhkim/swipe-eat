import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/features/profile/models/autoplay_setting.dart';
import 'package:swipe_eat/features/profile/state/autoplay_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('AutoplaySetting', () {
    test('always plays on anything, never plays on nothing', () {
      expect(AutoplaySetting.always.playsOn(wifi: false), isTrue);
      expect(AutoplaySetting.never.playsOn(wifi: true), isFalse);
    });

    test('wifi only asks the connection', () {
      expect(AutoplaySetting.wifiOnly.playsOn(wifi: true), isTrue);
      expect(AutoplaySetting.wifiOnly.playsOn(wifi: false), isFalse);
    });

    test('an unknown slug reads as the default, not as off', () {
      // A setting that silently turned itself off after a rename would be a
      // video app that stopped playing video.
      expect(AutoplaySetting.fromSlug('whatever'), AutoplaySetting.always);
      expect(AutoplaySetting.fromSlug(null), AutoplaySetting.always);
    });
  });

  group('AutoplayController', () {
    test('defaults to always, and remembers a choice', () async {
      final controller = AutoplayController(wifi: Stream<bool>.empty);
      await controller.ensureLoaded();

      expect(controller.setting, AutoplaySetting.always);
      expect(controller.playsNow, isTrue);

      await controller.select(AutoplaySetting.never);
      expect(controller.playsNow, isFalse);
      controller.dispose();

      final second = AutoplayController(wifi: Stream<bool>.empty);
      await second.ensureLoaded();
      expect(second.setting, AutoplaySetting.never);
      second.dispose();
    });

    test('wifi-only follows the connection, and says so', () async {
      final wifi = StreamController<bool>.broadcast();
      final controller = AutoplayController(
        wifi: () => wifi.stream,
        initialWifi: false,
      );
      await controller.ensureLoaded();
      await controller.select(AutoplaySetting.wifiOnly);

      expect(controller.playsNow, isFalse, reason: 'started on mobile data');

      var notifications = 0;
      controller.addListener(() => notifications += 1);
      wifi.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(controller.playsNow, isTrue);
      expect(notifications, 1);

      controller.dispose();
      await wifi.close();
    });

    test('a connection change is silent for the other two settings', () async {
      final wifi = StreamController<bool>.broadcast();
      final controller = AutoplayController(
        wifi: () => wifi.stream,
        initialWifi: false,
      );
      await controller.ensureLoaded();

      var notifications = 0;
      controller.addListener(() => notifications += 1);
      wifi.add(true);
      await Future<void>.delayed(Duration.zero);

      // Always plays either way, so a rebuild would repaint the same deck.
      expect(notifications, 0);
      expect(controller.playsNow, isTrue);

      controller.dispose();
      await wifi.close();
    });
  });
}
