import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/hex_color.dart';

void main() {
  group('parseHexColor', () {
    test('parses a leading-hash 6-digit hex', () {
      expect(parseHexColor('#F6D365'), const Color(0xFFF6D365));
    });

    test('parses a bare 6-digit hex', () {
      expect(parseHexColor('F6D365'), const Color(0xFFF6D365));
    });

    test('is case insensitive', () {
      expect(parseHexColor('#f6d365'), parseHexColor('#F6D365'));
    });

    test('forces full opacity on an 8-digit hex', () {
      // The implementation ORs 0xFF000000, so any alpha byte is discarded.
      expect(parseHexColor('#00F6D365'), const Color(0xFFF6D365));
      expect(parseHexColor('80F6D365'), const Color(0xFFF6D365));
      expect(parseHexColor('#FFF6D365'), const Color(0xFFF6D365));
    });

    test('returns the default fallback for null', () {
      expect(parseHexColor(null), _defaultFallback);
    });

    test('returns the caller fallback for null', () {
      expect(
        parseHexColor(null, fallback: const Color(0xFFB7E4C7)),
        const Color(0xFFB7E4C7),
      );
    });

    group('falls back on the wrong number of digits', () {
      for (final hex in <String>[
        '',
        '#',
        'F',
        '#FFF',
        'F6D36',
        '#F6D3655',
        'F6D365FFF',
      ]) {
        test('"$hex"', () {
          expect(
            parseHexColor(hex, fallback: const Color(0xFFB7E4C7)),
            const Color(0xFFB7E4C7),
            reason: '"$hex" has ${hex.replaceFirst('#', '').length} digits',
          );
        });
      }
    });

    group('falls back on non-hex digits', () {
      for (final hex in <String>[
        'tomato',
        '#tomato',
        'GGGGGG',
        '#F6D36Z',
        'rgb(1)',
      ]) {
        test('"$hex"', () {
          expect(
            parseHexColor(hex, fallback: const Color(0xFFB7E4C7)),
            const Color(0xFFB7E4C7),
          );
        });
      }
    });

    group('rejects the shapes int.tryParse would otherwise accept', () {
      // int.tryParse('  F6D3', radix: 16) == 0xF6D3 and
      // int.tryParse('-F6D36', radix: 16) == -0xF6D36, so a length-only guard
      // would turn these into a wrong colour instead of the fallback.
      for (final hex in <String>['  F6D3', '\tF6D3\n', '-F6D36', '+F6D36']) {
        test('"${hex.replaceAll('\t', r'\t').replaceAll('\n', r'\n')}"', () {
          expect(
            parseHexColor(hex, fallback: const Color(0xFFB7E4C7)),
            const Color(0xFFB7E4C7),
          );
        });
      }
    });

    test('ignores whitespace around a well-formed hex', () {
      expect(parseHexColor('  #F6D365  '), const Color(0xFFF6D365));
      expect(parseHexColor('\nF6D365\t'), const Color(0xFFF6D365));
    });

    test('only strips the first hash', () {
      expect(parseHexColor('##F6D365'), _defaultFallback);
    });

    test('parses the extremes', () {
      expect(parseHexColor('#000000'), const Color(0xFF000000));
      expect(parseHexColor('#FFFFFF'), const Color(0xFFFFFFFF));
    });
  });
}

const _defaultFallback = Color(0xFF141922);
