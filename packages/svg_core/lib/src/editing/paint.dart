import 'package:xml/xml.dart';

import '../colors.dart';
import '../css.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Fill and stroke of one element as the editor shows them.
class ElementPaint {
  const ElementPaint({this.fill, this.stroke, this.strokeWidth});

  /// Raw paint value (`#RRGGBB` when it is a plain color, otherwise e.g.
  /// `url(#gradient)` or `none`). Null when not set on the element.
  final String? fill;
  final String? stroke;
  final double? strokeWidth;

  /// `#RRGGBB` when [fill] is a plain color.
  String? get fillColor => fill == null ? null : SvgColorValue.normalize(fill!);
  String? get strokeColor => stroke == null ? null : SvgColorValue.normalize(stroke!);
}

/// Fill/stroke edits on a single element. Editor wrappers are skipped so the
/// paint lands on the element the user actually drew.
class SvgPaintEdit {
  const SvgPaintEdit._();

  static ElementPaint read(String svg, ElementPath path) {
    final element = _target(tryParseSvg(svg), path);
    if (element == null) return const ElementPaint();
    final width = _get(element, 'stroke-width');
    return ElementPaint(
      fill: _normalized(_get(element, 'fill')),
      stroke: _normalized(_get(element, 'stroke')),
      strokeWidth: width == null ? null : parseLength(width),
    );
  }

  /// The `#RRGGBB` fill the element at [path] shows: its own, else the nearest
  /// ancestor's. Null when that is not a plain color (`none`, a gradient...)
  /// or nothing sets one.
  static String? sampleFill(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    var element = _target(document, path);
    while (element != null) {
      final value = _get(element, 'fill');
      if (value != null) return SvgColorValue.normalize(value);
      element = element.parentElement;
    }
    return null;
  }

  /// Sets the fill color; null removes the fill (`none`).
  static String setFill(String svg, ElementPath path, String? color) =>
      _set(svg, path, 'fill', color ?? 'none');

  /// Sets the stroke color; null removes the stroke (`none`).
  static String setStroke(String svg, ElementPath path, String? color) =>
      _set(svg, path, 'stroke', color ?? 'none');

  static String setStrokeWidth(String svg, ElementPath path, double width) =>
      _set(svg, path, 'stroke-width', formatNumber(width));

  static XmlElement? _target(XmlDocument? document, ElementPath path) {
    if (document == null || path.isRoot) return null;
    final element = path.resolve(document.rootElement);
    return element == null ? null : unwrapEditorGroups(element);
  }

  static String? _normalized(String? value) =>
      value == null ? null : (SvgColorValue.normalize(value) ?? value.trim());

  static String? _get(XmlElement element, String property) {
    String? fromStyle;
    mapDeclarations(element.getAttribute('style') ?? '', (name, value) {
      if (name == property) fromStyle = value.trim();
      return value;
    });
    return fromStyle ?? element.getAttribute(property);
  }

  static String _set(String svg, ElementPath path, String property, String value) {
    final document = tryParseSvg(svg);
    final element = _target(document, path);
    if (element == null) return svg;
    element.setAttribute(property, value);
    final style = element.getAttribute('style');
    if (style != null) {
      final cleaned = mapDeclarations(style, (name, old) => name == property ? null : old);
      element.setAttribute('style', cleaned.trim().isEmpty ? null : cleaned);
    }
    return document!.toXmlString();
  }
}
