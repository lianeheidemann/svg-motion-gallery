import 'package:flutter/material.dart';

import 'color_swatch_picker.dart';

/// Wrapping grid of ready-made colors: tap one to choose it. Unlike
/// [ColorSwatchPicker] (one scrolling row) every color is visible at once.
class ColorPaletteGrid extends StatelessWidget {
  const ColorPaletteGrid({
    super.key,
    required this.colors,
    required this.onSelected,
    this.selected,
    this.size = 32,
    this.spacing = 10,
    this.semanticLabel,
    this.trailing = const [],
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;
  final double size;
  final double spacing;

  /// Extra swatches after the colors (e.g. a "custom color" button).
  final List<Widget> trailing;

  /// Builds the accessibility label for a swatch (defaults to its hex).
  final String Function(Color color)? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final color in colors)
          ColorDot(
            color: color,
            size: size,
            selected: selected?.toARGB32() == color.toARGB32(),
            semanticLabel: semanticLabel?.call(color),
            onTap: () => onSelected(color),
          ),
        ...trailing,
      ],
    );
  }
}
