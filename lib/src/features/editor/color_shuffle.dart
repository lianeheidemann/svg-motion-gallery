import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How [shuffleColors] picks the new palette.
enum ShuffleMode {
  /// A random recipe: a scheme, a mood and (sometimes) warm lights / cool shadows.
  surprise,

  /// Hue families spaced by the golden angle (137.5°): never repeats, works
  /// for any number of families.
  goldenAngle,

  /// A procedural gradient (cosine palette) walked along the families.
  cosine,

  /// Classic harmonies: split-complementary, triad or tetrad.
  classic,
}

/// A color as OKLCH: [l] lightness 0..1, [c] chroma, [h] hue in degrees.
class _Lch {
  const _Lch(this.l, this.c, this.h);
  final double l;
  final double c;
  final double h;
}

/// Colors with less chroma than this (black, white, greys) are left alone.
const _neutralChroma = 0.03;

/// The key of [color] in the map returned by [shuffleColors]: its RGB value
/// (alpha is ignored, the caller keeps it).
int colorKey(Color color) =>
    (_byte(color.r) << 16) | (_byte(color.g) << 8) | _byte(color.b);

int _byte(double channel) => (channel * 255).round().clamp(0, 255);

/// Picks a new, harmonious palette for [colors] and returns what each original
/// color becomes (keyed by [colorKey]).
///
/// It never sorts one random color per input, so it works the same for 3 or
/// 100 colors: the originals are grouped into a few hue families, every family
/// gets a new hue from the [mode]'s recipe, and each color keeps its place in
/// its family (and its lightness order, so background stays background and
/// highlights stay highlights). Neutrals are left out of the map.
Map<int, Color> shuffleColors(Iterable<Color> colors, ShuffleMode mode, math.Random random) {
  final originals = <int, _Lch>{};
  for (final color in colors) {
    final lch = _toLch(color);
    if (lch.c >= _neutralChroma) originals.putIfAbsent(colorKey(color), () => lch);
  }
  if (originals.isEmpty) return const {};

  final keys = originals.keys.toList();
  final lch = [for (final k in keys) originals[k]!];
  final family = _families(lch);
  final count = family.reduce(math.max) + 1;

  var minL = 1.0, maxL = 0.0, minC = 1.0, maxC = 0.0;
  for (final c in lch) {
    minL = math.min(minL, c.l);
    maxL = math.max(maxL, c.l);
    minC = math.min(minC, c.c);
    maxC = math.max(maxC, c.c);
  }
  double norm(double v, double lo, double hi) => hi - lo < 1e-6 ? 0.5 : (v - lo) / (hi - lo);

  // A few tries: keep the first palette whose families are far enough apart,
  // else the one that got them furthest apart.
  Map<int, Color>? best;
  var bestSpread = -1.0;
  for (var attempt = 0; attempt < 8; attempt++) {
    final recipe = _Recipe(mode, count, random);
    final result = <int, Color>{};
    final reps = List<_Lch?>.filled(count, null);
    for (var i = 0; i < keys.length; i++) {
      final from = lch[i];
      final lNorm = norm(from.l, minL, maxL);
      final cNorm = norm(from.c, minC, maxC);
      final to = recipe.apply(from, family[i], lNorm, cNorm);
      result[keys[i]] = _fromLch(to);
      reps[family[i]] ??= to;
    }
    final spread = _spread([for (final r in reps) r!]);
    if (spread > bestSpread) {
      best = result;
      bestSpread = spread;
    }
    if (spread >= 0.09) break;
  }
  return best!;
}

