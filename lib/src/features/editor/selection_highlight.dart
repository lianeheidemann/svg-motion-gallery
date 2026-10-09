import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svg_view/svg_view.dart';

/// Outlines the element picked in the layer list (or anywhere) on the stage,
/// so it is clear which one is being edited. The renderer reports where the
/// element is drawn, so this works for any element: paths, groups, shapes.
/// Draws only; touches go through it.
class SelectionHighlight extends StatelessWidget {
  const SelectionHighlight({super.key, required this.controller, required this.padding});

  final SvgPlaybackController controller;

  /// Padding between the stage edge and the drawing (the rendered view).
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final inner = padding.deflateSize(constraints.biggest);
            final rects = [
              for (final box in controller.selectionBoxes)
                Rect.fromLTRB(
                  padding.left + box.left * inner.width,
                  padding.top + box.top * inner.height,
                  padding.left + box.right * inner.width,
                  padding.top + box.bottom * inner.height,
                ),
            ];
            return CustomPaint(size: constraints.biggest, painter: _HighlightPainter(rects, color));
          },
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in rects) {
      final shape = RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(3));
      canvas
        ..drawRRect(shape, Paint()..color = color.withValues(alpha: .14))
        ..drawRRect(
          shape,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter old) =>
      !listEquals(old.rects, rects) || old.color != color;
}
