import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Adds shapes and text centered on the canvas.
class InsertPanel extends StatefulWidget {
  const InsertPanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<InsertPanel> createState() => _InsertPanelState();
}

class _InsertPanelState extends State<InsertPanel> {
  var _kind = SvgShapeKind.rectangle;
  Color? _color;
  var _size = 30.0;
  var _picker = _ColorPicker.none;
  TextEditingController? _text;
  final _hex = TextEditingController();

  static const _quickColors = [
    Color(0xFF1E7BFF),
    Color(0xFFA04BFF),
    Color(0xFFFF4D8D),
    Color(0xFF16B9D8),
    Color(0xFFFF8A1F),
    Color(0xFF22C55E),
    Color(0xFFFFFFFF),
  ];

  static IconData _icon(SvgShapeKind kind) => switch (kind) {
    SvgShapeKind.rectangle => Icons.crop_square_rounded,
    SvgShapeKind.circle => Icons.circle_outlined,
    SvgShapeKind.ellipse => Icons.panorama_fish_eye_rounded,
    SvgShapeKind.line => Icons.horizontal_rule_rounded,
    SvgShapeKind.star => Icons.star_outline_rounded,
    SvgShapeKind.text => Icons.text_fields_rounded,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= TextEditingController(text: context.l10n.defaultText);
  }

  @override
  void dispose() {
    _text?.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _togglePicker(_ColorPicker picker) =>
      setState(() => _picker = _picker == picker ? _ColorPicker.none : picker);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = [for (final hex in widget.editor.palette) colorFromHex(hex)!];
    final color = _color ?? Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.add_box_outlined,
          title: l10n.insertTitle,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in SvgShapeKind.values)
                  ChoiceChip(
                    avatar: Icon(_icon(kind), size: 18),
                    label: Text(l10n.shape(kind)),
                    selected: kind == _kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            Text(l10n.color),
            ColorPaletteGrid(
              key: const Key('insert-colors'),
              colors: _quickColors,
              size: 36,
              selected: color,
              onSelected: (value) => setState(() {
                _color = value;
                _picker = _ColorPicker.none;
              }),
              trailing: [
                _ToolDot(
                  key: const Key('insert-eyedropper'),
                  icon: Icons.colorize_rounded,
                  label: l10n.eyedropper,
                  selected: _picker == _ColorPicker.drawing,
                  onTap: () => _togglePicker(_ColorPicker.drawing),
                ),
                ColorDot(
                  key: const Key('insert-custom-color'),
                  color: color,
                  size: 36,
                  selected: _picker == _ColorPicker.custom,
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
                    _hex.text = colorToHex(color);
                    _togglePicker(_ColorPicker.custom);
                  },
                ),
              ],
            ),
            if (_picker == _ColorPicker.drawing)
              palette.isEmpty
                  ? Text(l10n.paletteEmpty)
                  : ColorPaletteGrid(
                      key: const Key('insert-drawing-colors'),
                      colors: palette,
                      size: 32,
                      selected: color,
                      onSelected: (value) => setState(() => _color = value),
                    ),
            if (_picker == _ColorPicker.custom) ...[
              ColorAreaPicker(
                key: const Key('insert-color-area'),
                color: color,
                onChanged: (value) => setState(() {
                  _color = value;
                  _hex.text = colorToHex(value);
                }),
              ),
              TextField(
                key: const Key('insert-hex'),
                controller: _hex,
                decoration: InputDecoration(labelText: l10n.hex),
                onChanged: (value) {
                  final parsed = colorFromHex(value);
                  if (parsed != null) setState(() => _color = parsed);
                },
                onSubmitted: (value) {
                  final parsed = colorFromHex(value);
                  if (parsed == null) _hex.text = colorToHex(color);
                },
              ),
            ],
            SliderField(
              label: l10n.shapeSize,
              value: _size,
              min: 5,
              max: 100,
              unit: '%',
              onChanged: (v) => setState(() => _size = v.roundToDouble()),
            ),
            if (_kind == SvgShapeKind.text)
              TextField(
                controller: _text,
                decoration: InputDecoration(labelText: l10n.textContent),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('insert-shape'),
                onPressed: () => widget.editor.apply(
                  SvgInsertEdit.insert(
                    widget.editor.svg,
                    _kind,
                    color: colorToHex(color),
                    size: _size / 100,
                    text: _text!.text,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.insertAction),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ColorPicker { none, drawing, custom }

/// Round button that sits among the color swatches but opens a picker.
class _ToolDot extends StatelessWidget {
  const _ToolDot({
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
