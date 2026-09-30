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
    final scheme = Theme.of(context).colorScheme;
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
          final selected = widget.selected?.toARGB32() == color.toARGB32();
          final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black;
          return Semantics(
            button: true,
            selected: selected,
            label: widget.semanticLabel?.call(color) ?? colorToHex(color),
            child: InkResponse(
              onTap: () => widget.onSelected(color),
              radius: widget.size / 2 + 6,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outline,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 18, color: onColor) : null,
              ),
            ),
          );
        },
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
