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
import 'colors/gradient_paint.dart';
import 'layers/theme_badge.dart';

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

  /// The stop of the gradient the palette and the hex field paint.
  var _stop = 0;
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
    // A gradient is painted a stop at a time: the palette sets the selected one.
    if (color != null && _firstGradient(svg) != null) {
      return _mapGradients(svg, (gradient) => _editStop(gradient, (s) => s.copyWith(color: color)));
    }
    var out = svg;
    for (final target in _editor.paintTargets) {
      out = _setColor(out, target, color, _property(out, target));
    }
    return out;
  }

  /// The gradient the first target paints with, if it paints with one.
  SvgGradient? _firstGradient(String svg) {
    final targets = _editor.paintTargets;
    if (targets.isEmpty) return null;
    return _gradientOf(svg, targets.first, _property(svg, targets.first));
  }

  SvgGradient? _gradientOf(String svg, ElementPath target, String property) {
    final scheme = widget.scheme;
    return scheme == null
        ? SvgGradientEdit.of(svg, target, property)
        : SvgGradientEdit.ofScheme(svg, target, property, scheme);
  }

  String _writeGradient(
    String svg,
    List<ElementPath> paths,
    String property,
    SvgGradient gradient,
  ) {
    final scheme = widget.scheme;
    return scheme == null
        ? SvgGradientEdit.apply(svg, paths, property, gradient)
        : SvgGradientEdit.applyScheme(svg, paths, property, scheme, gradient);
  }

  /// [svg] with [change] applied to every gradient the targets paint with. A
  /// gradient shared by several targets is changed once for all of them.
  String _mapGradients(String svg, SvgGradient Function(SvgGradient gradient) change) {
    final groups = <String, ({SvgGradient gradient, String property, List<ElementPath> paths})>{};
    for (final target in _editor.paintTargets) {
      final property = _property(svg, target);
      final gradient = _gradientOf(svg, target, property);
      if (gradient == null) continue;
      final group = groups.putIfAbsent(
        '$property|${gradient.id}',
        () => (gradient: gradient, property: property, paths: <ElementPath>[]),
      );
      group.paths.add(target);
    }
    var out = svg;
    for (final group in groups.values) {
      out = _writeGradient(out, group.paths, group.property, change(group.gradient));
    }
    return out;
  }

  /// [gradient] with the selected stop changed by [change].
  SvgGradient _editStop(SvgGradient gradient, GradientStop Function(GradientStop stop) change) =>
      _withStop(gradient, _stop, change);

  /// [gradient] with stop [index] (kept in range) changed by [change].
  SvgGradient _withStop(
    SvgGradient gradient,
    int index,
    GradientStop Function(GradientStop stop) change,
  ) {
    final at = index.clamp(0, gradient.stops.length - 1);
    return gradient.withStop(at, change(gradient.stops[at]));
  }

  /// Puts what is being previewed on the drawing as one undoable step.
  void _commitPreview() => _editor.commit(_editor.displaySvg);

  /// A new stop at [offset] on every gradient of the targets; it is selected.
  void _addStop(SvgGradient gradient, double offset) {
    _stop = gradient.indexForOffset(offset);
    _editor.commit(_mapGradients(_editor.svg, (g) => g.withStopAt(offset)));
  }

  void _removeStop(SvgGradient gradient) {
    final index = _stop.clamp(0, gradient.stops.length - 1);
    _stop = math.max(0, math.min(index, gradient.stops.length - 2));
    _editor.commit(_mapGradients(_editor.svg, (g) => g.withoutStop(index)));
  }

  /// Every target's paint becomes a [kind] gradient: one that fades from its
  /// color if it was plain, else the gradient it has, turned into [kind].
  String _toGradient(String svg, SvgGradientKind kind) {
    final groups = <String, ({String hex, String property, List<ElementPath> paths})>{};
    for (final target in _editor.paintTargets) {
      final property = _property(svg, target);
      final hex = _colorOf(svg, target, property);
      if (hex == null) continue;
      groups
          .putIfAbsent(
            '$property|$hex',
            () => (hex: hex, property: property, paths: <ElementPath>[]),
          )
          .paths
          .add(target);
    }
    var out = svg;
    for (final group in groups.values) {
      out = _writeGradient(
        out,
        group.paths,
        group.property,
        SvgGradient.fromColor(group.hex, kind: kind),
      );
    }
    return _mapGradients(out, (gradient) => gradient.withKind(kind));
  }

  /// Every gradient the targets paint with becomes the plain color of its
  /// first stop.
  String _toSolid(String svg) {
    final scheme = widget.scheme;
    var out = svg;
    for (final target in _editor.paintTargets) {
      final property = _property(out, target);
      final gradient = _gradientOf(out, target, property);
      if (gradient == null || gradient.stops.isEmpty) continue;
      final color = gradient.stops.first.color;
      out = scheme == null
          ? SvgGradientEdit.toSolid(out, [target], property, color)
          : SvgThemeEdit.setPaint(out, target, color, scheme, property);
    }
    return scheme == null ? out : SvgGradientEdit.collectGarbage(out);
  }

  void _setKind(SvgGradientKind? kind) {
    _stop = 0;
    _editor.commit(kind == null ? _toSolid(_editor.svg) : _toGradient(_editor.svg, kind));
  }

  /// [svg] with every target's own color moved by [amount] of [kind]: each
  /// shape keeps its place in the palette, they are not all set to one color.
  /// Shapes with no color (none) are left alone.
  String _adjust(String svg, ColorAdjustment kind, double amount) {
    var out = svg;
    for (final target in _editor.paintTargets) {
      final property = _property(out, target);
      final shown = _colorOf(out, target, property);
      final base = shown == null ? null : colorFromHex(shown);
      if (base == null) continue;
      out = _setColor(out, target, colorToHex(adjustColor(base, kind, amount)), property);
    }
    // Gradients move every one of their stops.
    return _mapGradients(
      out,
      (gradient) => gradient.copyWith(
        stops: [
          for (final stop in gradient.stops)
            stop.copyWith(
              color: colorToHex(
                adjustColor(colorFromHex(stop.color) ?? const Color(0xFF000000), kind, amount),
              ),
            ),
        ],
      ),
    );
  }

  /// [svg] with every target's color replaced by a new harmonious palette:
  /// one mapping for the whole selection, so equal colors stay equal.
  /// Shapes with no color (none) and neutrals are left alone.
  String _shuffle(String svg, ShuffleMode mode) {
    final targets = _editor.paintTargets;
    final shown = <Color>[];
    for (final target in targets) {
      final hex = _colorOf(svg, target, _property(svg, target));
      final color = hex == null ? null : colorFromHex(hex);
      if (color != null) shown.add(color);
      final gradient = _gradientOf(svg, target, _property(svg, target));
      for (final stop in gradient?.stops ?? const <GradientStop>[]) {
        final stopColor = colorFromHex(stop.color);
        if (stopColor != null) shown.add(stopColor);
      }
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
    return _mapGradients(
      out,
      (gradient) => gradient.copyWith(
        stops: [
          for (final stop in gradient.stops)
            stop.copyWith(
              color: switch (colorFromHex(stop.color)) {
                final color? => colorToHex(mapping[colorKey(color)] ?? color),
                _ => stop.color,
              },
            ),
        ],
      ),
    );
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

  /// Which version the paint goes to, with the color [path] has in each.
  Widget _themeStrip(AppLocalizations l10n, SvgColorScheme active, ElementPath path) {
    final svg = _editor.svg;
    final property = _property(svg, path);
    // The highlighted one is painted; the locked one stays as it is until
    // it is tapped, which switches to it.
    return Row(
      key: const Key('colors-theme-strip'),
      children: [
        for (final scheme in SvgColorScheme.values) ...[
          if (scheme != SvgColorScheme.values.first) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ThemeChip(
              key: Key('colors-theme-${scheme.name}'),
              scheme: scheme,
              active: scheme == active,
              color: colorFromHex(SvgThemeEdit.paintFor(svg, path, scheme, property) ?? ''),
              gradient: switch (SvgGradientEdit.ofScheme(svg, path, property, scheme)) {
                final gradient? => flutterGradient(gradient),
                _ => null,
              },
              label: l10n.themeTitle(scheme),
              semanticLabel: scheme == active
                  ? '${l10n.themeTitle(scheme)} · ${l10n.themeEditing}'
                  : l10n.themeSwitchTo(l10n.themeName(scheme)),
              onTap: scheme == active ? null : _editor.toggleTheme,
            ),
          ),
        ],
      ],
    );
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

  /// Solid, linear or radial: what the targets are painted with.
  Widget _kindSelector(AppLocalizations l10n, SvgGradientKind? kind) {
    final current = switch (kind) {
      null => _PaintKind.solid,
      SvgGradientKind.linear => _PaintKind.linear,
      SvgGradientKind.radial => _PaintKind.radial,
    };
    return Semantics(
      container: true,
      label: l10n.paintType,
      child: SegmentedButton<_PaintKind>(
        key: const Key('paint-kind'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: _PaintKind.solid, label: Text(l10n.paintSolid)),
          ButtonSegment(value: _PaintKind.linear, label: Text(l10n.paintLinear)),
          ButtonSegment(value: _PaintKind.radial, label: Text(l10n.paintRadial)),
        ],
        selected: {current},
        onSelectionChanged: (picked) => _setKind(switch (picked.first) {
          _PaintKind.solid => null,
          _PaintKind.linear => SvgGradientKind.linear,
          _PaintKind.radial => SvgGradientKind.radial,
        }),
      ),
    );
  }

  /// The gradient strip with its stops, the angle, the stop's opacity and the
  /// buttons that reverse it or add and remove stops.
  Widget _gradientEditor(AppLocalizations l10n, SvgGradient gradient) {
    final stops = gradient.stops;
    final selected = _stop.clamp(0, stops.length - 1);
    final stop = stops[selected];
    final opacity = (stop.opacity * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientBar(
          colors: [
            for (final s in stops)
              (colorFromHex(s.color) ?? Colors.black).withValues(alpha: s.opacity),
          ],
          offsets: [for (final s in stops) s.offset],
          selected: selected,
          semanticLabel: (i) => l10n.gradientStop(i + 1, stops[i].color),
          onSelect: (i) => setState(() => _stop = i),
          onMove: (i, offset) => _editor.preview(
            _mapGradients(_editor.svg, (g) => _withStop(g, i, (s) => s.copyWith(offset: offset))),
          ),
          onMoveEnd: _commitPreview,
          onAdd: (offset) => _addStop(gradient, offset),
        ),
        // Right under the strip, since these act on its stops: the discreet
        // ones first, the one used most (a new stop) filled.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: l10n.gradientReverseTip,
                  child: OutlinedButton.icon(
                    key: const Key('gradient-reverse'),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: _actionLabel(l10n.gradientReverse),
                    onPressed: () => _editor.commit(_mapGradients(_editor.svg, (g) => g.reversed)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Tooltip(
                  message: l10n.gradientRemoveStopTip,
                  child: OutlinedButton.icon(
                    key: const Key('gradient-remove'),
                    icon: const Icon(Icons.remove_rounded),
                    label: _actionLabel(l10n.gradientRemoveStop),
                    // A gradient keeps at least two stops.
                    onPressed: stops.length > 2 ? () => _removeStop(gradient) : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Tooltip(
                  message: l10n.gradientAddStopTip,
                  child: FilledButton.icon(
                    key: const Key('gradient-add'),
                    icon: const Icon(Icons.add_rounded),
                    label: _actionLabel(l10n.gradientAddStop),
                    onPressed: () => _addStop(
                      gradient,
                      selected < stops.length - 1
                          ? (stop.offset + stops[selected + 1].offset) / 2
                          : (stops[selected - 1].offset + stop.offset) / 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (gradient.isLinear) ...[
          Text(l10n.gradientAngle(gradient.angle.round().toString())),
          Slider(
            key: const Key('gradient-angle'),
            max: 360,
            value: gradient.angle.clamp(0, 360),
            onChanged: (degrees) => _editor.preview(
              _mapGradients(_editor.svg, (g) => g.isLinear ? g.withAngle(degrees) : g),
            ),
            onChangeEnd: (_) => _commitPreview(),
          ),
        ],
        Text(l10n.gradientOpacity('$opacity')),
        Slider(
          key: const Key('gradient-opacity'),
          max: 100,
          value: opacity.toDouble(),
          onChanged: (percent) => _editor.preview(
            _mapGradients(
              _editor.svg,
              (g) => _editStop(g, (s) => s.copyWith(opacity: percent / 100)),
            ),
          ),
          onChangeEnd: (_) => _commitPreview(),
        ),
      ],
    );
  }

  Text _actionLabel(String text) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

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
    final property = _property(_editor.svg, path);
    final gradient = _gradientOf(_editor.svg, path, property);
    if (gradient != null) _stop = _stop.clamp(0, gradient.stops.length - 1);
    // With a gradient the palette and the hex field edit the selected stop.
    final hex = gradient?.stops[_stop].color ?? _colorOf(_editor.svg, path, property);
    String apply(String svg, String? color) => _paint(svg, color);

    final scheme = widget.scheme;
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
        if (scheme != null) _themeStrip(l10n, scheme, path),
        _kindSelector(l10n, gradient?.kind),
        if (gradient != null)
          // What the drag is showing, so the handles follow the finger.
          _gradientEditor(
            l10n,
            _gradientOf(_editor.displaySvg, path, _property(_editor.displaySvg, path)) ?? gradient,
          ),
        _presetPalette(
          l10n,
          colorFromHex(hex ?? '') ?? Theme.of(context).colorScheme.primary,
          preview: (to) => _editor.preview(apply(_editor.svg, to)),
          commit: (to) => _editor.commit(apply(_editor.svg, to)),
        ),
        HslColorEditor(
          key: ValueKey('paint-$path-$_stop-$hex'),
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

/// What the Colors tab paints a layer with.
enum _PaintKind { solid, linear, radial }

/// The two versions of a light/dark file over the palette: the one being
/// painted (highlighted, the only one that changes) and the other, which a tap
/// switches to. Each shows the color [path] has there.
class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    super.key,
    required this.scheme,
    required this.active,
    required this.color,
    required this.label,
    required this.semanticLabel,
    this.gradient,
    this.onTap,
  });

  final SvgColorScheme scheme;
  final bool active;
  final Color? color;

  /// What the version paints with when that is a gradient (then [color] is null).
  final Gradient? gradient;
  final String label;

  /// Says which one is being edited, or that a tap switches to it.
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mark = themeColor(context, scheme, active: active);
    return Semantics(
      button: onTap != null,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active ? colors.primary.withValues(alpha: .1) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? colors.primary.withValues(alpha: .7) : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(themeIcon(scheme), size: 18, color: mark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: active ? FontWeight.w700 : null),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    gradient: gradient,
                    border: Border.all(color: colors.outline),
                  ),
                  child: color == null && gradient == null
                      ? const Icon(Icons.block_rounded, size: 12)
                      : null,
                ),
                if (!active) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.lock_outline_rounded, size: 14, color: mark),
                ],
              ],
            ),
          ),
        ),
      ),
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