/// Splits the colors by hue into at most four families (a new family starts at
/// a gap of 25°+ in the hue circle); returns each color's family index, in the
/// order of the original hues.
List<int> _families(List<_Lch> lch) {
  if (lch.length == 1) return const [0];
  final order = List.generate(lch.length, (i) => i)..sort((a, b) => lch[a].h.compareTo(lch[b].h));
  // Gaps between neighbouring hues; the last one closes the circle (a full
  // turn when every color has the same hue).
  final gaps = <({int after, double size})>[];
  for (var i = 0; i < order.length; i++) {
    final a = lch[order[i]].h;
    final b = lch[order[(i + 1) % order.length]].h;
    final size = (b - a + 360) % 360;
    gaps.add((after: i, size: i == order.length - 1 && size == 0 ? 360 : size));
  }
  final cuts = (gaps.where((g) => g.size >= 25).toList()..sort((a, b) => b.size.compareTo(a.size)))
      .take(3)
      .map((g) => g.after)
      .toSet();
  // Fewer than two cuts means a single family (a cut count of one cannot
  // split a circle).
  if (cuts.length < 2) return List.filled(lch.length, 0);
  final cutList = cuts.toList()..sort();
  final out = List.filled(lch.length, 0);
  // Family 0 starts right after the last cut.
  var current = 0;
  final start = (cutList.last + 1) % order.length;
  for (var n = 0; n < order.length; n++) {
    final index = (start + n) % order.length;
    out[order[index]] = current;
    if (cuts.contains(index)) current++;
  }
  return out;
}

/// The smallest OKLab distance between any two family colors (1 when single).
double _spread(List<_Lch> reps) {
  if (reps.length < 2) return 1;
  var best = double.infinity;
  for (var i = 0; i < reps.length; i++) {
    for (var j = i + 1; j < reps.length; j++) {
      final a = reps[i], b = reps[j];
      final ar = a.h * math.pi / 180, br = b.h * math.pi / 180;
      final da = a.c * math.cos(ar) - b.c * math.cos(br);
      final db = a.c * math.sin(ar) - b.c * math.sin(br);
      best = math.min(best, math.sqrt((a.l - b.l) * (a.l - b.l) + da * da + db * db));
    }
  }
  return best;
}

/// A mood narrows lightness and chroma to a range, giving the palette a feel.
class _Mood {
  const _Mood(this.lo, this.hi, this.cLo, this.cHi);
  final double lo, hi, cLo, cHi;
}

const _moods = [
  _Mood(0.78, 0.94, 0.04, 0.09), // pastel
  _Mood(0.62, 0.84, 0.17, 0.27), // neon
  _Mood(0.38, 0.72, 0.05, 0.11), // earthy
  _Mood(0.45, 0.80, 0.06, 0.12), // vintage
  _Mood(0.22, 0.58, 0.08, 0.20), // night
];

/// One random recipe: how family hues are chosen and how a color is moved.
class _Recipe {
  _Recipe(ShuffleMode mode, this.count, this.random) {
    final resolved = mode == ShuffleMode.surprise
        ? const [ShuffleMode.goldenAngle, ShuffleMode.cosine, ShuffleMode.classic][random.nextInt(3)]
        : mode;
    this.mode = resolved;
    base = random.nextDouble() * 360;
    if (mode == ShuffleMode.surprise) {
      // Half the time the palette keeps the original lightness and chroma.
      mood = random.nextBool() ? _moods[random.nextInt(_moods.length)] : null;
      slide = random.nextBool();
    }
    offsets = _classicOffsets();
    for (var i = 0; i < 3; i++) {
      freq[i] = 0.6 + random.nextDouble() * 0.8;
      phase[i] = random.nextDouble();
    }
  }

  final int count;
  final math.Random random;
  late final ShuffleMode mode;
  late final double base;
  _Mood? mood;
  var slide = false;
  late final List<double> offsets;
  final freq = List.filled(3, 1.0);
  final phase = List.filled(3, 0.0);

  /// Hue offsets for [ShuffleMode.classic], in a random order, one per family.
  List<double> _classicOffsets() {
    const schemes = [
      [0.0, 150.0, 210.0], // split-complementary
      [0.0, 120.0, 240.0], // triad
      [0.0, 90.0, 180.0, 270.0], // tetrad
      [0.0, 180.0, 60.0, 240.0], // double complementary
    ];
    final scheme = [...schemes[random.nextInt(schemes.length)]];
    final out = <double>[];
    // The first offset is always 0; the rest are shuffled so the family order
    // does not always give the same colors.
    out.add(scheme.removeAt(0));
    scheme.shuffle(random);
    out.addAll(scheme);
    // More families than offsets: continue around the circle.
    while (out.length < count) {
      out.add((out.last + 137.5) % 360);
    }
    return out;
  }

