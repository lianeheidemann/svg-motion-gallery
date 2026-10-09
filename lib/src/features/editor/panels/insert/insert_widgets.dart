import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

/// Which color picker is open under a row of swatches.
enum InsertColorPicker { none, drawing, custom }

/// Round button that sits among the color swatches but opens a picker.
class ToolDot extends StatelessWidget {
  const ToolDot({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          child: Icon(icon, size: 18, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// An oval outline, so Ellipse does not look like Circle.
class EllipseIcon extends StatelessWidget {
  const EllipseIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return CustomPaint(size: const Size(20, 18), painter: _EllipsePainter(color));
  }
}

class _EllipsePainter extends CustomPainter {
  const _EllipsePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(center: size.center(Offset.zero), width: size.width - 2, height: 11),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_EllipsePainter old) => old.color != color;
}

/// The ready-made colors at the start of each color row.
const insertQuickColors = [
  Color(0xFF1E7BFF),
  Color(0xFFA04BFF),
  Color(0xFFFF4D8D),
  Color(0xFF16B9D8),
  Color(0xFFFF8A1F),
  Color(0xFF22C55E),
  Color(0xFFFFFFFF),
];

/// A row of swatches plus the eyedropper and free picker, for one color of
/// the Insert and Text tabs.
List<Widget> insertColorSection(
  BuildContext context, {
  required String label,
  required String keys,
  required Color color,
  required InsertColorPicker picker,
  required TextEditingController hex,
  required void Function(InsertColorPicker) togglePicker,
  required void Function(Color value, {bool live}) pick,
  required VoidCallback closePicker,
  required List<Color> palette,
}) {
  final l10n = context.l10n;
  return [
    Text(label),
    ColorPaletteGrid(
      key: Key('$keys-colors'),
      colors: insertQuickColors,
      size: 36,
      selected: color,
      onSelected: (value) {
        closePicker();
        pick(value);
      },
      trailing: [
        ToolDot(
          key: Key('$keys-eyedropper'),
          icon: Icons.colorize_rounded,
          label: l10n.eyedropper,
          selected: picker == InsertColorPicker.drawing,
          onTap: () => togglePicker(InsertColorPicker.drawing),
        ),
        ColorDot(
          key: Key('$keys-custom-color'),
          color: color,
          size: 36,
          selected: picker == InsertColorPicker.custom,
          semanticLabel: l10n.customColor,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          onTap: () {
            hex.text = colorToHex(color);
            togglePicker(InsertColorPicker.custom);
          },
        ),
      ],
    ),
    if (picker == InsertColorPicker.drawing)
      palette.isEmpty
          ? Text(l10n.paletteEmpty)
          : ColorPaletteGrid(
              key: Key('$keys-drawing-colors'),
              colors: palette,
              size: 32,
              selected: color,
              onSelected: pick,
            ),
    if (picker == InsertColorPicker.custom) ...[
      ColorAreaPicker(
        key: Key('$keys-color-area'),
        color: color,
        onChanged: (value) {
          hex.text = colorToHex(value);
          pick(value, live: true);
        },
        onChangeEnd: pick,
      ),
      TextField(
        key: Key('$keys-hex'),
        controller: hex,
        decoration: InputDecoration(labelText: l10n.hex),
        onChanged: (value) {
          final parsed = colorFromHex(value);
          if (parsed == null) return;
          // A whole color (#RRGGBB) is one undoable step; a partial one
          // only previews.
          final whole = value.replaceAll('#', '').length >= 6;
          pick(parsed, live: !whole);
        },
        onSubmitted: (value) {
          final parsed = colorFromHex(value);
          if (parsed == null) hex.text = colorToHex(color);
        },
      ),
    ],
  ];
}
