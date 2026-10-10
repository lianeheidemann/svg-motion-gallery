import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import 'stage_geometry.dart';

/// The shapes among [paths] that are drawn straight on the canvas, so their
/// outline can be worked out from the document alone (see [SelectionOutlines]).
List<SvgMovable> movablesAmong(String svg, Iterable<ElementPath> paths) {
  final wanted = paths.toList();
  if (wanted.isEmpty) return const [];
  return [
    for (final shape in SvgHitTest.movables(svg))
      if (wanted.contains(shape.path)) shape,
  ];
}

/// Where [shape] is on the stage: its box (with room around it) and how much
/// it is turned, in radians, around the center of that box.
({Rect rect, double turn}) outlineOf(SvgMovable shape, StageGeometry map) {
  final b = shape.bounds;
  final rect = Rect.fromLTRB(
    b.left * map.scale + map.originX,
    b.top * map.scale + map.originY,
    b.right * map.scale + map.originX,
    b.bottom * map.scale + map.originY,
  ).inflate(4);
  return (rect: rect, turn: shape.rotation * math.pi / 180);
}

/// Outlines the ticked shapes on the stage from the document's own geometry,
/// like the outline of the selected shape: it turns and resizes with the
/// shape, and follows a slider while it is dragged (the document is the
/// preview). Draws only; touches go through it.
class SelectionOutlines extends StatelessWidget {
  const SelectionOutlines({
    super.key,
    required this.svg,
    required this.shapes,
    required this.padding,
  });

  final String svg;

  /// What to outline, from [movablesAmong] on the same [svg].
  final List<SvgMovable> shapes;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final map = StageGeometry.of(svg, constraints.biggest, padding);
          if (!map.isUsable) return const SizedBox.shrink();
          return CustomPaint(
            size: constraints.biggest,
            painter: _OutlinesPainter([for (final shape in shapes) outlineOf(shape, map)], color),
          );
        },
      ),
    );
  }
}

class _OutlinesPainter extends CustomPainter {
  const _OutlinesPainter(this.outlines, this.color);

  final List<({Rect rect, double turn})> outlines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final outline in outlines) {
      StageOutlinePainter.drawOutline(canvas, outline.rect, outline.turn, color, active: false);
    }
  }

  @override
  bool shouldRepaint(covariant _OutlinesPainter old) =>
      old.color != color || !_same(old.outlines, outlines);

  static bool _same(List<({Rect rect, double turn})> a, List<({Rect rect, double turn})> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].rect != b[i].rect || a[i].turn != b[i].turn) return false;
    }
    return true;
  }
}

/// The outline of one shape: [rect] turned by [turn] radians around its center.
class StageOutlinePainter extends CustomPainter {
  const StageOutlinePainter(this.rect, this.turn, this.color, {required this.active});

  final Rect? rect;

  /// Radians, clockwise, around the center of [rect].
  final double turn;
  final Color color;
  final bool active;

  static void drawOutline(
    Canvas canvas,
    Rect rect,
    double turn,
    Color color, {
    required bool active,
  }) {
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..rotate(turn)
      ..translate(-rect.center.dx, -rect.center.dy);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    if (active) canvas.drawRRect(rounded, Paint()..color = color.withValues(alpha: .15));
    canvas
      ..drawRRect(
        rounded,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.5,
      )
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    drawOutline(canvas, rect, turn, color, active: active);
  }

  @override
  bool shouldRepaint(covariant StageOutlinePainter old) =>
      old.rect != rect || old.turn != turn || old.color != color || old.active != active;
}
