import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Adds shapes and text centered on the canvas.
class InsertPanel extends StatefulWidget {
  const InsertPanel({super.key, required this.editor, this.text = false});

  final EditorController editor;

  /// Inserts text instead of shapes (its own tab).
  final bool text;

  @override
  State<InsertPanel> createState() => _InsertPanelState();
}

class _InsertPanelState extends State<InsertPanel> {
  late var _kind = widget.text ? SvgShapeKind.text : SvgShapeKind.rectangle;
  Color? _color;

  /// True while a color is being dragged in the free picker, so the row keeps
  /// showing that color instead of the one stored in the file.
  var _picking = false;
  var _size = 30.0;

  /// Outline of new shapes, as a percentage of the smaller canvas side.
  var _stroke = 1.5;

  /// Whether new shapes are filled; they are hollow (outline only) by default.
  var _filled = false;
  double? _liveScale;
  double? _liveStroke;
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

  static Widget _icon(SvgShapeKind kind) => switch (kind) {
    SvgShapeKind.rectangle => const Icon(Icons.crop_square_rounded, size: 18),
    SvgShapeKind.circle => const Icon(Icons.circle_outlined, size: 18),
    // No stock icon is an oval: a circle would look like the one above.
    SvgShapeKind.ellipse => const _EllipseIcon(),
    SvgShapeKind.line => const Icon(Icons.horizontal_rule_rounded, size: 18),
    SvgShapeKind.star => const Icon(Icons.star_outline_rounded, size: 18),
    SvgShapeKind.text => const Icon(Icons.text_fields_rounded, size: 18),
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

  EditorController get editor => widget.editor;

  SvgEditResult _scaled(ElementPath path, double scale) => SvgTransformEdit.apply(
    editor.svg,
    path,
    SvgTransformEdit.read(editor.svg, path).copyWith(scale: scale),
  );

  /// The smaller side of the canvas: outlines are a percentage of it, so the
  /// same slider suits a 24-unit icon and a 1000-unit drawing.
  double get _side {
    final canvas = editor.metadata.canvas;
    return math.min(canvas.width, canvas.height);
  }

  /// Sets the outline [percent] (of the canvas side); the first time, the
  /// outline also gets a color.
  String _outlined(ElementPath path, double percent, Color fallback) {
    final width = percent / 100 * _side;
    var svg = editor.svg;
    final paint = SvgPaintEdit.read(svg, path);
    final hasStroke = paint.stroke != null && paint.stroke != 'none';
    if (width > 0 && !hasStroke) svg = SvgPaintEdit.setStroke(svg, path, colorToHex(fallback));
    return SvgPaintEdit.setStrokeWidth(svg, path, width);
  }

  SvgLayer? _layerAt(ElementPath path) =>
      editor.layers.where((layer) => layer.path == path).firstOrNull;

  /// Closed shapes can be filled or hollow; lines and text cannot.
  bool _fillable(ElementPath path) =>
      const {'rect', 'circle', 'ellipse', 'polygon', 'path'}.contains(_layerAt(path)?.tag);

  bool _isFilled(ElementPath path) {
    final fill = SvgPaintEdit.read(editor.svg, path).fill;
    return fill != 'none' && fill != 'transparent';
  }

  /// Fills the shape with its outline color, or hollows it (keeping an
  /// outline so it does not disappear).
  void _setFilled(ElementPath path, bool filled, Color fallback) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final own = paint.strokeColor ?? paint.fillColor ?? colorToHex(fallback);
    var svg = editor.svg;
    if (filled) {
      svg = SvgPaintEdit.setFill(svg, path, own);
    } else {
      svg = SvgPaintEdit.setFill(svg, path, 'none');
      if (paint.stroke == null || paint.stroke == 'none') {
        svg = SvgPaintEdit.setStroke(svg, path, own);
      }
      if ((paint.strokeWidth ?? 0) <= 0) {
        svg = SvgPaintEdit.setStrokeWidth(svg, path, _side * 0.015);
      }
    }
    editor.commit(svg);
  }

