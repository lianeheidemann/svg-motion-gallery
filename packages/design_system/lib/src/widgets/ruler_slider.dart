import 'package:flutter/material.dart';

/// A dial-style ruler: the marks slide under a fixed marker in the middle as
/// the finger drags sideways, and the value sits above it. Drag left to raise
/// the value, right to lower it. Cheap to draw: ticks only, no images.
class RulerSlider extends StatefulWidget {
  const RulerSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.semanticLabel,
    this.unit = '',
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;

  /// Shown after the number above the marker (e.g. `°`).
  final String unit;

  @override
  State<RulerSlider> createState() => _RulerSliderState();
}

class _RulerSliderState extends State<RulerSlider> {
  /// Logical pixels per unit of value, and the spacing of the marks.
  static const _pixelsPerUnit = 3.2;
  static const _tickEvery = 5;
  static const _majorEvery = 25;

  double? _dragFrom;
  var _dragged = 0.0;

  /// The value last reported while dragging (the widget may not have rebuilt
  /// with it yet when the finger lifts).
  var _latest = 0.0;

  bool get _enabled => widget.onChanged != null;

  double _clamp(double v) => v.clamp(widget.min, widget.max).toDouble();

  void _start(DragStartDetails d) {
    _dragFrom = widget.value;
    _latest = widget.value;
    _dragged = 0;
    widget.onChangeStart?.call(widget.value);
  }

  void _update(DragUpdateDetails d) {
    final from = _dragFrom;
    if (from == null) return;
    _dragged += d.delta.dx;
    final next = _clamp((from - _dragged / _pixelsPerUnit).roundToDouble());
    if (next != _latest) {
      _latest = next;
      widget.onChanged?.call(next);
    }
  }

  void _end([DragEndDetails? d]) {
    if (_dragFrom == null) return;
    _dragFrom = null;
    widget.onChangeEnd?.call(_latest);
  }

  void _nudge(double by) {
    final next = _clamp(widget.value + by);
    if (next == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = _clamp(widget.value);
    return Semantics(
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: '${value.round()}${widget.unit}',
      increasedValue: '${_clamp(value + 1).round()}${widget.unit}',
      decreasedValue: '${_clamp(value - 1).round()}${widget.unit}',
      onIncrease: _enabled ? () => _nudge(1) : null,
      onDecrease: _enabled ? () => _nudge(-1) : null,
      child: GestureDetector(
        key: const Key('ruler'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _enabled ? _start : null,
        onHorizontalDragUpdate: _enabled ? _update : null,
        onHorizontalDragEnd: _enabled ? _end : null,
        onHorizontalDragCancel: _enabled ? _end : null,
        child: SizedBox(
          height: 44,
          child: Column(
            children: [
              Text(
                '${value.round()}${widget.unit}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _enabled ? scheme.onSurface : scheme.outline,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _RulerPainter(
                    value: value,
                    min: widget.min,
                    max: widget.max,
                    tick: scheme.outline,
                    marker: _enabled ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.tick,
    required this.marker,
  });

  final double value;
  final double min;
  final double max;
  final Color tick;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const ppu = _RulerSliderState._pixelsPerUnit;
    final step = _RulerSliderState._tickEvery;
    final visible = center / ppu;
    final first = ((value - visible).floor() ~/ step) * step;
    for (var u = first; u <= value + visible; u += step) {
      if (u < min || u > max) continue;
      final x = center + (u - value) * ppu;
      final major = u % _RulerSliderState._majorEvery == 0;
      // Fade towards the edges so the ruler seems to roll away.
      final fade = (1 - ((x - center).abs() / center)).clamp(0.15, 1.0);
      paint
        ..color = tick.withValues(alpha: fade * .8)
        ..strokeWidth = major ? 2 : 1.6;
      final height = size.height * (major ? .75 : .5);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
    paint
      ..color = marker
      ..strokeWidth = 4;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.tick != tick ||
      old.marker != marker;
}
