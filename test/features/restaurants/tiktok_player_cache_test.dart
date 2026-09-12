import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/features/restaurants/data/tiktok_player_factory.dart';
import 'package:swipe_eat/features/restaurants/state/tiktok_player_cache.dart';

/// Counts the players asked for, and hands back a future that never completes.
///
/// A real [TikTokPlayerHandle] needs a `WebViewController`, which needs a
/// platform view. Nothing in this file waits on a player, so a pending future
/// is a whole player as far as the cache is concerned — the same trick
/// `swipe_card_test.dart` uses.
class _Counter {
  final List<String> asked = <String>[];

  Future<TikTokPlayerHandle> create(String videoUrl) {
    asked.add(videoUrl);
    return Completer<TikTokPlayerHandle>().future;
  }
}

void main() {
  late _Counter counter;
  late TikTokPlayerCache cache;

  setUp(() {
    counter = _Counter();
    cache = TikTokPlayerCache(createPlayer: counter.create);
  });

  test('the same clip is only ever built once', () {
    final first = cache.warm('a');
    final second = cache.warm('a');

    expect(counter.asked, ['a']);
    expect(cache.length, 1);
    expect(identical(first, second), isTrue);
  });

  test('a card with no clip warms nothing', () {
    expect(cache.warm(null), isNull);
    expect(cache.warm(''), isNull);

    expect(counter.asked, isEmpty);
    expect(cache.length, 0);
  });

  test('the sixth player pushes the first one out', () {
    for (final url in ['a', 'b', 'c', 'd', 'e']) {
      cache.warm(url);
    }
    expect(cache.length, 5);

    cache.warm('f');

    expect(cache.length, 5);
    expect(cache.peek('a'), isNull);
    expect(cache.peek('b'), isNotNull);
    expect(cache.peek('f'), isNotNull);
  });

  test('the player being watched is never the one evicted (D39, D40)', () {
    for (final url in ['a', 'b', 'c', 'd', 'e']) {
      cache.warm(url);
    }

    // What the deck does on every build for the card on screen.
    cache.warm('a');
    cache.warm('f');

    expect(cache.peek('a'), isNotNull);
    expect(cache.peek('b'), isNull);
    expect(counter.asked, ['a', 'b', 'c', 'd', 'e', 'f']);
  });

  test('peeking at a card on its way out is not a use', () {
    for (final url in ['a', 'b', 'c', 'd', 'e']) {
      cache.warm(url);
    }

    // If peek counted, 'a' would move to the front and 'b' would go instead.
    expect(cache.peek('a'), isNotNull);
    cache.warm('f');

    expect(cache.peek('a'), isNull);
    expect(cache.peek('b'), isNotNull);
  });

  test('peek starts nothing', () {
    expect(cache.peek('a'), isNull);
    expect(cache.peek(null), isNull);

    expect(counter.asked, isEmpty);
    expect(cache.length, 0);
  });

  test('clear empties the cache, and warming after it starts over', () {
    cache.warm('a');
    cache.warm('b');

    cache.clear();

    expect(cache.length, 0);
    expect(cache.peek('a'), isNull);

    cache.warm('a');
    expect(counter.asked, ['a', 'b', 'a']);
  });
}
