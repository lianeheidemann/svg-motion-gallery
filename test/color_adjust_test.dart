import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/color_adjust.dart';

void main() {
  const blue = Color(0xFF3B82F6);

  test('zero changes nothing and every adjustment moves the right way', () {
    for (final kind in ColorAdjustment.values) {
      expect(adjustColor(blue, kind, 0), blue, reason: kind.name);
    }
    double lightness(Color c) => HSLColor.fromColor(c).lightness;
    expect(
      lightness(adjustColor(blue, ColorAdjustment.lightness, 50)),
      greaterThan(lightness(blue)),
    );
    expect(lightness(adjustColor(blue, ColorAdjustment.lightness, -50)), lessThan(lightness(blue)));
    expect(HSLColor.fromColor(adjustColor(blue, ColorAdjustment.saturation, -100)).saturation, 0);
    expect(HSVColor.fromColor(adjustColor(blue, ColorAdjustment.brightness, -100)).value, 0);
    final warm = adjustColor(blue, ColorAdjustment.temperature, 100);
    expect(warm.r, greaterThan(blue.r));
    expect(warm.b, lessThan(blue.b));
  });

  test('hue turns around the wheel in both directions', () {
    final red = adjustColor(const Color(0xFFFF0000), ColorAdjustment.hue, 120);
    expect(channelDistance(red, const Color(0xFF00FF00)), lessThan(3));
    final back = adjustColor(const Color(0xFFFF0000), ColorAdjustment.hue, -120);
    expect(channelDistance(back, const Color(0xFF0000FF)), lessThan(3));
  });

  test('highlights only change light colors and shadows only dark ones', () {
    const light = Color(0xFFEEEEEE);
    const dark = Color(0xFF111111);
    double l(Color c) => HSLColor.fromColor(c).lightness;
    expect(l(adjustColor(dark, ColorAdjustment.highlights, -100)), closeTo(l(dark), .01));
    expect(l(adjustColor(light, ColorAdjustment.highlights, -100)), lessThan(l(light) - .1));
    expect(l(adjustColor(light, ColorAdjustment.shadows, 100)), closeTo(l(light), .01));
    expect(l(adjustColor(dark, ColorAdjustment.shadows, 100)), greaterThan(l(dark) + .1));
  });

  test('contrast pushes channels away from mid grey', () {
    final c = adjustColor(const Color(0xFF9999CC), ColorAdjustment.contrast, 80);
    expect(c.b, greaterThan(const Color(0xFF9999CC).b));
    expect(c.r, greaterThan(const Color(0xFF9999CC).r));
  });
}
