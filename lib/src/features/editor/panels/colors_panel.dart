import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../color_adjust.dart';
import '../color_presets.dart';
import '../color_shuffle.dart';
import '../editor_controller.dart';
import 'colors/color_adjuster.dart';

/// Paints the selected layers (all of them at once when several are ticked).
/// Colors are picked from a palette of ready-made colors and fine-tuned with
/// hue/saturation/lightness sliders.
class ColorsPanel extends StatefulWidget {
  const ColorsPanel({super.key, required this.editor, this.scheme});

  final EditorController editor;

  /// The light/dark version being edited (the change goes to that version
  /// only); null for a file without such versions.
  final SvgColorScheme? scheme;

  @override
  State<ColorsPanel> createState() => _ColorsPanelState();
}

class _ColorsPanelState extends State<ColorsPanel> {
  var _custom = false;
  final _random = math.Random();

  /// The drawing before the ruler first changed anything, so its changes can
  /// be put back; dropped when something else is edited or the selection moves.
  String? _adjustBase;
  String? _adjustResult;
  List<ElementPath> _adjustTargets = const [];

  /// What each ruler shows now: the total of that adjustment since
  /// [_adjustBase], in the order they were first used. Every result is worked
  /// out again from [_adjustBase], so an adjustment can be taken out alone.
  final _adjustAmounts = <ColorAdjustment, double>{};

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

  /// What painting [target] sets: its fill, except that an outline-only shape
  /// (fill none, with a stroke: an antenna, a smile) has its stroke painted,
  /// since a fill would turn the line into a blob.
  String _property(String svg, ElementPath target) {
    final scheme = widget.scheme;
    // What the shape shows, so a fill or stroke set on its group counts.
    final fill = scheme == null
        ? SvgPaintEdit.inherited(svg, target, 'fill')
        : SvgThemeEdit.fillFor(svg, target, scheme);
    if (fill != 'none') return 'fill';
    final stroke = scheme == null
        ? SvgPaintEdit.inherited(svg, target, 'stroke')
        : SvgThemeEdit.paintFor(svg, target, scheme, 'stroke');
    return stroke != null && stroke != 'none' ? 'stroke' : 'fill';
  }

  /// The `#RRGGBB` [property] of [target] as it shows, or null (no plain color).
  String? _colorOf(String svg, ElementPath target, String property) {
    final scheme = widget.scheme;
    final String? value;
    if (scheme != null) {
      value = SvgThemeEdit.paintFor(svg, target, scheme, property);
    } else {
      final paint = SvgPaintEdit.read(svg, target);
      value = property == 'stroke' ? paint.strokeColor : paint.fillColor;
    }
    return value != null && value.startsWith('#') ? value : null;
  }

  String _setColor(String svg, ElementPath target, String? color, String property) {
    final scheme = widget.scheme;
    if (scheme != null && color != null) {
      return SvgThemeEdit.setPaint(svg, target, color, scheme, property);
    }
    return property == 'stroke'
        ? SvgPaintEdit.setStroke(svg, target, color)
        : SvgPaintEdit.setFill(svg, target, color);
  }

  /// Paints every target: fills get the color, and so do the strokes of
  /// outline-only shapes, so everything ends up the same color.
  String _paint(String svg, String? color) {
    var out = svg;
    for (final target in _editor.paintTargets) {
      out = _setColor(out, target, color, _property(out, target));
    }
    return out;
  }

  /// [svg] with every target's own color moved by [amount] of [kind]: each
  /// shape keeps its place in the palette, they are not all set to one color.
  /// Shapes with no plain fill color (a gradient, none) are left alone.
  String _adjust(String svg, ColorAdjustment kind, double amount) {
    var out = svg;
    for (final target in _editor.paintTargets) {
      final property = _property(out, target);
      final shown = _colorOf(out, target, property);
      final base = shown == null ? null : colorFromHex(shown);
      if (base == null) continue;
      out = _setColor(out, target, colorToHex(adjustColor(base, kind, amount)), property);
    }
    return out;
  }

  /// [svg] with every target's color replaced by a new harmonious palette:
  /// one mapping for the whole selection, so equal colors stay equal.
  /// Shapes with no plain color (a gradient, none) and neutrals are left alone.
  String _shuffle(String svg, ShuffleMode mode) {
    final targets = _editor.paintTargets;
    final shown = <Color>[];
    for (final target in targets) {
      final hex = _colorOf(svg, target, _property(svg, target));
      final color = hex == null ? null : colorFromHex(hex);
      if (color != null) shown.add(color);
    }
    final mapping = shuffleColors(shown, mode, _random);
    if (mapping.isEmpty) return svg;
    var out = svg;
    for (final target in targets) {
      final property = _property(out, target);
      final hex = _colorOf(out, target, property);
      final color = hex == null ? null : colorFromHex(hex);
      final to = color == null ? null : mapping[colorKey(color)];
      if (to != null) out = _setColor(out, target, colorToHex(to), property);
    }
    return out;
  }

