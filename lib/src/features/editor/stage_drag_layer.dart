import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../l10n/l10n.dart';
import 'editor_controller.dart';
import 'stage_geometry.dart';

/// Transparent layer over the stage that lets a finger select, move, resize
/// and rotate the shapes drawn on the canvas: drag to move, pinch/twist with
/// two fingers, or use the corner handles (bottom-right resizes, top-right
/// rotates). The SVG is re-rendered only on release; while touching, an
/// outline follows the finger.
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

  /// Gesture result so far: movement in pixels, size factor and turn (degrees).
  var _offset = Offset.zero;
  var _factor = 1.0;
  var _angle = 0.0;

  // Bookkeeping so moving fingers on/off keeps the result continuous.
  var _baseOffset = Offset.zero;
  var _baseFactor = 1.0;
  var _baseAngle = 0.0;
  var _focalStart = Offset.zero;
  var _pointerCount = 0;

  /// Where the first finger of the current touch landed.
  Offset? _touchDown;

  // Corner handles.
  Offset _handleCenter = Offset.zero;
  var _handleStartDistance = 1.0;
  var _handleStartAngle = 0.0;

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
    _angle = 0;
    _baseOffset = Offset.zero;
    _baseFactor = 1;
    _baseAngle = 0;
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
    // The recognizer only starts after the finger moved past the touch slop;
    // measure from where it first touched, so that part is not lost.
    final from = _touchDown ?? d.localFocalPoint;
    final hit = _hit(from, _mapping(size));
    if (hit == null) return;
    if (_editor.selection != hit.path) _editor.select(hit.path);
    setState(() {
      _reset(hit);
      _focalStart = from;
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
        _baseAngle = _angle;
        _focalStart = d.localFocalPoint;
      }
      _offset = _baseOffset + (d.localFocalPoint - _focalStart);
      _factor = (_baseFactor * d.scale).clamp(_minFactor, _maxFactor);
      _angle = _baseAngle + d.rotation * 180 / math.pi;
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

  void _rotateStart(DragStartDetails d, Rect rect) {
    final target = _selected;
    if (target == null) return;
    final box = context.findRenderObject() as RenderBox;
    final center = rect.center;
    final from = box.globalToLocal(d.globalPosition) - center;
    setState(() {
      _reset(target);
      _handleCenter = center;
      _handleStartAngle = math.atan2(from.dy, from.dx);
    });
  }

  void _rotateUpdate(DragUpdateDetails d) {
    if (_target == null) return;
    final box = context.findRenderObject() as RenderBox;
    final to = box.globalToLocal(d.globalPosition) - _handleCenter;
    setState(() => _angle = (math.atan2(to.dy, to.dx) - _handleStartAngle) * 180 / math.pi);
  }

  /// Degrees folded into -180..180, the range of the rotation slider.
  static double _fold(double degrees) => ((degrees + 180) % 360 + 360) % 360 - 180;

  void _end(Size size) {
    final target = _target;
    if (target == null) return;
    final map = _mapping(size);
    final offset = _offset;
    final factor = _factor;
    final angle = _angle;
    // Reset wipes the starting values, so keep them for the edit below.
    final start = _start;
    setState(() => _reset(null));
    if ((offset == Offset.zero && factor == 1 && angle == 0) || !map.isUsable) return;
    _editor.apply(
      SvgTransformEdit.apply(
        _editor.svg,
        target.path,
        start.copyWith(
          translateX: start.translateX + offset.dx / map.scale,
          translateY: start.translateY + offset.dy / map.scale,
          scale: (start.scale * factor).clamp(_minFactor, _maxFactor),
          rotation: _fold(start.rotation + angle),
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
        var turn = 0.0; // radians
        if (shape != null) {
          final gesturing = _target != null;
          final b = shape.bounds;
          outline = _rect(
            gesturing ? b.transformed(scale: _factor) : b,
            map,
          ).shift(gesturing ? _offset : Offset.zero).inflate(4);
          final degrees = gesturing ? _start.rotation + _angle : shape.rotation;
          turn = degrees * math.pi / 180;
        }
        final color = Theme.of(context).colorScheme.primary;
        final l10n = context.l10n;

        /// A corner of [outline] after the shape's turn.
        Offset corner(Offset c) {
          final center = outline!.center;
          final v = c - center;
          return center +
              Offset(
                v.dx * math.cos(turn) - v.dy * math.sin(turn),
                v.dx * math.sin(turn) + v.dy * math.cos(turn),
              );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (e) {
                  if (e.down && _pointerCount == 0) _touchDown = e.localPosition;
                },
                child: GestureDetector(
                  key: const Key('stage-drag'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tap(d.localPosition, size),
                  onScaleStart: (d) => _bodyStart(d, size),
                  onScaleUpdate: _bodyUpdate,
                  onScaleEnd: (_) => _end(size),
                  child: CustomPaint(
                    size: size,
                    painter: _OutlinePainter(outline, turn, color, active: _target != null),
                  ),
                ),
              ),
            ),
            if (outline != null) ...[
              _handle(
                key: const Key('rotate-handle'),
                at: corner(outline.topRight),
                icon: Icons.rotate_right_rounded,
                label: l10n.rotateHandle,
                color: color,
                onStart: (d) => _rotateStart(d, outline!),
                onUpdate: _rotateUpdate,
                onEnd: () => _end(size),
              ),
              _handle(
                key: const Key('resize-handle'),
                at: corner(outline.bottomRight),
                icon: Icons.open_in_full_rounded,
                label: l10n.resizeHandle,
                color: color,
                onStart: (d) => _handleStart(d, outline!),
                onUpdate: _handleUpdate,
                onEnd: () => _end(size),
              ),
            ],
          ],
        );
      },
    );
  }

  /// A round grab point centered on [at].
  Widget _handle({
    required Key key,
    required Offset at,
    required IconData icon,
    required String label,
    required Color color,
    required void Function(DragStartDetails) onStart,
    required void Function(DragUpdateDetails) onUpdate,
    required VoidCallback onEnd,
  }) => Positioned(
    left: at.dx - _handleSize / 2,
    top: at.dy - _handleSize / 2,
    width: _handleSize,
    height: _handleSize,
    child: Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onPanStart: onStart,
        onPanUpdate: onUpdate,
        onPanEnd: (_) => onEnd(),
        onPanCancel: () => setState(() => _reset(null)),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Icon(icon, size: 12, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.rect, this.turn, this.color, {required this.active});

  final Rect? rect;

  /// Radians, clockwise, around the center of [rect].
  final double turn;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
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
  bool shouldRepaint(covariant _OutlinePainter old) =>
      old.rect != rect || old.turn != turn || old.color != color || old.active != active;
}
