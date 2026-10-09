import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../color_presets.dart';
import '../editor_controller.dart';

/// Paints the selected layers (all of them at once when several are ticked).
/// Colors are picked from a palette of ready-made colors and fine-tuned with
/// hue/saturation/lightness sliders.
class ColorsPanel extends StatefulWidget {
  const ColorsPanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<ColorsPanel> createState() => _ColorsPanelState();
}

class _ColorsPanelState extends State<ColorsPanel> {
  var _custom = false;

  EditorController get _editor => widget.editor;

  @override
  void initState() {
    super.initState();
    _editor.onColorPicked = _picked;
  }

  @override
  void dispose() {
    _editor
      ..onColorPicked = null
      ..eyedropper = false;
    super.dispose();
  }

  /// The eyedropper found [hex] on the stage: it becomes the paint.
  void _picked(String hex) {
    _editor
      ..eyedropper = false
      ..commit(_paint(_editor.svg, hex));
  }

  /// Paints every target. Outline-only shapes (fill none) stay that way when
  /// several are painted.
  String _paint(String svg, String? color) {
    final targets = _editor.editTargets;
    var out = svg;
    for (final target in targets) {
      if (targets.length > 1 && SvgPaintEdit.read(out, target).fill == 'none') continue;
      out = SvgPaintEdit.setFill(out, target, color);
    }
    return out;
  }

  HslLabels _labels(AppLocalizations l10n) => HslLabels(
    hue: l10n.hue,
    saturation: l10n.saturation,
    lightness: l10n.lightness,
    hex: l10n.hex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSelection = _editor.editTargets.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (hasSelection)
          _layerColors(l10n)
        else
          SectionCard(
            icon: Icons.format_color_fill_rounded,
            children: [
              Text(l10n.selectLayerHint, style: TextStyle(color: GalleryColors.of(context).muted)),
            ],
          ),
      ],
    );
  }

  /// Ready-made colors plus a rainbow swatch that opens a free color picker.
  /// Both apply through [commit]; dragging in the picker calls [preview].
  Widget _presetPalette(
    AppLocalizations l10n,
    Color current, {
    required ValueChanged<String> preview,
    required ValueChanged<String> commit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.presetPalette, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        ColorPaletteGrid(
          key: const Key('preset-palette'),
          colors: presetColors,
          size: 24,
          spacing: 6,
          selected: current,
          onSelected: (color) => commit(colorToHex(color)),
          trailing: [
            ColorDot(
              key: const Key('custom-color'),
              color: current,
              size: 24,
              selected: _custom,
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
              onTap: () => setState(() => _custom = !_custom),
            ),
            _EyedropperButton(
              key: const Key('eyedropper'),
              active: _editor.eyedropper,
              label: l10n.eyedropper,
              onTap: () => _editor.eyedropper = !_editor.eyedropper,
            ),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: AppSpacing.md),
          ColorAreaPicker(
            key: const Key('color-area'),
            color: current,
            onChanged: (color) => preview(colorToHex(color)),
            onChangeEnd: (color) => commit(colorToHex(color)),
          ),
        ],
      ],
    );
  }

  Widget _layerColors(AppLocalizations l10n) {
    // Every ticked layer takes the change; the card shows the first one's paint.
    final targets = _editor.editTargets;
    final path = targets.first;
    final paint = SvgPaintEdit.read(_editor.svg, path);
    final hex = paint.fillColor;
    String apply(String svg, String? color) => _paint(svg, color);

    return SectionCard(
      icon: Icons.format_color_fill_rounded,
      title: targets.length > 1 || _editor.selectedLayer == null
          ? l10n.multiSelectCount(targets.length)
          : l10n.layerPaint(l10n.layerLabel(_editor.selectedLayer!, _editor.layers)),
      children: [
        _presetPalette(
          l10n,
          colorFromHex(hex ?? '') ?? Theme.of(context).colorScheme.primary,
          preview: (to) => _editor.preview(apply(_editor.svg, to)),
          commit: (to) => _editor.commit(apply(_editor.svg, to)),
        ),
        HslColorEditor(
          key: ValueKey('paint-$path-$hex'),
          color: colorFromHex(hex ?? '') ?? Theme.of(context).colorScheme.primary,
          labels: _labels(l10n),
          onChanged: (color) => _editor.preview(apply(_editor.svg, colorToHex(color))),
          onChangeEnd: (color) => _editor.commit(apply(_editor.svg, colorToHex(color))),
        ),
      ],
    );
  }
}

/// The pipette next to the palette: tap it, then tap the drawing.
class _EyedropperButton extends StatelessWidget {
  const _EyedropperButton({
    super.key,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? scheme.primary : null,
              border: Border.all(color: active ? scheme.primary : scheme.outline, width: 1.5),
            ),
            child: Icon(
              Icons.colorize_rounded,
              size: 14,
              color: active ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
