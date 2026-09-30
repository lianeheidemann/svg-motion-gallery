import 'package:flutter/material.dart';

import '../theme/gallery_colors.dart';
import '../theme/tokens.dart';

/// Rounded backdrop for SVG previews with an optional editor grid.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.child,
    this.showGrid = false,
    this.borderRadius = AppSpacing.radius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool showGrid;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = GalleryColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.stage),
        child: CustomPaint(
          painter: showGrid ? GridPainter(color: colors.stageGrid) : null,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Paints an evenly spaced grid (the editor canvas background).
class GridPainter extends CustomPainter {
  const GridPainter({required this.color, this.spacing = 24});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