  /// [base] with every adjustment of [amounts] applied, in order.
  String _adjustAll(String base, Map<ColorAdjustment, double> amounts) {
    var svg = base;
    for (final entry in amounts.entries) {
      svg = _adjust(svg, entry.key, entry.value);
    }
    return svg;
  }

  /// [kind] set to [amount] (0 takes it out) with the other adjustments kept.
  Map<ColorAdjustment, double> _withAmount(ColorAdjustment kind, double amount) {
    final out = Map.of(_adjustAmounts);
    if (amount == 0) {
      out.remove(kind);
    } else {
      out[kind] = amount;
    }
    return out;
  }

  /// Puts [amounts] on the drawing as one undoable step.
  void _commitAdjust(Map<ColorAdjustment, double> amounts) {
    final base = _adjustBase ?? _editor.svg;
    _adjustBase = amounts.isEmpty ? null : base;
    _adjustAmounts
      ..clear()
      ..addAll(amounts);
    _editor.commit(_adjustAll(base, amounts));
    _adjustResult = _editor.svg;
    _adjustTargets = _editor.paintTargets;
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
    final hasSelection = _editor.paintTargets.isNotEmpty;
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
    // Another edit, undo or a new selection: the ruler's changes are no
    // longer the last thing done, so there is nothing to put back.
    if (_adjustBase != null &&
        (_editor.svg != _adjustResult || !listEquals(_editor.paintTargets, _adjustTargets))) {
      _adjustBase = null;
      _adjustAmounts.clear();
    }
    // Every ticked layer takes the change; the card shows the first one's paint.
    final targets = _editor.paintTargets;
    final path = targets.first;
    final hex = _colorOf(_editor.svg, path, _property(_editor.svg, path));
    String apply(String svg, String? color) => _paint(svg, color);

    return SectionCard(
      icon: Icons.format_color_fill_rounded,
      title: targets.length > 1 || _editor.selectedLayer == null
          ? l10n.multiSelectCount(targets.length)
          : l10n.layerPaint(l10n.layerLabel(_editor.selectedLayer!, _editor.layers)),
      trailing: _ShuffleButton(
        key: const Key('shuffle-colors'),
        label: l10n.shuffleColors,
        names: {
          ShuffleMode.surprise: l10n.shuffleSurprise,
          ShuffleMode.goldenAngle: l10n.shuffleGoldenAngle,
          ShuffleMode.cosine: l10n.shuffleCosine,
          ShuffleMode.classic: l10n.shuffleClassic,
        },
        onSelected: (mode) => _editor.commit(_shuffle(_editor.svg, mode)),
      ),
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
          showSliders: false,
          onChanged: (color) => _editor.preview(apply(_editor.svg, colorToHex(color))),
          onChangeEnd: (color) => _editor.commit(apply(_editor.svg, colorToHex(color))),
        ),
        ColorAdjuster(
          amounts: Map.of(_adjustAmounts),
          onPreview: (kind, amount) =>
              _editor.preview(_adjustAll(_adjustBase ?? _editor.svg, _withAmount(kind, amount))),
          onCommit: (kind, amount) {
            if (amount == 0 && !_adjustAmounts.containsKey(kind)) return;
            _commitAdjust(_withAmount(kind, amount));
          },
          onReset: _adjustBase == null ? null : () => _commitAdjust(const {}),
          onResetKind: (kind) {
            if (_adjustAmounts.containsKey(kind)) _commitAdjust(_withAmount(kind, 0));
          },
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

/// The dice in the card header: opens the ways to draw a new palette.
class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({
    super.key,
    required this.label,
    required this.names,
    required this.onSelected,
  });

  final String label;
  final Map<ShuffleMode, String> names;
  final ValueChanged<ShuffleMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShuffleMode>(
      tooltip: label,
      icon: const Icon(Icons.casino_rounded),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in names.entries)
          PopupMenuItem(
            key: Key('shuffle-${entry.key.name}'),
            value: entry.key,
            child: Text(entry.value),
          ),
      ],
    );
  }
}
