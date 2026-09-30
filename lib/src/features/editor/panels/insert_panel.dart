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
  TextEditingController? _text;

  static const _quickColors = [
    Color(0xFF1E7BFF),
    Color(0xFFA04BFF),
    Color(0xFFFF4D8D),
    Color(0xFF16B9D8),
    Color(0xFFFF8A1F),
    Color(0xFF22C55E),
    Color(0xFFFFFFFF),
    Color(0xFF0E1628),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = [for (final hex in widget.editor.palette.take(8)) colorFromHex(hex)!];
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
            ColorSwatchPicker(
              colors: {..._quickColors, ...palette}.toList(),
              selected: color,
              onSelected: (value) => setState(() => _color = value),
            ),
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
