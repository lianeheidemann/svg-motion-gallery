import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/painting.dart';
import 'package:svg_core/svg_core.dart';

/// [gradient] as a Flutter gradient, for swatches and previews.
Gradient flutterGradient(SvgGradient gradient) {
  final colors = [
    for (final stop in gradient.stops)
      (colorFromHex(stop.color) ?? const Color(0xFF000000)).withValues(alpha: stop.opacity),
  ];
  final stops = [for (final stop in gradient.stops) stop.offset];
  if (gradient.kind == SvgGradientKind.radial) {
    return RadialGradient(
      center: Alignment(gradient.centerX * 2 - 1, gradient.centerY * 2 - 1),
      radius: gradient.radius,
      colors: colors,
      stops: stops,
    );
  }
  final radians = gradient.angle * math.pi / 180;
  final c = math.cos(radians);
  final s = math.sin(radians);
  // Stretched so the line spans the box, like the SVG one does.
  final scale = 1 / math.max(c.abs(), s.abs());
  return LinearGradient(
    begin: Alignment(-c * scale, -s * scale),
    end: Alignment(c * scale, s * scale),
    colors: colors,
    stops: stops,
  );
}
