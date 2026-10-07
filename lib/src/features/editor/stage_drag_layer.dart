import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../l10n/l10n.dart';
import 'editor_controller.dart';
import 'stage_geometry.dart';

/// Transparent layer over the stage that lets a finger select, move and
/// resize the shapes drawn on the canvas: drag to move, pinch or drag the
/// corner handle to resize. The SVG is re-rendered only on release; while
/// touching, an outline follows the finger.
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
  static const _handleSize = 32.0;
  static const _minFactor = 0.05;
  static const _maxFactor = 20.0;

  SvgMovable? _target;
  SvgTransformValues _start = SvgTransformValues.identity;

  /// Gesture result so far: movement in pixels and size factor.
  var _offset = Offset.zero;
  var _factor = 1.0;

  // Bookkeeping so moving fingers on/off keeps the result continuous.
  var _baseOffset = Offset.zero;
  var _baseFactor = 1.0;
  var _focalStart = Offset.zero;
  var _pointerCount = 0;

  // Corner handle.
  Offset _handleCenter = Offset.zero;
  var _handleStartDistance = 1.0;

  EditorController get _editor => widget.editor;

  StageGeometry _mapping(Size size) => StageGeometry.of(_editor.svg, size, widget.padding);

  SvgMovable? _hit(Offset position, StageGeometry map) {
    if (!map.isUsable) return null;
    return SvgHitTest.at(
      _editor.svg,
      (position.dx - map.originX) / map.scale,
      (position.dy - map.originY) / map.scale,
      slop: _slop / map.scale,
    );
  }

  SvgMovable? get _selected {
    final path = _editor.selection;
    if (path == null) return null;
    return SvgHitTest.movables(_editor.svg).where((m) => m.path == path).firstOrNull;
  }

  Rect _rect(SvgBounds b, StageGeometry map) => Rect.fromLTRB(
    b.left * map.scale + map.originX,
    b.top * map.scale + map.originY,
    b.right * map.scale + map.originX,
    b.bottom * map.scale + map.originY,
  );

  void _reset(SvgMovable? target) {
    _target = target;
    _start = target == null
        ? SvgTransformValues.identity
        : SvgTransformEdit.read(_editor.svg, target.path);
    _offset = Offset.zero;
    _factor = 1;
    _baseOffset = Offset.zero;
    _baseFactor = 1;
    _pointerCount = 0;
  }

  void _tap(Offset position, Size size) {
    final hit = _hit(position, _mapping(size));
    if (hit == null) {
      if (_editor.selection != null) _editor.select(null);
    } else if (_editor.selection != hit.path) {
      _editor.select(hit.path);
    }
  }

  void _bodyStart(ScaleStartDetails d, Size size) {
    final hit = _hit(d.localFocalPoint, _mapping(size));
    if (hit == null) return;
    if (_editor.selection != hit.path) _editor.select(hit.path);
    setState(() {
      _reset(hit);
      _focalStart = d.localFocalPoint;
      _pointerCount = d.pointerCount;
    });
  }

  void _bodyUpdate(ScaleUpdateDetails d) {
    if (_target == null) return;
    setState(() {
      if (d.pointerCount != _pointerCount) {
        // A finger came or went: continue from where the shape is now.
        _pointerCount = d.pointerCount;
        _baseOffset = _offset;
        _baseFactor = _factor;
        _focalStart = d.localFocalPoint;
      }
      _offset = _baseOffset + (d.localFocalPoint - _focalStart);
      _factor = (_baseFactor * d.scale).clamp(_minFactor, _maxFactor);
    });
  }

  void _handleStart(DragStartDetails d, Rect rect) {
    final target = _selected;
    if (target == null) return;
    final box = context.findRenderObject() as RenderBox;
    final center = rect.center;
    setState(() {
      _reset(target);
      _handleCenter = center;
      _handleStartDistance = math.max((box.globalToLocal(d.globalPosition) - center).distance, 1);
    });
  }

  void _handleUpdate(DragUpdateDetails d) {
    if (_target == null) return;
    final box = context.findRenderObject() as RenderBox;
    final distance = (box.globalToLocal(d.globalPosition) - _handleCenter).distance;
    setState(() => _factor = (distance / _handleStartDistance).clamp(_minFactor, _maxFactor));
  }

  void _end(Size size) {
    final target = _target;
    if (target == null) return;
    final map = _mapping(size);
    final offset = _offset;
    final factor = _factor;
    setState(() => _reset(null));
    if ((offset == Offset.zero && factor == 1) || !map.isUsable) return;
    _editor.apply(
      SvgTransformEdit.apply(
        _editor.svg,
        target.path,
        _start.copyWith(
          translateX: _start.translateX + offset.dx / map.scale,
          translateY: _start.translateY + offset.dy / map.scale,
          scale: (_start.scale * factor).clamp(_minFactor, _maxFactor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final map = _mapping(size);
        final shape = _target ?? _selected;
        Rect? outline;
        if (shape != null) {
          final b = shape.bounds;
          outline = _rect(
            _target == null ? b : b.transformed(scale: _factor),
            map,
          ).shift(_target == null ? Offset.zero : _offset).inflate(4);
        }
        final color = Theme.of(context).colorScheme.primary;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('stage-drag'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d.localPosition, size),
                onScaleStart: (d) => _bodyStart(d, size),
                onScaleUpdate: _bodyUpdate,
                onScaleEnd: (_) => _end(size),
                child: CustomPaint(
                  size: size,
                  painter: _OutlinePainter(outline, color, active: _target != null),
                ),
              ),
            ),
            if (outline != null)
              Positioned(
                left: outline.right - _handleSize / 2,
                top: outline.bottom - _handleSize / 2,
                width: _handleSize,
                height: _handleSize,
                child: Semantics(
                  button: true,
                  label: context.l10n.resizeHandle,
                  child: GestureDetector(
                    key: const Key('resize-handle'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _handleStart(d, outline!),
                    onPanUpdate: _handleUpdate,
                    onPanEnd: (_) => _end(size),
                    onPanCancel: () => setState(() => _reset(null)),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: Icon(Icons.open_in_full_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.rect, this.color, {required this.active});

  final Rect? rect;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    if (active) canvas.drawRRect(rounded, Paint()..color = color.withValues(alpha: .15));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) =>
      old.rect != rect || old.color != color || old.active != active;
}
