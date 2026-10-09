import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The adjustments of the Colors tab. Each one moves a color by an amount
/// (see [adjustColor]); all of them are plain arithmetic on the color, so
/// they cost nothing to run or to ship.
enum ColorAdjustment {
  /// Turns the color around the color wheel (degrees, -180..180).
  hue,

  /// How vivid it is (-100..100).
  saturation,

  /// Lighter or darker, as HSL lightness (-100..100).
  lightness,

  /// Brighter or dimmer, as the brightness of the color (-100..100).
  brightness,

  /// Pushes the channels away from (or towards) mid grey (-100..100).
  contrast,

  /// Warmer (towards orange) or cooler (towards blue) (-100..100).
  temperature,

  /// Changes only the light colors (-100..100).
  highlights,

  /// Changes only the dark colors (-100..100).
  shadows,
}

extension ColorAdjustmentRange on ColorAdjustment {
  /// The amount at either end of the ruler (0 is "no change").
  double get limit => this == ColorAdjustment.hue ? 180 : 100;
}

/// Moves [amount] of 0..1 from [value] towards 1 (positive) or 0 (negative).
double _towards(double value, double amount) {
  final a = amount.clamp(-1.0, 1.0);
  return a >= 0 ? value + (1 - value) * a : value * (1 + a);
}

double _smooth(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// [color] changed by [amount] of [adjustment]. 0 returns the same color;
/// the amount runs over `-limit..limit` of the adjustment.
Color adjustColor(Color color, ColorAdjustment adjustment, double amount) {
  if (amount == 0) return color;
  final a = amount / adjustment.limit;
  final hsl = HSLColor.fromColor(color);
  switch (adjustment) {
    case ColorAdjustment.hue:
      return hsl.withHue(((hsl.hue + amount) % 360 + 360) % 360).toColor();
    case ColorAdjustment.saturation:
      return hsl.withSaturation(_towards(hsl.saturation, a)).toColor();
    case ColorAdjustment.lightness:
      return hsl.withLightness(_towards(hsl.lightness, a)).toColor();
    case ColorAdjustment.brightness:
      final hsv = HSVColor.fromColor(color);
      return hsv.withValue(_towards(hsv.value, a)).toColor();
    case ColorAdjustment.contrast:
      final factor = a >= 0 ? 1 + a * 1.5 : 1 + a;
      double channel(double c) => ((c - .5) * factor + .5).clamp(0.0, 1.0);
      return Color.from(
        alpha: color.a,
        red: channel(color.r),
        green: channel(color.g),
        blue: channel(color.b),
      );
    case ColorAdjustment.temperature:
      final shift = a * .22;
      return Color.from(
        alpha: color.a,
        red: (color.r + shift).clamp(0.0, 1.0),
        green: color.g,
        blue: (color.b - shift).clamp(0.0, 1.0),
      );
    case ColorAdjustment.highlights:
      final weight = _smooth(.45, 1, hsl.lightness);
      return hsl.withLightness((hsl.lightness + a * .35 * weight).clamp(0.0, 1.0)).toColor();
    case ColorAdjustment.shadows:
      final weight = 1 - _smooth(0, .55, hsl.lightness);
      return hsl.withLightness((hsl.lightness + a * .35 * weight).clamp(0.0, 1.0)).toColor();
  }
}

/// Rounds an amount to a whole number, the way the ruler shows it.
double wholeAmount(double value) => value.roundToDouble();

/// Largest distance between two channels, for tests of "close enough".
int channelDistance(Color a, Color b) => math.max(
  (a.r * 255 - b.r * 255).abs().round(),
  math.max((a.g * 255 - b.g * 255).abs().round(), (a.b * 255 - b.b * 255).abs().round()),
);