  /// The color of a shape: its outline, else its fill.
  Color? _shapeColor(ElementPath path) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final stroke = paint.stroke == 'none' ? null : paint.strokeColor;
    final fill = paint.fill == 'none' ? null : paint.fillColor;
    final hex = stroke ?? fill;
    return hex == null ? null : colorFromHex(hex);
  }

  /// [svg] with the shape at [path] painted [color]: the fill when it has one
  /// (filled shapes, text) and the outline when it has one (hollow shapes,
  /// lines).
  String _recolor(String svg, ElementPath path, Color color) {
    final paint = SvgPaintEdit.read(svg, path);
    final hex = colorToHex(color);
    final hasStroke = paint.stroke != null && paint.stroke != 'none';
    final hasFill = paint.fill != 'none' && (paint.fill != null || !hasStroke);
    var result = svg;
    if (hasFill) result = SvgPaintEdit.setFill(result, path, hex);
    if (hasStroke) result = SvgPaintEdit.setStroke(result, path, hex);
    return result;
  }

  /// A color was picked: it is the color of the next shapes, and it repaints
  /// the selected shape (right away when [live], as one undoable step when not).
  void _pick(Color value, ElementPath? shape, {bool live = false}) {
    setState(() {
      _color = value;
      _picking = live;
    });
    if (shape == null) return;
    final svg = _recolor(editor.svg, shape, value);
    live ? editor.preview(svg) : editor.commit(svg);
  }

  void _togglePicker(_ColorPicker picker) =>
      setState(() => _picker = _picker == picker ? _ColorPicker.none : picker);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = [for (final hex in editor.palette) colorFromHex(hex)!];
    final selection = editor.selection;
    final selectedShape =
        selection != null && SvgHitTest.movables(editor.svg).any((m) => m.path == selection)
        ? selection
        : null;
    // With a shape selected the row shows (and changes) that shape's color.
    final color =
        (selectedShape != null && !_picking ? _shapeColor(selectedShape) : null) ??
        _color ??
        Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.add_box_outlined,
          title: widget.text ? l10n.insertTextTitle : l10n.insertTitle,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!widget.text)
                  for (final kind in SvgShapeKind.values)
                    if (kind != SvgShapeKind.text)
                      ChoiceChip(
                        avatar: _icon(kind),
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
              onSelected: (value) {
                setState(() => _picker = _ColorPicker.none);
                _pick(value, selectedShape);
              },
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
                      onSelected: (value) => _pick(value, selectedShape),
                    ),
            if (_picker == _ColorPicker.custom) ...[
              ColorAreaPicker(
                key: const Key('insert-color-area'),
                color: color,
                onChanged: (value) {
                  _hex.text = colorToHex(value);
                  _pick(value, selectedShape, live: true);
                },
                onChangeEnd: (value) => _pick(value, selectedShape),
              ),
              TextField(
                key: const Key('insert-hex'),
                controller: _hex,
                decoration: InputDecoration(labelText: l10n.hex),
                onChanged: (value) {
                  final parsed = colorFromHex(value);
                  if (parsed == null) return;
                  // A whole color (#RRGGBB) is one undoable step; a partial
                  // one only previews.
                  final whole = value.replaceAll('#', '').length >= 6;
                  _pick(parsed, selectedShape, live: !whole);
                },
                onSubmitted: (value) {
                  final parsed = colorFromHex(value);
                  if (parsed == null) _hex.text = colorToHex(color);
                },
              ),
            ],
            if (selectedShape == null) ...[
              SliderField(
                label: l10n.shapeSize,
                value: _size,
                min: 5,
                max: 100,
                unit: '%',
                onChanged: (v) => setState(() => _size = v.roundToDouble()),
              ),
              if (_kind != SvgShapeKind.text && _kind != SvgShapeKind.line)
                CheckboxListTile(
                  key: const Key('new-filled'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.filledShape),
                  value: _filled,
                  onChanged: (v) => setState(() => _filled = v ?? false),
                ),
              if (_kind != SvgShapeKind.text)
                SliderField(
                  key: const Key('new-stroke'),
                  label: l10n.outline,
                  value: _stroke,
                  min: 0,
                  max: 10,
                  fractionDigits: 1,
                  unit: '%',
                  onChanged: (v) => setState(() => _stroke = v),
                ),
            ] else ...[
              SliderField(
                key: const Key('selected-size'),
                label: l10n.shapeSize,
                value: (_liveScale ?? SvgTransformEdit.read(editor.svg, selectedShape).scale * 100)
                    .clamp(5, 400),
                min: 5,
                max: 400,
                unit: '%',
                onChanged: (v) {
                  setState(() => _liveScale = v.roundToDouble());
                  editor.preview(_scaled(selectedShape, v / 100).svg);
                },
                onChangeEnd: (v) {
                  _liveScale = null;
                  editor.apply(_scaled(selectedShape, v.roundToDouble() / 100));
                },
              ),
              if (_fillable(selectedShape))
                CheckboxListTile(
                  key: const Key('selected-filled'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.filledShape),
                  value: _isFilled(selectedShape),
                  onChanged: (v) => _setFilled(selectedShape, v ?? false, color),
                ),
              SliderField(
                key: const Key('selected-stroke'),
                label: l10n.outline,
                value:
                    (_liveStroke ??
                            (SvgPaintEdit.read(editor.svg, selectedShape).strokeWidth ?? 0) /
                                _side *
                                100)
                        .clamp(0, 10),
                min: 0,
                max: 10,
                fractionDigits: 1,
                unit: '%',
                onChanged: (v) {
                  setState(() => _liveStroke = v);
                  editor.preview(_outlined(selectedShape, v, color));
                },
                onChangeEnd: (v) {
                  _liveStroke = null;
                  editor.commit(_outlined(selectedShape, v, color));
                },
              ),
            ],
            if (_kind == SvgShapeKind.text)
              TextField(
                controller: _text,
                decoration: InputDecoration(labelText: l10n.textContent),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.outlined(
                  key: const Key('delete-shape'),
                  tooltip: l10n.deleteSelectedElement,
                  onPressed: selectedShape == null
                      ? null
                      : () => editor.apply(SvgLayers.remove(editor.svg, selectedShape)),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                FilledButton.icon(
                  key: const Key('insert-shape'),
                  onPressed: () => editor.apply(
                    SvgInsertEdit.insert(
                      editor.svg,
                      _kind,
                      color: colorToHex(color),
                      size: _size / 100,
                      text: _text!.text,
                      filled: _filled,
                      strokeWidth: _stroke / 100 * _side,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.insertAction),
                ),
              ],
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

/// An oval outline, so Ellipse does not look like Circle.
class _EllipseIcon extends StatelessWidget {
  const _EllipseIcon();

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
