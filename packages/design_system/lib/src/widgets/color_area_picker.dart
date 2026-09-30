import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Free color picker: a saturation/brightness square plus a hue bar.
/// [onChanged] fires while dragging, [onChangeEnd] once when released.
class ColorAreaPicker extends StatefulWidget {
  const ColorAreaPicker({
    super.key,
    required this.color,
    this.onChanged,
    this.onChangeEnd,
    this.height = 160,
  });

  final Color color;
  final double height;
  final ValueChanged<Color>? onChanged;
  final ValueChanged<Color>? onChangeEnd;

  @override
  State<ColorAreaPicker> createState() => _ColorAreaPickerState();
}

class _ColorAreaPickerState extends State<ColorAreaPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  @override
  void didUpdateWidget(covariant ColorAreaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow outside changes (undo, hex field) but keep the hue of greys.
    if (widget.color.toARGB32() != _hsv.toColor().toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _set(HSVColor hsv, {bool end = false}) {
    setState(() => _hsv = hsv);
    widget.onChanged?.call(hsv.toColor());
    if (end) widget.onChangeEnd?.call(hsv.toColor());
  }

  void _area(Offset position, Size size, {bool end = false}) {
    final s = (position.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (position.dy / size.height).clamp(0.0, 1.0);
    _set(_hsv.withSaturation(s).withValue(v), end: end);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            return GestureDetector(
              onPanStart: (d) => _area(d.localPosition, size),
              onPanUpdate: (d) => _area(d.localPosition, size),
              onPanEnd: (_) => _set(_hsv, end: true),
              onTapUp: (d) => _area(d.localPosition, size, end: true),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.white, hueColor]),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _hsv.saturation * size.width - 10,
                        top: (1 - _hsv.value) * size.height - 10,
                        child: IgnorePointer(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black54)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            for (var h = 0; h <= 360; h += 60)
                              HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                          ],
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 12,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: hueColor,
                      ),
                      child: Slider(
                        value: _hsv.hue.clamp(0, 360),
                        min: 0,
                        max: 360,
                        semanticFormatterCallback: (v) => '${v.round()}°',
                        onChanged: (v) => _set(_hsv.withHue(v)),
                        onChangeEnd: (_) => _set(_hsv, end: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
