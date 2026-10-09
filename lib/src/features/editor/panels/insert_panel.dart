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
  /// Outline color (the only color of lines and text) and fill color.
  Color? _color;
  Color? _fillColor;

  /// True while a color is being dragged in the free picker, so the row keeps
  /// showing that color instead of the one stored in the file.
  var _picking = false;
  var _size = 30.0;

  /// Stretch of new shapes' width and height, in percent.
  var _width = 100.0;
  var _height = 100.0;
  double? _liveWidth;
  double? _liveHeight;

  /// Outline of new shapes, as a percentage of the smaller canvas side.
  var _stroke = 1.5;

  /// Whether new shapes are filled; they are hollow (outline only) by default.
  var _filled = false;
  double? _liveScale;
  double? _liveStroke;
  var _picker = _ColorPicker.none;
  var _fillPicker = _ColorPicker.none;
  TextEditingController? _text;
  final _hex = TextEditingController();
  final _fillHex = TextEditingController();

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
    _fillHex.dispose();
    super.dispose();
  }

  EditorController get editor => widget.editor;

  /// Shapes are resized in their own geometry, so the outline keeps its
  /// thickness; what cannot be (text, paths) is scaled instead.
  SvgEditResult _scaled(ElementPath path, double scale) =>
      SvgShapeSize.stretch(editor.svg, path, size: scale) ??
      SvgTransformEdit.apply(
        editor.svg,
        path,
        SvgTransformEdit.read(editor.svg, path).copyWith(scale: scale),
      );

  /// Size, width and height of [path] as factors (1 = as drawn).
  SvgShapeFactors _factors(ElementPath path) {
    if (SvgShapeSize.canStretch(editor.svg, path)) return SvgShapeSize.read(editor.svg, path);
    final values = SvgTransformEdit.read(editor.svg, path);
    return (size: values.scale, width: values.widthFactor, height: values.heightFactor);
  }

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

  /// Fills the shape with [fallback] (keeping a fill it already has), or
  /// hollows it (keeping an outline so it does not disappear).
  void _setFilled(ElementPath path, bool filled, Color fallback) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final own = paint.strokeColor ?? paint.fillColor ?? colorToHex(fallback);
    var svg = editor.svg;
    if (filled) {
      svg = SvgPaintEdit.setFill(svg, path, colorToHex(fallback));
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

  /// The outline color of a shape, else its fill (text has only a fill).
  Color? _shapeColor(ElementPath path) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final stroke = paint.stroke == 'none' ? null : paint.strokeColor;
    final fill = paint.fill == 'none' ? null : paint.fillColor;
    final hex = stroke ?? fill;
    return hex == null ? null : colorFromHex(hex);
  }

  /// The outline color of a shape, or null when it has none.
  Color? _shapeOutline(ElementPath path) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final hex = paint.stroke == 'none' ? null : paint.strokeColor;
    return hex == null ? null : colorFromHex(hex);
  }

  /// The fill color of a shape, or null when it is hollow.
  Color? _shapeFill(ElementPath path) {
    final paint = SvgPaintEdit.read(editor.svg, path);
    final hex = paint.fill == 'none' || paint.fill == 'transparent' ? null : paint.fillColor;
    return hex == null ? null : colorFromHex(hex);
  }

  /// [svg] with the shape at [path] painted [color]: the fill when it has one
  /// (filled shapes, text) and the outline when it has one (hollow shapes,
  /// lines). Only for text, which has a single color.
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

  /// [svg] with the outline of the shape at [path] painted [color]; an
  /// outline that is not there yet gets a thin one.
  String _recolorOutline(String svg, ElementPath path, Color color) {
    var result = SvgPaintEdit.setStroke(svg, path, colorToHex(color));
    if ((SvgPaintEdit.read(result, path).strokeWidth ?? 0) <= 0) {
      result = SvgPaintEdit.setStrokeWidth(result, path, _side * 0.015);
    }
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
    final svg = widget.text
        ? _recolor(editor.svg, shape, value)
        : _recolorOutline(editor.svg, shape, value);
    live ? editor.preview(svg) : editor.commit(svg);
  }

  /// Same for the fill color.
  void _pickFill(Color value, ElementPath? shape, {bool live = false}) {
    setState(() {
      _fillColor = value;
      _picking = live;
    });
    if (shape == null || !_isFilled(shape)) return;
    final svg = SvgPaintEdit.setFill(editor.svg, shape, colorToHex(value));
    live ? editor.preview(svg) : editor.commit(svg);
  }

  /// A shape button was tapped: the shape is added right away, with the
  /// colors, size, outline and stretch set below.
  void _insert(SvgShapeKind kind, Color outline, Color fill) {
    var result = SvgInsertEdit.insert(
      editor.svg,
      kind,
      color: colorToHex(outline),
      fillColor: colorToHex(fill),
      size: _size / 100,
      text: _text?.text ?? '',
      filled: _filled,
      strokeWidth: _stroke / 100 * _side,
    );
    if (_width != 100 || _height != 100) {
      result = SvgTransformEdit.apply(
        result.svg,
        result.selection,
        SvgTransformValues.identity.copyWith(
          widthFactor: _width / 100,
          heightFactor: _height / 100,
        ),
      );
    }
    editor.apply(result);
  }

  /// The selected shape stretched to [width] x [height] percent.
  SvgEditResult _stretched(ElementPath path, {double? width, double? height}) =>
      SvgShapeSize.stretch(
        editor.svg,
        path,
        width: width == null ? null : width / 100,
        height: height == null ? null : height / 100,
      ) ??
      SvgTransformEdit.apply(
        editor.svg,
        path,
        SvgTransformEdit.read(editor.svg, path).copyWith(
          widthFactor: width == null ? null : width / 100,
          heightFactor: height == null ? null : height / 100,
        ),
      );

  void _togglePicker(_ColorPicker picker) =>
      setState(() => _picker = _picker == picker ? _ColorPicker.none : picker);

  void _toggleFillPicker(_ColorPicker picker) =>
      setState(() => _fillPicker = _fillPicker == picker ? _ColorPicker.none : picker);

  /// A row of swatches plus the eyedropper and free picker, for one color.
  List<Widget> _colorSection({
    required String label,
    required String keys,
    required Color color,
    required _ColorPicker picker,
    required TextEditingController hex,
    required void Function(_ColorPicker) togglePicker,
    required void Function(Color value, {bool live}) pick,
    required VoidCallback closePicker,
    required List<Color> palette,
  }) {
    final l10n = context.l10n;
    return [
      Text(label),
      ColorPaletteGrid(
        key: Key('$keys-colors'),
        colors: _quickColors,
        size: 36,
        selected: color,
        onSelected: (value) {
          closePicker();
          pick(value);
        },
        trailing: [
          _ToolDot(
            key: Key('$keys-eyedropper'),
            icon: Icons.colorize_rounded,
            label: l10n.eyedropper,
            selected: picker == _ColorPicker.drawing,
            onTap: () => togglePicker(_ColorPicker.drawing),
          ),
          ColorDot(
            key: Key('$keys-custom-color'),
            color: color,
            size: 36,
            selected: picker == _ColorPicker.custom,
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
              togglePicker(_ColorPicker.custom);
            },
          ),
        ],
      ),
      if (picker == _ColorPicker.drawing)
        palette.isEmpty
            ? Text(l10n.paletteEmpty)
            : ColorPaletteGrid(
                key: Key('$keys-drawing-colors'),
                colors: palette,
                size: 32,
                selected: color,
                onSelected: pick,
              ),
      if (picker == _ColorPicker.custom) ...[
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = [for (final hex in editor.palette) colorFromHex(hex)!];
    final selection = editor.selection;
    final selectedShape =
        selection != null && SvgHitTest.movables(editor.svg).any((m) => m.path == selection)
        ? selection
        : null;
    final primary = Theme.of(context).colorScheme.primary;
    // With a shape selected the rows show (and change) that shape's colors.
    final shown = selectedShape != null && !_picking;
    final color =
        (shown
            ? (widget.text ? _shapeColor(selectedShape) : _shapeOutline(selectedShape))
            : null) ??
        _color ??
        primary;
    final fill = (shown ? _shapeFill(selectedShape) : null) ?? _fillColor ?? color;
    // The fill color only matters while the shapes are filled.
    final showFill =
        !widget.text &&
        (selectedShape == null ? _filled : _fillable(selectedShape) && _isFilled(selectedShape));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.add_box_outlined,
          title: widget.text ? l10n.insertTextTitle : l10n.insertTitle,
          children: [
            if (!widget.text)
              // Tapping a shape adds it right away.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in SvgShapeKind.values)
                    if (kind != SvgShapeKind.text)
                      ActionChip(
                        key: Key('insert-${kind.name}'),
                        avatar: _icon(kind),
                        label: Text(l10n.shape(kind)),
                        onPressed: () => _insert(kind, color, fill),
                      ),
                ],
              ),
            ..._colorSection(
              label: widget.text ? l10n.color : l10n.outline,
              keys: 'insert',
              color: color,
              picker: _picker,
              hex: _hex,
              togglePicker: _togglePicker,
              pick: (value, {live = false}) => _pick(value, selectedShape, live: live),
              closePicker: () => setState(() => _picker = _ColorPicker.none),
              palette: palette,
            ),
            if (showFill)
              ..._colorSection(
                label: l10n.fill,
                keys: 'fill',
                color: fill,
                picker: _fillPicker,
                hex: _fillHex,
                togglePicker: _toggleFillPicker,
                pick: (value, {live = false}) => _pickFill(value, selectedShape, live: live),
                closePicker: () => setState(() => _fillPicker = _ColorPicker.none),
                palette: palette,
              ),
            if (selectedShape == null) ...[
              SliderField(
                label: l10n.shapeSize,
                value: _size,
                min: 5,
                max: 100,
                unit: '%',
                onChanged: (v) => setState(() => _size = v.roundToDouble()),
              ),
              SliderField(
                key: const Key('new-width'),
                label: l10n.width,
                value: _width,
                min: 10,
                max: 400,
                unit: '%',
                onChanged: (v) => setState(() => _width = v.roundToDouble()),
              ),
              SliderField(
                key: const Key('new-height'),
                label: l10n.height,
                value: _height,
                min: 10,
                max: 400,
                unit: '%',
                onChanged: (v) => setState(() => _height = v.roundToDouble()),
              ),
              if (!widget.text)
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
                value: (_liveScale ?? _factors(selectedShape).size * 100).clamp(5, 400),
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
              SliderField(
                key: const Key('selected-width'),
                label: l10n.width,
                value: (_liveWidth ?? _factors(selectedShape).width * 100).clamp(10, 400),
                min: 10,
                max: 400,
                unit: '%',
                onChanged: (v) {
                  setState(() => _liveWidth = v.roundToDouble());
                  editor.preview(_stretched(selectedShape, width: v.roundToDouble()).svg);
                },
                onChangeEnd: (v) {
                  _liveWidth = null;
                  editor.apply(_stretched(selectedShape, width: v.roundToDouble()));
                },
              ),
              SliderField(
                key: const Key('selected-height'),
                label: l10n.height,
                value: (_liveHeight ?? _factors(selectedShape).height * 100).clamp(10, 400),
                min: 10,
                max: 400,
                unit: '%',
                onChanged: (v) {
                  setState(() => _liveHeight = v.roundToDouble());
                  editor.preview(_stretched(selectedShape, height: v.roundToDouble()).svg);
                },
                onChangeEnd: (v) {
                  _liveHeight = null;
                  editor.apply(_stretched(selectedShape, height: v.roundToDouble()));
                },
              ),
              if (!widget.text)
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
            if (widget.text)
              TextField(
                controller: _text,
                decoration: InputDecoration(labelText: l10n.textContent),
              ),
            Row(
              children: [
                IconButton.outlined(
                  key: const Key('delete-shape'),
                  tooltip: l10n.deleteSelectedElement,
                  onPressed: selectedShape == null
                      ? null
                      : () => editor.apply(SvgLayers.remove(editor.svg, selectedShape)),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                if (!widget.text && (selectedShape == null || _fillable(selectedShape)))
                  Expanded(
                    child: CheckboxListTile(
                      key: Key(selectedShape == null ? 'new-filled' : 'selected-filled'),
                      contentPadding: const EdgeInsets.only(left: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.filledShape),
                      value: selectedShape == null ? _filled : _isFilled(selectedShape),
                      onChanged: (v) => selectedShape == null
                          ? setState(() => _filled = v ?? false)
                          : _setFilled(selectedShape, v ?? false, fill),
                    ),
                  )
                else
                  const Spacer(),
                if (widget.text)
                  FilledButton.icon(
                    key: const Key('insert-shape'),
                    onPressed: () => _insert(SvgShapeKind.text, color, color),
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
