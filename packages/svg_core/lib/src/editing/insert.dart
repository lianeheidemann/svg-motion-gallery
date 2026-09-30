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
  static SvgEditResult insert(
    String svg,
    SvgShapeKind kind, {
    required String color,
    double size = 0.3,
    String text = 'Text',
  }) {
    final document = tryParseSvg(svg);
    if (document == null) return SvgEditResult(svg);
    final canvas = SvgMetadata.parse(svg).canvas;
    final cx = canvas.centerX;
    final cy = canvas.centerY;
    final side = math.min(canvas.width, canvas.height) * size.clamp(0.02, 1.0);
    final n = formatNumber;

    final element = switch (kind) {
      SvgShapeKind.rectangle => _element('rect', {
        'x': n(cx - side / 2),
        'y': n(cy - side / 2),
        'width': n(side),
        'height': n(side),
        'rx': n(side * 0.12),
        'fill': color,
      }),
      SvgShapeKind.circle => _element('circle', {
        'cx': n(cx),
        'cy': n(cy),
        'r': n(side / 2),
        'fill': color,
      }),
      SvgShapeKind.ellipse => _element('ellipse', {
        'cx': n(cx),
        'cy': n(cy),
        'rx': n(side * 0.7),
        'ry': n(side * 0.4),
        'fill': color,
      }),
      SvgShapeKind.line => _element('line', {
        'x1': n(cx - side / 2),
        'y1': n(cy),
        'x2': n(cx + side / 2),
        'y2': n(cy),
        'stroke': color,
        'stroke-width': n(math.max(side * 0.04, 1)),
        'stroke-linecap': 'round',
      }),
      SvgShapeKind.star => _element('polygon', {
        'points': _starPoints(cx, cy, side / 2),
        'fill': color,
      }),
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
