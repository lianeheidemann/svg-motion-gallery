import 'package:flutter/material.dart';

/// Shows [before] on the left and [after] on the right of a divider the finger
/// drags (or taps) sideways, to compare an edit with the original.
class BeforeAfter extends StatefulWidget {
  const BeforeAfter({
    super.key,
    required this.before,
    required this.after,
    required this.beforeLabel,
    required this.afterLabel,
    required this.handleLabel,
  });

  final Widget before;
  final Widget after;
  final String beforeLabel;
  final String afterLabel;
  final String handleLabel;

  @override
  State<BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<BeforeAfter> {
  static const _handle = 44.0;
  var _fraction = .5;

  void _move(double dx, double width) =>
      setState(() => _fraction = (dx / (width <= 0 ? 1 : width)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final x = width * _fraction;
        return GestureDetector(
          key: const Key('before-after'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _move(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, width),
          child: Stack(
            children: [
              Positioned.fill(child: widget.after),
              Positioned.fill(
                child: ClipRect(clipper: _LeftClipper(x), child: widget.before),
              ),
              Positioned(
                left: x - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: IgnorePointer(child: ColoredBox(color: color)),
              ),
              Positioned(
                left: x - _handle / 2,
                top: height / 2 - _handle / 2,
                width: _handle,
                height: _handle,
                child: Semantics(
                  label: widget.handleLabel,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(left: 8, top: 8, child: _Tag(widget.beforeLabel)),
              Positioned(right: 8, top: 8, child: _Tag(widget.afterLabel)),
            ],
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    ),
  );
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper old) => old.x != x;
}