  _Lch apply(_Lch from, int family, double lNorm, double cNorm) {
    var l = from.l;
    var c = from.c;
    var h = switch (mode) {
      ShuffleMode.goldenAngle => base + 137.508 * family,
      ShuffleMode.classic => base + offsets[family],
      ShuffleMode.cosine => _cosineHue(family, lNorm),
      ShuffleMode.surprise => base,
    };
    if (mode == ShuffleMode.cosine) {
      c = math.max(c, 0.08);
    }
    // Keep a little of the color's own spread inside its family.
    h += _spreadInFamily(from.h, family);

    final m = mood;
    if (m != null) {
      l = m.lo + (m.hi - m.lo) * lNorm;
      c = m.cLo + (m.cHi - m.cLo) * cNorm;
    }
    if (slide) {
      // Warm lights, cool shadows: the hue leans towards yellow as it gets
      // lighter and towards violet as it gets darker.
      final lean = (lNorm * 2 - 1);
      h = _lerpHue(h, lean >= 0 ? 75 : 285, 0.3 * lean.abs());
    }
    return _Lch(l.clamp(0.05, 0.97), c, ((h % 360) + 360) % 360);
  }

  /// How far the color's hue is from the middle of the first color of its
  /// family, capped, so colors of one family stay close but not identical.
  final _familyHue = <int, double>{};
  double _spreadInFamily(double hue, int family) {
    final anchor = _familyHue.putIfAbsent(family, () => hue);
    var d = ((hue - anchor + 540) % 360) - 180;
    d = d.clamp(-30.0, 30.0);
    return d * 0.5;
  }

  /// The hue of an Inigo Quilez cosine palette `0.5 + 0.5·cos(2π(f·t + p))`,
  /// at `t` from the family and the lightness.
  double _cosineHue(int family, double lNorm) {
    final t = (family + lNorm * 0.6) / math.max(count, 1);
    double ch(int i) => 0.5 + 0.5 * math.cos(2 * math.pi * (freq[i] * t + phase[i]));
    final color = Color.from(alpha: 1, red: ch(0), green: ch(1), blue: ch(2));
    return _toLch(color).h;
  }
}

double _lerpHue(double from, double to, double t) {
  final d = ((to - from + 540) % 360) - 180;
  return from + d * t;
}

// --- OKLab ------------------------------------------------------------

double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _fromLinear(double c) =>
    c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

_Lch _toLch(Color color) {
  final r = _toLinear(color.r), g = _toLinear(color.g), b = _toLinear(color.b);
  final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3).toDouble();
  final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3).toDouble();
  final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3).toDouble();
  final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  final chroma = math.sqrt(a * a + bb * bb);
  final hue = chroma < 1e-4 ? 0.0 : (math.atan2(bb, a) * 180 / math.pi + 360) % 360;
  return _Lch(lightness, chroma, hue);
}

/// The sRGB values (0..1) of an OKLCH color, or null when outside the gamut.
List<double>? _rgbIfInGamut(double lightness, double chroma, double hue) {
  final h = hue * math.pi / 180;
  final a = chroma * math.cos(h), b = chroma * math.sin(h);
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  final rgb = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  ];
  const eps = 1e-4;
  return rgb.every((v) => v >= -eps && v <= 1 + eps) ? rgb : null;
}

/// The sRGB color of [lch]; a color outside the gamut loses chroma (not
/// lightness or hue) until it fits.
Color _fromLch(_Lch lch) {
  var lo = 0.0, hi = lch.c;
  var rgb = _rgbIfInGamut(lch.l, hi, lch.h);
  if (rgb == null) {
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      if (_rgbIfInGamut(lch.l, mid, lch.h) == null) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    rgb = _rgbIfInGamut(lch.l, lo, lch.h) ?? const [0.0, 0.0, 0.0];
  }
  return Color.from(
    alpha: 1,
    red: _fromLinear(rgb[0].clamp(0.0, 1.0)),
    green: _fromLinear(rgb[1].clamp(0.0, 1.0)),
    blue: _fromLinear(rgb[2].clamp(0.0, 1.0)),
  );
}
