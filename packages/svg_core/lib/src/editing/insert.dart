import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../metadata.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Shapes the editor can insert.
enum SvgShapeKind { rectangle, circle, ellipse, line, star, text }

/// Inserts new elements centered on the canvas.
class SvgInsertEdit {
  const SvgInsertEdit._();

  /// Adds a [kind] shape painted with [color] on top of the drawing and
  /// selects it. [size] is a fraction (0..1) of the smaller canvas side.
  ///
  /// Shapes are hollow (just an outline in [color]) unless [filled], in which
  /// case they are filled with [fillColor] (default: [color]). The
  /// outline is [strokeWidth] units thick (a thin default scaled to the
  /// canvas); 0 leaves a filled shape without one. Lines are only an outline
  /// and text is only filled.
  static SvgEditResult insert(
    String svg,
    SvgShapeKind kind, {
    required String color,
    double size = 0.3,
    String text = 'Text',
    bool filled = false,
    String? fillColor,
    double? strokeWidth,
  }) {
    final document = tryParseSvg(svg);
    if (document == null) return SvgEditResult(svg);
    final canvas = SvgMetadata.parse(svg).canvas;
    final cx = canvas.centerX;
    final cy = canvas.centerY;
    final side = math.min(canvas.width, canvas.height) * size.clamp(0.02, 1.0);
    final n = formatNumber;
    final outline = math.max(strokeWidth ?? math.min(canvas.width, canvas.height) * 0.015, 0.0);
    // fill + stroke attributes of a closed shape.
    final paint = <String, String>{
      'fill': filled ? (fillColor ?? color) : 'none',
      if (!filled || outline > 0) 'stroke': color,
      if (!filled || outline > 0) 'stroke-width': n(filled ? outline : math.max(outline, 0.1)),
      if (!filled || outline > 0) 'stroke-linejoin': 'round',
    };

    final element = switch (kind) {
      SvgShapeKind.rectangle => _element('rect', {
        'x': n(cx - side / 2),
        'y': n(cy - side / 2),
        'width': n(side),
        'height': n(side),
        'rx': n(side * 0.12),
        ...paint,
      }),
      SvgShapeKind.circle => _element('circle', {
        'cx': n(cx),
        'cy': n(cy),
        'r': n(side / 2),
        ...paint,
      }),
      SvgShapeKind.ellipse => _element('ellipse', {
        'cx': n(cx),
        'cy': n(cy),
        'rx': n(side * 0.7),
        'ry': n(side * 0.4),
        ...paint,
      }),
      SvgShapeKind.line => _element('line', {
        'x1': n(cx - side / 2),
        'y1': n(cy),
        'x2': n(cx + side / 2),
        'y2': n(cy),
        'stroke': color,
        'stroke-width': n(strokeWidth == null ? math.max(side * 0.04, 1) : math.max(outline, 0.1)),
        'stroke-linecap': 'round',
      }),
      SvgShapeKind.star => _element('polygon', {'points': _starPoints(cx, cy, side / 2), ...paint}),
      SvgShapeKind.text => _element('text', {
        'x': n(cx),
        'y': n(cy),
        'fill': color,
        'font-family': 'sans-serif',
        'font-size': n(side * 0.35),
        'font-weight': '700',
        'text-anchor': 'middle',
        'dominant-baseline': 'middle',
      }, text),
    };
    document.rootElement.children.add(element);
    return SvgEditResult(document.toXmlString(), selection: ElementPath.of(element));
  }

  static XmlElement _element(String tag, Map<String, String> attributes, [String? text]) =>
      buildElement(tag, attributes: attributes, children: [if (text != null) XmlText(text)]);

  static String _starPoints(double cx, double cy, double radius) {
    final points = <String>[];
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      points.add(
        '${formatNumber(cx + r * math.cos(angle))},${formatNumber(cy + r * math.sin(angle))}',
      );
    }
    return points.join(' ');
  }
}
