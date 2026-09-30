import 'package:flutter/material.dart';

/// Horizontally scrollable row of round color swatches with a ring around the
/// selected one.
class ColorSwatchPicker extends StatefulWidget {
  const ColorSwatchPicker({
    super.key,
    required this.colors,
    required this.onSelected,
    this.selected,
    this.size = 36,
    this.semanticLabel,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;
  final double size;

  /// Builds the accessibility label for a swatch (defaults to its hex).
  final String Function(Color color)? semanticLabel;

  @override
  State<ColorSwatchPicker> createState() => _ColorSwatchPickerState();
}

class _ColorSwatchPickerState extends State<ColorSwatchPicker> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size + 18,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
        itemCount: widget.colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final color = widget.colors[index];
          return ColorDot(
            color: color,
            size: widget.size,
            selected: widget.selected?.toARGB32() == color.toARGB32(),
            semanticLabel: widget.semanticLabel?.call(color),
            onTap: () => widget.onSelected(color),
          );
        },
      ),
    );
  }
}

/// One round color swatch with a ring (and a check mark) when [selected].
/// Shared by [ColorSwatchPicker] and `ColorPaletteGrid`.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.size = 36,
    this.semanticLabel,
    this.gradient,
  });

  final Color color;

  /// Paints this instead of the flat [color] (e.g. the rainbow "custom" swatch).
  final Gradient? gradient;
  final VoidCallback onTap;
  final bool selected;
  final double size;

  /// Accessibility label (defaults to the hex code).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? colorToHex(color),
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 6,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected ? Icon(Icons.check_rounded, size: size / 2, color: onColor) : null,
        ),
      ),
    );
  }
}

/// `#RRGGBB` for [color] (alpha ignored).
String colorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Parses `#RGB` / `#RRGGBB` (with or without `#`), or returns null.
Color? colorFromHex(String hex) {
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 3) value = value.split('').map((c) => '$c$c').join();
  if (value.length != 6) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
