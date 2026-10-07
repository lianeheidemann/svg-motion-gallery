import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import 'editor_controller.dart';

/// Transparent layer over the stage that lets a finger grab a shape drawn on
/// the canvas and drag it. The SVG is re-rendered only on release; while
/// dragging, an outline follows the finger.
class StageDragLayer extends StatefulWidget {
  const StageDragLayer({super.key, required this.editor, required this.padding});

  final EditorController editor;

  /// Padding between the stage edge and the drawing.
  final EdgeInsets padding;

  @override
  State<StageDragLayer> createState() => _StageDragLayerState();
}

class _StageDragLayerState extends State<StageDragLayer> {
  /// Touch tolerance, in logical pixels.
  static const _slop = 14.0;

  SvgMovable? _target;
  SvgTransformValues _start = SvgTransformValues.identity;
  var _offset = Offset.zero;

  EditorController get _editor => widget.editor;

  _Mapping _mapping(Size size) {
    final canvas = SvgMetadata.parse(_editor.svg).canvas;
    final inner = widget.padding.deflateSize(size);
    final scale = math.min(inner.width / canvas.width, inner.height / canvas.height);
    return _Mapping(
      scale: scale,
      originX: widget.padding.left + (inner.width - canvas.width * scale) / 2 - canvas.minX * scale,
      originY:
          widget.padding.top + (inner.height - canvas.height * scale) / 2 - canvas.minY * scale,
    );
  }

  void _down(Offset position, Size size) {
    final map = _mapping(size);
    if (!map.scale.isFinite || map.scale <= 0) return;
    final hit = SvgHitTest.at(
      _editor.svg,
      (position.dx - map.originX) / map.scale,
      (position.dy - map.originY) / map.scale,
      slop: _slop / map.scale,
    );
    if (hit == null) return;
    if (_editor.selection != hit.path) _editor.select(hit.path);
    setState(() {
      _target = hit;
      _start = SvgTransformEdit.read(_editor.svg, hit.path);
      _offset = Offset.zero;
    });
  }

  void _end(Size size) {
    final target = _target;
    if (target == null) return;
    final map = _mapping(size);
    setState(() => _target = null);
    if (_offset == Offset.zero || !map.scale.isFinite || map.scale <= 0) return;
    _editor.apply(
      SvgTransformEdit.apply(
        _editor.svg,
        target.path,
        _start.copyWith(
          translateX: _start.translateX + _offset.dx / map.scale,
          translateY: _start.translateY + _offset.dy / map.scale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final target = _target;
        Rect? outline;
        if (target != null) {
          final map = _mapping(size);
          final b = target.bounds;
          outline = Rect.fromLTRB(
            b.left * map.scale + map.originX,
            b.top * map.scale + map.originY,
            b.right * map.scale + map.originX,
            b.bottom * map.scale + map.originY,
          ).shift(_offset).inflate(4);
        }
        return GestureDetector(
          key: const Key('stage-drag'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _down(d.localPosition, size),
          onPanUpdate: (d) {
            if (_target != null) setState(() => _offset += d.delta);
          },
          onPanEnd: (_) => _end(size),
          onPanCancel: () => setState(() => _target = null),
          child: CustomPaint(
            size: size,
            painter: _OutlinePainter(outline, Theme.of(context).colorScheme.primary),
          ),
        );
      },
    );
  }
}

class _Mapping {
  const _Mapping({required this.scale, required this.originX, required this.originY});

  /// Logical pixels per user unit, and where user (0, 0) lands in the layer.
  final double scale;
  final double originX;
  final double originY;
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.rect, this.color);

  final Rect? rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rounded, Paint()..color = color.withValues(alpha: .15));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) => old.rect != rect || old.color != color;
}
