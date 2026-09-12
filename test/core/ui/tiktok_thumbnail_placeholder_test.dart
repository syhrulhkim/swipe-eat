import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/tiktok_thumbnail_placeholder.dart';

void main() {
  group('tiktokCreatorHandle', () {
    test('extracts the handle from a video URL', () {
      expect(
        tiktokCreatorHandle(
          'https://www.tiktok.com/@johorfoodie/video/7670115348573621525',
        ),
        '@johorfoodie',
      );
    });

    test('supports dots and underscores in handles', () {
      expect(
        tiktokCreatorHandle('https://www.tiktok.com/@some.user_1/video/1'),
        '@some.user_1',
      );
    });

    test('returns null for a null URL', () {
      expect(tiktokCreatorHandle(null), isNull);
    });

    test('returns null when the URL has no handle', () {
      expect(tiktokCreatorHandle('https://example.com/video/123'), isNull);
    });

    test('returns null for a bare @ with no handle characters after it', () {
      expect(tiktokCreatorHandle('https://www.tiktok.com/@/video/1'), isNull);
      expect(tiktokCreatorHandle('@'), isNull);
      expect(tiktokCreatorHandle('https://www.tiktok.com/video/1@'), isNull);
    });

    test('returns null for an empty URL', () {
      expect(tiktokCreatorHandle(''), isNull);
    });

    test('extracts a handle sitting at the very start of the string', () {
      expect(tiktokCreatorHandle('@johorfoodie'), '@johorfoodie');
    });

    test('preserves handle casing', () {
      expect(
        tiktokCreatorHandle('https://www.tiktok.com/@JohorFoodie/video/1'),
        '@JohorFoodie',
      );
    });

    test('returns the first handle when the URL contains several', () {
      expect(
        tiktokCreatorHandle(
            'https://www.tiktok.com/@first/video/1?ref=@second'),
        '@first',
      );
    });

    test('stops at the first character outside the handle charset', () {
      // Hyphens are not valid in TikTok handles, so the match ends there.
      expect(
        tiktokCreatorHandle('https://www.tiktok.com/@some-user/video/1'),
        '@some',
      );
    });

    test('matches the domain part of an email-like string', () {
      // Documents current behaviour: the helper only ever receives TikTok
      // video URLs, so it does not try to reject other @-bearing strings.
      expect(tiktokCreatorHandle('mailto:chef@example.com'), '@example.com');
    });

    test('handles a very long URL without pathological behaviour', () {
      final longUrl =
          'https://www.tiktok.com/@johorfoodie/video/7670115348573621525'
          '?${'a' * 5000}=${'b' * 5000}';

      expect(tiktokCreatorHandle(longUrl), '@johorfoodie');
    });
  });

  group('TikTokThumbnailPlaceholder', () {
    testWidgets('shows the TikTok Review label and creator handle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TikTokThumbnailPlaceholder(creatorHandle: '@johorfoodie'),
        ),
      );

      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('omits the handle line when none is known', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TikTokThumbnailPlaceholder()),
      );

      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets(
        'does not overflow in a thumbnail slot shorter than its content',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              height: 50,
              width: 82,
              child: TikTokThumbnailPlaceholder(creatorHandle: '@johorfoodie'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
    });

    testWidgets('stays inside a very short AspectRatio box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              child: AspectRatio(
                aspectRatio: 1.65,
                child:
                    TikTokThumbnailPlaceholder(creatorHandle: '@a.very_long'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // getRect follows the FittedBox transform, so this checks what is
      // actually painted rather than the unscaled layout size.
      final box = tester.getRect(find.byType(TikTokThumbnailPlaceholder));
      final label = tester.getRect(find.text('TikTok Review'));
      final handle = tester.getRect(find.text('@a.very_long'));

      expect(box.height, closeTo(120 / 1.65, 0.01));
      for (final rect in [label, handle]) {
        expect(rect.top, greaterThanOrEqualTo(box.top - 0.01));
        expect(rect.bottom, lessThanOrEqualTo(box.bottom + 0.01));
        expect(rect.left, greaterThanOrEqualTo(box.left - 0.01));
        expect(rect.right, lessThanOrEqualTo(box.right + 0.01));
      }
    });

    testWidgets('renders as an Image errorBuilder fallback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              height: 200,
              width: 320,
              child: Image(
                // Not decodable image bytes, so the error path always runs.
                image: MemoryImage(Uint8List.fromList([1, 2, 3, 4])),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const TikTokThumbnailPlaceholder(
                    creatorHandle: '@johorfoodie',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TikTokThumbnailPlaceholder), findsOneWidget);
      expect(find.text('TikTok Review'), findsOneWidget);
      expect(find.text('@johorfoodie'), findsOneWidget);
    });
  });
}
