import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/data/tiktok_player_factory.dart';
import 'package:swipe_eat/features/restaurants/presentation/tiktok_player.dart';

void main() {
  group('tikTokPlayerUrl', () {
    const share = 'https://www.tiktok.com/@warung/video/7391234567890123456';

    test('never locks the volume, so the sound can be turned on (D122)', () {
      final url = tikTokPlayerUrl(share);

      // `muted=1` is not "start silent" — TikTok's docs define it as pinning
      // the volume at 0 *and* refusing every later unmute, which is what made
      // "Tap for sound" do nothing. Silence at the start is D89's job, and
      // the handle posts `mute` for it once the page is up.
      expect(url.query, contains('muted=0'));
      expect(url.query, contains('volume_control=1'));
      expect(url.query, contains('autoplay=1'));
      expect(url.path, endsWith('7391234567890123456'));
    });

    test('a url with no video id is left alone', () {
      expect(
        tikTokPlayerUrl('https://tiktok.test/nope').toString(),
        'https://tiktok.test/nope',
      );
    });
  });

  group('isTikTokPlayerNavigation', () {
    // The player carries links out to the app, the creator's profile and ads.
    // Whatever the page asks for, only TikTok's own hosts — plus the blank
    // page an evicted player is parked on — may be followed.
    const allowed = <String, bool>{
      'https://www.tiktok.com/x': true,
      'https://evil.com': false,
      'http://tiktok.com.evil.com': false,
      'about:blank': true,
      'javascript:alert(1)': false,
      'not a url': false,
    };

    test('follows TikTok and the blank page, and nothing else', () {
      allowed.forEach((url, mayFollow) {
        expect(isTikTokPlayerNavigation(url), mayFollow, reason: url);
      });
    });

    test('a subdomain is TikTok, a suffix of the name is not', () {
      expect(isTikTokPlayerNavigation('https://TikTok.com/@warung'), isTrue);
      expect(isTikTokPlayerNavigation('https://m.tiktok.com/v/1'), isTrue);
      expect(isTikTokPlayerNavigation('https://nottiktok.com/v/1'), isFalse);
    });
  });

  group('tikTokFramingScale', () {
    // A phone-sized card: 360 x 620, a touch wider than 9:16.
    const card = BoxConstraints.tightFor(width: 360, height: 620);

    test('a card leaves no letterbox, nudge included', () {
      final scale = tikTokFramingScale(card, TikTokFraming.card);

      // The clip fits to 348.75 x 620 inside the card, so covering the width
      // takes 1.032 — but the 7% nudge needs 1.14, and the larger wins.
      expect(scale, closeTo(1.14, 0.001));

      // Whatever the box, the scaled clip covers it in both directions after
      // the nudge.
      const clipAspect = 9 / 16;
      for (final size in const [
        Size(360, 620),
        Size(390, 844),
        Size(300, 300),
        Size(500, 400),
      ]) {
        final s = tikTokFramingScale(
          BoxConstraints.tightFor(width: size.width, height: size.height),
          TikTokFraming.card,
        );
        final fittedWidth = size.width < size.height * clipAspect
            ? size.width
            : size.height * clipAspect;
        final fittedHeight = size.height < size.width / clipAspect
            ? size.height
            : size.width / clipAspect;

        expect(fittedWidth * s, greaterThanOrEqualTo(size.width - 0.001),
            reason: 'covers the width of $size');
        expect(fittedHeight * s,
            greaterThanOrEqualTo((size.height * 1.14) - 0.001),
            reason: 'covers $size plus the nudge at both ends');
      }
    });

    test('the hero and the fullscreen route keep the old hand-picked scale',
        () {
      expect(tikTokFramingScale(card, TikTokFraming.hero), 1.03);
      expect(tikTokFramingScale(card, TikTokFraming.fullscreen), 1.03);
    });

    test('a box with no size does not divide by zero', () {
      expect(
        tikTokFramingScale(
          const BoxConstraints.tightFor(width: 0, height: 0),
          TikTokFraming.card,
        ),
        1.03,
      );
    });
  });
}
