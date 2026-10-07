import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

/// Where the drawing's canvas (its viewBox) sits on the editor stage: the SVG
/// is fitted inside the stage minus its padding and centered.
class StageGeometry {
  const StageGeometry({
    required this.scale,
    required this.originX,
    required this.originY,
    required this.canvas,
  });

  factory StageGeometry.of(String svg, Size size, EdgeInsets padding) {
    final canvas = SvgMetadata.parse(svg).canvas;
    final inner = padding.deflateSize(size);
    final scale = math.min(inner.width / canvas.width, inner.height / canvas.height);
    return StageGeometry(
      scale: scale,
      originX: padding.left + (inner.width - canvas.width * scale) / 2 - canvas.minX * scale,
      originY: padding.top + (inner.height - canvas.height * scale) / 2 - canvas.minY * scale,
      canvas: canvas,
    );
  }

  /// Logical pixels per user unit, and where user (0, 0) lands on the stage.
  final double scale;
  final double originX;
  final double originY;
  final SvgViewBox canvas;

  bool get isUsable => scale.isFinite && scale > 0;

  /// The canvas on the stage, in logical pixels.
  Rect get canvasRect => Rect.fromLTWH(
    originX + canvas.minX * scale,
    originY + canvas.minY * scale,
    canvas.width * scale,
    canvas.height * scale,
  );
}

/// A frame around the canvas, so it is clear which area is being edited and
/// what will be saved. Draws only; touches go through it.
class CanvasFrame extends StatelessWidget {
  const CanvasFrame({super.key, required this.svg, required this.padding});

  final String svg;

  /// Padding between the stage edge and the drawing.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = StageGeometry.of(svg, constraints.biggest, padding);
          return CustomPaint(
            size: constraints.biggest,
            painter: _FramePainter(geometry.isUsable ? geometry.canvasRect : null, color),
          );
        },
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.rect, this.color);

  final Rect? rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    // Dashed outline just outside the canvas, plus solid corner marks.
    final dash = Paint()
      ..color = color.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outer = rect.inflate(1);
    final path = Path()..addRect(outer);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 7, metric.length)), dash);
      }
    }
    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const len = 14.0;
    for (final p in [
      [outer.topLeft, const Offset(len, 0), const Offset(0, len)],
      [outer.topRight, const Offset(-len, 0), const Offset(0, len)],
      [outer.bottomLeft, const Offset(len, 0), const Offset(0, -len)],
      [outer.bottomRight, const Offset(-len, 0), const Offset(0, -len)],
    ]) {
      final origin = p[0];
      canvas.drawLine(origin, origin + p[1], corner);
      canvas.drawLine(origin, origin + p[2], corner);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.rect != rect || old.color != color;
}
