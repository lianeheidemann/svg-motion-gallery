import 'package:flutter/material.dart';

import '../theme/gallery_colors.dart';
import '../theme/tokens.dart';

/// What the preview sits on.
enum StageBackground {
  /// The app's usual stage color (with the editor grid when asked for).
  current,

  /// A light surface, to check how a drawing looks on white-ish pages.
  light,

  /// A near-black surface.
  dark,

  /// Light/grey squares, the usual sign of transparency.
  checkerboard,
}

/// Rounded backdrop for SVG previews with an optional editor grid.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.child,
    this.showGrid = false,
    this.background = StageBackground.current,
    this.borderRadius = AppSpacing.radius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool showGrid;

  /// Grid lines only show on [StageBackground.current].
  final StageBackground background;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = GalleryColors.of(context);
    final color = switch (background) {
      StageBackground.current => colors.stage,
      StageBackground.light => const Color(0xFFF1F4FA),
      StageBackground.dark => const Color(0xFF05070D),
      StageBackground.checkerboard => const Color(0xFFFFFFFF),
    };
    final CustomPainter? painter = switch (background) {
      StageBackground.current => showGrid ? GridPainter(color: colors.stageGrid) : null,
      StageBackground.checkerboard => const CheckerboardPainter(),
      _ => null,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: CustomPaint(
          painter: painter,
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

/// Grey and white squares: what an image editor shows behind transparency.
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter({
    this.size = 12,
    this.light = const Color(0xFFFFFFFF),
    this.dark = const Color(0xFFD5DAE4),
  });

  /// Side of one square.
  final double size;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size area) {
    canvas.drawRect(Offset.zero & area, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var row = 0; row * size < area.height; row++) {
      for (var column = row.isEven ? 1 : 0; column * size < area.width; column += 2) {
        canvas.drawRect(Rect.fromLTWH(column * size, row * size, size, size), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter old) =>
      old.size != size || old.light != light || old.dark != dark;
}
