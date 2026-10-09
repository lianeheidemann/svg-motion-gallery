import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';
import 'insert/insert_widgets.dart';

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

  /// How new shapes are born: the controls below only edit what is selected,
  /// so these never change.
  static const _size = 30.0;
  static const _width = 100.0;
  static const _height = 100.0;
  static const _stroke = 1.5;
  static const _filled = false;
  double? _liveWidth;
  double? _liveHeight;
  double? _liveScale;
  double? _liveStroke;
  var _picker = InsertColorPicker.none;
  var _fillPicker = InsertColorPicker.none;
  TextEditingController? _text;
  final _hex = TextEditingController();
  final _fillHex = TextEditingController();

  static Widget _icon(SvgShapeKind kind) => switch (kind) {
    SvgShapeKind.rectangle => const Icon(Icons.crop_square_rounded, size: 18),
    SvgShapeKind.circle => const Icon(Icons.circle_outlined, size: 18),
    // No stock icon is an oval: a circle would look like the one above.
    SvgShapeKind.ellipse => const EllipseIcon(),
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
      // In the shape's own geometry, so the outline keeps its thickness.
      result =
          SvgShapeSize.stretch(
            result.svg,
            result.selection!,
            width: _width / 100,
            height: _height / 100,
          ) ??
          SvgTransformEdit.apply(
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

  /// [children] greyed out and untouchable while [off].
  List<Widget> _dimmed(bool off, List<Widget> children) => off
      ? [
          for (final child in children)
            IgnorePointer(child: Opacity(opacity: .38, child: child)),
        ]
      : children;

  void _togglePicker(InsertColorPicker picker) =>
      setState(() => _picker = _picker == picker ? InsertColorPicker.none : picker);

  void _toggleFillPicker(InsertColorPicker picker) =>
      setState(() => _fillPicker = _fillPicker == picker ? InsertColorPicker.none : picker);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = [for (final hex in editor.palette) colorFromHex(hex)!];
    final selection = editor.selection;
    // Only what this tab added is resized here, never a layer of the file.
    // The Text tab edits text and the Insert tab edits shapes: anything else
    // leaves the controls greyed out.
    final selectedShape =
        selection != null &&
            SvgInsertEdit.isInserted(editor.svg, selection) &&
            (_layerAt(selection)?.tag == 'text') == widget.text &&
            SvgHitTest.movables(editor.svg).any((m) => m.path == selection)
        ? selection
        : null;
    final enabled = selectedShape != null;
    final strokeNow = selectedShape == null
        ? 0.0
        : (SvgPaintEdit.read(editor.svg, selectedShape).strokeWidth ?? 0) / _side * 100;
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
        !widget.text && selectedShape != null && _fillable(selectedShape) && _isFilled(selectedShape);
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
            if (!widget.text)
              CheckboxListTile(
                key: const Key('selected-filled'),
                contentPadding: const EdgeInsets.only(left: 8),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.filledShape),
                value: selectedShape != null && _isFilled(selectedShape),
                onChanged: selectedShape == null || !_fillable(selectedShape)
                    ? null
                    : (v) => _setFilled(selectedShape, v ?? false, fill),
              ),
            if (showFill)
              ...insertColorSection(
                context,
                label: l10n.fill,
                keys: 'fill',
                color: fill,
                picker: _fillPicker,
                hex: _fillHex,
                togglePicker: _toggleFillPicker,
                pick: (value, {live = false}) => _pickFill(value, selectedShape, live: live),
                closePicker: () => setState(() => _fillPicker = InsertColorPicker.none),
                palette: palette,
              ),
            ..._dimmed(
              !enabled,
              insertColorSection(
                context,
                label: widget.text ? l10n.color : l10n.outline,
                keys: 'insert',
                color: color,
                picker: _picker,
                hex: _hex,
                togglePicker: _togglePicker,
                pick: (value, {live = false}) => _pick(value, selectedShape, live: live),
                closePicker: () => setState(() => _picker = InsertColorPicker.none),
                palette: palette,
              ),
            ),
            SliderField(
              key: const Key('selected-size'),
              label: l10n.shapeSize,
              value: selectedShape == null
                  ? 100
                  : (_liveScale ?? _factors(selectedShape).size * 100).clamp(5, 400),
              min: 5,
              max: 400,
              unit: '%',
              onChanged: selectedShape == null
                  ? null
                  : (v) {
                      setState(() => _liveScale = v.roundToDouble());
                      editor.preview(_scaled(selectedShape, v / 100).svg);
                    },
              onChangeEnd: selectedShape == null
                  ? null
                  : (v) {
                      _liveScale = null;
                      editor.apply(_scaled(selectedShape, v.roundToDouble() / 100));
                    },
            ),
            SliderField(
              key: const Key('selected-width'),
              label: l10n.width,
              value: selectedShape == null
                  ? 100
                  : (_liveWidth ?? _factors(selectedShape).width * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: selectedShape == null
                  ? null
                  : (v) {
                      setState(() => _liveWidth = v.roundToDouble());
                      editor.preview(_stretched(selectedShape, width: v.roundToDouble()).svg);
                    },
              onChangeEnd: selectedShape == null
                  ? null
                  : (v) {
                      _liveWidth = null;
                      editor.apply(_stretched(selectedShape, width: v.roundToDouble()));
                    },
            ),
            SliderField(
              key: const Key('selected-height'),
              label: l10n.height,
              value: selectedShape == null
                  ? 100
                  : (_liveHeight ?? _factors(selectedShape).height * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: selectedShape == null
                  ? null
                  : (v) {
                      setState(() => _liveHeight = v.roundToDouble());
                      editor.preview(_stretched(selectedShape, height: v.roundToDouble()).svg);
                    },
              onChangeEnd: selectedShape == null
                  ? null
                  : (v) {
                      _liveHeight = null;
                      editor.apply(_stretched(selectedShape, height: v.roundToDouble()));
                    },
            ),
            if (!widget.text)
              SliderField(
                key: const Key('selected-stroke'),
                label: l10n.outline,
                value: (_liveStroke ?? strokeNow).clamp(0, 10),
                min: 0,
                max: 10,
                fractionDigits: 1,
                unit: '%',
                onChanged: selectedShape == null
                    ? null
                    : (v) {
                        setState(() => _liveStroke = v);
                        editor.preview(_outlined(selectedShape, v, color));
                      },
                onChangeEnd: selectedShape == null
                    ? null
                    : (v) {
                        _liveStroke = null;
                        editor.commit(_outlined(selectedShape, v, color));
                      },
              ),
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
