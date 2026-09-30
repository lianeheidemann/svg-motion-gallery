import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

enum _ColorScope { document, layer }

enum _PaintTarget { fill, stroke }

/// Recolors the whole document (palette) or paints the selected layer.
/// Colors are picked with hue/saturation/lightness sliders.
class ColorsPanel extends StatefulWidget {
  const ColorsPanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<ColorsPanel> createState() => _ColorsPanelState();
}

class _ColorsPanelState extends State<ColorsPanel> {
  _ColorScope? _scope;
  _PaintTarget _target = _PaintTarget.fill;
  String? _from;
  double? _liveStrokeWidth;

  EditorController get _editor => widget.editor;

  HslLabels _labels(AppLocalizations l10n) => HslLabels(
    hue: l10n.hue,
    saturation: l10n.saturation,
    lightness: l10n.lightness,
    hex: l10n.hex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSelection = _editor.selectedLayer != null;
    final scope = hasSelection ? (_scope ?? _ColorScope.layer) : _ColorScope.document;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SegmentedButton<_ColorScope>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _ColorScope.document,
              label: Text(l10n.colorsDocument),
              icon: const Icon(Icons.palette_outlined),
            ),
            ButtonSegment(
              value: _ColorScope.layer,
              enabled: hasSelection,
              label: Text(l10n.colorsLayer),
              icon: const Icon(Icons.format_color_fill_rounded),
            ),
          ],
          selected: {scope},
          onSelectionChanged: (value) => setState(() => _scope = value.single),
        ),
        if (!hasSelection)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.selectLayerHint,
              style: TextStyle(color: GalleryColors.of(context).muted),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (scope == _ColorScope.document) _documentColors(l10n) else _layerColors(l10n),
      ],
    );
  }

  Widget _documentColors(AppLocalizations l10n) {
    final palette = _editor.palette;
    final from = palette.contains(_from) ? _from : null;
    return SectionCard(
      icon: Icons.palette_outlined,
      title: l10n.paletteTitle,
      children: [
        if (palette.isEmpty)
          Text(l10n.paletteEmpty)
        else ...[
          Text(l10n.paletteHint, style: TextStyle(color: GalleryColors.of(context).muted)),
          ColorSwatchPicker(
            colors: [for (final hex in palette) colorFromHex(hex)!],
            selected: from == null ? null : colorFromHex(from),
            onSelected: (color) => setState(() => _from = colorToHex(color)),
          ),
          if (from != null)
            HslColorEditor(
              key: ValueKey('replace-$from'),
              color: colorFromHex(from)!,
              labels: _labels(l10n),
              onChanged: (color) =>
                  _editor.preview(SvgColors.replace(_editor.svg, from, colorToHex(color))),
              onChangeEnd: (color) {
                final to = colorToHex(color);
                _editor.commit(SvgColors.replace(_editor.svg, from, to));
                setState(() => _from = to);
              },
            ),
        ],
      ],
    );
  }

  Widget _layerColors(AppLocalizations l10n) {
    final path = _editor.selection!;
    final paint = SvgPaintEdit.read(_editor.svg, path);
    final isFill = _target == _PaintTarget.fill;
    final raw = isFill ? paint.fill : paint.stroke;
    final hex = isFill ? paint.fillColor : paint.strokeColor;
    String apply(String svg, String? color) =>
        isFill ? SvgPaintEdit.setFill(svg, path, color) : SvgPaintEdit.setStroke(svg, path, color);
    final current = switch (raw) {
      null => l10n.paintInherited,
      'none' => l10n.paintNone,
      final value when value.startsWith('url(') => l10n.paintGradient,
      final value => value,
    };
    return SectionCard(
      icon: Icons.format_color_fill_rounded,
      title: l10n.layerPaint(l10n.layer(_editor.selectedLayer!)),
      children: [
        SegmentedButton<_PaintTarget>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _PaintTarget.fill, label: Text(l10n.fill)),
            ButtonSegment(value: _PaintTarget.stroke, label: Text(l10n.stroke)),
          ],
          selected: {_target},
          onSelectionChanged: (value) => setState(() => _target = value.single),
        ),
        Text(l10n.currentPaint(current)),
        HslColorEditor(
          key: ValueKey('paint-$path-$_target-$hex'),
          color: colorFromHex(hex ?? '') ?? Theme.of(context).colorScheme.primary,
          labels: _labels(l10n),
          onChanged: (color) => _editor.preview(apply(_editor.svg, colorToHex(color))),
          onChangeEnd: (color) => _editor.commit(apply(_editor.svg, colorToHex(color))),
        ),
        if (!isFill)
          SliderField(
            label: l10n.strokeWidth,
            value: (_liveStrokeWidth ?? paint.strokeWidth ?? 1).clamp(0, 50),
            min: 0,
            max: 50,
            fractionDigits: 1,
            onChanged: (v) {
              setState(() => _liveStrokeWidth = v);
              _editor.preview(SvgPaintEdit.setStrokeWidth(_editor.svg, path, v));
            },
            onChangeEnd: (v) {
              _liveStrokeWidth = null;
              _editor.commit(SvgPaintEdit.setStrokeWidth(_editor.svg, path, v));
            },
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: raw == 'none' ? null : () => _editor.commit(apply(_editor.svg, null)),
            icon: const Icon(Icons.format_color_reset_rounded),
            label: Text(isFill ? l10n.removeFill : l10n.removeStroke),
          ),
        ),
      ],
    );
  }
}
