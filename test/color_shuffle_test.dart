import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/color_shuffle.dart';

Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(1, h, s, l).toColor();

List<Color> _many(int n) => [for (var i = 0; i < n; i++) _hsl(i * 360 / n, 0.7, 0.3 + (i % 5) * 0.1)];

void main() {
  const black = Color(0xFF000000);
  const white = Color(0xFFFFFFFF);
  const grey = Color(0xFF808080);

  test('neutrals are left out of the mapping', () {
    final out = shuffleColors([black, white, grey, _hsl(10, 0.8, 0.5)], ShuffleMode.surprise, math.Random(1));
    expect(out.containsKey(colorKey(black)), isFalse);
    expect(out.containsKey(colorKey(white)), isFalse);
    expect(out.containsKey(colorKey(grey)), isFalse);
    expect(out.length, 1);
  });

  test('only neutrals gives an empty mapping', () {
    expect(shuffleColors([black, white], ShuffleMode.classic, math.Random(1)), isEmpty);
    expect(shuffleColors(const [], ShuffleMode.classic, math.Random(1)), isEmpty);
  });

  test('the same seed gives the same palette', () {
    final colors = _many(12);
    for (final mode in ShuffleMode.values) {
      final a = shuffleColors(colors, mode, math.Random(7));
      final b = shuffleColors(colors, mode, math.Random(7));
      expect(a, b, reason: '$mode');
    }
  });

  test('equal colors stay equal, and every chromatic color is mapped', () {
    final red = _hsl(0, 0.8, 0.5);
    final blue = _hsl(220, 0.8, 0.5);
    for (final mode in ShuffleMode.values) {
      final out = shuffleColors([red, blue, red, red], mode, math.Random(3));
      expect(out.length, 2, reason: '$mode');
      expect(out[colorKey(red)], isNotNull);
      expect(out[colorKey(blue)], isNotNull);
    }
  });

  test('works from one to a hundred colors, with valid opaque results', () {
    for (final n in [1, 2, 3, 10, 100]) {
      for (final mode in ShuffleMode.values) {
        final colors = _many(n);
        final out = shuffleColors(colors, mode, math.Random(n));
        expect(out, isNotEmpty, reason: '$mode n=$n');
        for (final color in out.values) {
          expect(color.a, 1);
          for (final channel in [color.r, color.g, color.b]) {
            expect(channel, inInclusiveRange(0, 1));
          }
        }
      }
    }
  });

  test('the palette really changes', () {
    final colors = _many(6);
    final out = shuffleColors(colors, ShuffleMode.goldenAngle, math.Random(5));
    final changed = colors.where((c) => out[colorKey(c)] != null && colorKey(out[colorKey(c)]!) != colorKey(c));
    expect(changed, isNotEmpty);
  });

  test('without a mood, lightness order within the selection is kept', () {
    final dark = _hsl(200, 0.6, 0.25);
    final mid = _hsl(205, 0.6, 0.5);
    final light = _hsl(210, 0.6, 0.75);
    for (final mode in [ShuffleMode.goldenAngle, ShuffleMode.classic]) {
      final out = shuffleColors([dark, mid, light], mode, math.Random(11));
      double l(Color c) => out[colorKey(c)]!.computeLuminance();
      expect(l(dark), lessThan(l(mid)), reason: '$mode');
      expect(l(mid), lessThan(l(light)), reason: '$mode');
    }
  });
}
