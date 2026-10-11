import 'package:flutter/material.dart';

/// A strip showing a gradient with one draggable handle per color stop.
///
/// Tap a handle to select it, drag it to move it, tap an empty spot of the
/// strip to add a stop there. The bar only reports what the user did; the
/// caller owns the stops.
class GradientBar extends StatefulWidget {
  const GradientBar({
    super.key,
    required this.colors,
    required this.offsets,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onAdd,
    this.semanticLabel,
  }) : assert(colors.length == offsets.length);

  /// Color of each stop, opacity included.
  final List<Color> colors;

  /// Position of each stop, 0 to 1, in the same order as [colors].
  final List<double> offsets;

  /// Index of the highlighted stop.
  final int selected;
  final ValueChanged<int> onSelect;

  /// A handle was dragged to a new position.
  final void Function(int index, double offset) onMove;

  /// The drag of a handle ended.
  final VoidCallback onMoveEnd;

  /// An empty spot of the strip was tapped.
  final ValueChanged<double> onAdd;

  /// Accessibility label of the handle at an index.
  final String Function(int index)? semanticLabel;

  static const _handle = 26.0;
  static const _barHeight = 28.0;

  @override
  State<GradientBar> createState() => _GradientBarState();
}

class _GradientBarState extends State<GradientBar> {
  static const _height = GradientBar._handle + 14;

  int? _dragging;

  /// Index of the handle under [x] (a pixel position on a strip [width] wide),
  /// the nearest one when two overlap; null when none is close enough.
  int? _handleAt(double x, double width) {
    int? best;
    var bestDistance = GradientBar._handle / 2 + 6;
    for (var i = 0; i < widget.offsets.length; i++) {
      final distance = (widget.offsets[i] * width - x).abs();
      // On a tie the selected one wins, so a stack of stops can be told apart.
      if (distance < bestDistance || (distance == bestDistance && i == widget.selected)) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The first and last handles sit half a handle in, so they can be tapped.
        const inset = GradientBar._handle / 2;
        final width = constraints.maxWidth - 2 * inset;
        final gradient = LinearGradient(colors: widget.colors, stops: widget.offsets);
        return GestureDetector(
          key: const Key('gradient-bar'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final x = details.localPosition.dx - inset;
            final hit = _handleAt(x, width);
            if (hit != null) {
              widget.onSelect(hit);
            } else {
              widget.onAdd((x / width).clamp(0.0, 1.0));
            }
          },
          // The handle is picked where the finger went down: by the time the drag
          // starts the finger has already moved past the touch slop.
          onHorizontalDragDown: (details) =>
              _dragging = _handleAt(details.localPosition.dx - inset, width),
          onHorizontalDragCancel: () => _dragging = null,
          onHorizontalDragStart: (_) {
            if (_dragging != null) widget.onSelect(_dragging!);
          },
          onHorizontalDragUpdate: (details) {
            final index = _dragging;
            if (index != null) {
              widget.onMove(index, ((details.localPosition.dx - inset) / width).clamp(0.0, 1.0));
            }
          },
          onHorizontalDragEnd: (_) {
            if (_dragging != null) widget.onMoveEnd();
            _dragging = null;
          },
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: inset,
                  right: inset,
                  top: (_height - GradientBar._barHeight) / 2,
                  height: GradientBar._barHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outline),
                    ),
                  ),
                ),
                for (var i = 0; i < widget.colors.length; i++)
                  Positioned(
                    key: Key('gradient-stop-$i'),
                    left: widget.offsets[i] * width,
                    top: (_height - GradientBar._handle) / 2,
                    width: GradientBar._handle,
                    height: GradientBar._handle,
                    child: Semantics(
                      button: true,
                      selected: i == widget.selected,
                      label: widget.semanticLabel?.call(i),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.colors[i].withValues(alpha: 1),
                          border: Border.all(
                            color: i == widget.selected ? scheme.onSurface : scheme.outline,
                            width: i == widget.selected ? 3 : 1.5,
                          ),
                          boxShadow: const [BoxShadow(blurRadius: 3, color: Color(0x55000000))],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
