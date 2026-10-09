import 'package:xml/xml.dart';

import '../xml_support.dart';
import 'element_path.dart';

/// Size, width and height of a shape, as factors of how it was drawn
/// (1 = as inserted).
typedef SvgShapeFactors = ({double size, double width, double height});

/// Resizes simple shapes by changing their own geometry (width, radius,
/// points...) instead of putting a `scale` around them, so the outline keeps
/// the thickness it has whatever the shape is stretched to.
///
/// The factors are kept on the element (`data-sm-size`, `data-sm-w`,
/// `data-sm-h`) so a slider can show where the shape is.
class SvgShapeSize {
  const SvgShapeSize._();

  static const _sizeAttribute = 'data-sm-size';
  static const _widthAttribute = 'data-sm-w';
  static const _heightAttribute = 'data-sm-h';

  /// Shapes whose geometry can be stretched.
  static const _shapes = {'rect', 'circle', 'ellipse', 'line', 'polygon', 'polyline'};

  /// Whether the element at [path] (or inside the editor wrapper there) is a
  /// shape that [stretch] can resize.
  static bool canStretch(String svg, ElementPath path) {
    final element = _shape(tryParseSvg(svg), path);
    return element != null && _shapes.contains(element.localName);
  }

  /// The factors of the shape at [path]; all 1 when it was never stretched.
  static SvgShapeFactors read(String svg, ElementPath path) {
    final element = _shape(tryParseSvg(svg), path);
    return element == null ? _identity : _factors(element);
  }

  /// Sets the factors of the shape at [path] that are given, moving its
  /// geometry around its center. The outline width is not touched. Null when
  /// the shape cannot be stretched (paths, text, groups...), so the caller can
  /// scale it instead.
  static SvgEditResult? stretch(
    String svg,
    ElementPath path, {
    double? size,
    double? width,
    double? height,
  }) {
    final document = tryParseSvg(svg);
    var element = _shape(document, path);
    if (document == null || element == null || !_shapes.contains(element.localName)) return null;

    final old = _factors(element);
    final next = (
      size: (size ?? old.size).clamp(0.01, 100.0),
      width: (width ?? old.width).clamp(0.01, 100.0),
      height: (height ?? old.height).clamp(0.01, 100.0),
    );
    final ratioX = (next.size * next.width) / (old.size * old.width);
    final ratioY = (next.size * next.height) / (old.size * old.height);

    element = _apply(element, ratioX, ratioY);
    _store(element, _sizeAttribute, next.size);
    _store(element, _widthAttribute, next.width);
    _store(element, _heightAttribute, next.height);
    return SvgEditResult(document.toXmlString(), selection: path);
  }

  static const SvgShapeFactors _identity = (size: 1, width: 1, height: 1);

  static SvgShapeFactors _factors(XmlElement element) => (
    size: _read(element, _sizeAttribute),
    width: _read(element, _widthAttribute),
    height: _read(element, _heightAttribute),
  );

  static double _read(XmlElement element, String name) {
    final value = double.tryParse(element.getAttribute(name) ?? '');
    return value == null || value <= 0 ? 1 : value;
  }

  /// A factor of 1 is the default, so it leaves no attribute behind.
  static void _store(XmlElement element, String name, double value) =>
      element.setAttribute(name, (value - 1).abs() < 1e-9 ? null : formatNumber(value));

  /// The shape at [path], looking through the wrapper the editor puts around
  /// an element it moved or turned.
  static XmlElement? _shape(XmlDocument? document, ElementPath path) {
    if (document == null || path.isRoot) return null;
    final element = path.resolve(document.rootElement);
    return element == null ? null : unwrapEditorGroups(element);
  }

  static double _n(XmlElement element, String name, [double fallback = 0]) =>
      double.tryParse(element.getAttribute(name) ?? '') ?? fallback;

  static void _set(XmlElement element, String name, double value) =>
      element.setAttribute(name, formatNumber(value));

  /// Moves the geometry by [rx] across and [ry] down, around its center.
  /// Returns the element that now holds the shape (a circle is replaced by an
  /// ellipse, since it stops being round).
  static XmlElement _apply(XmlElement element, double rx, double ry) {
    switch (element.localName) {
      case 'rect':
        final width = _n(element, 'width');
        final height = _n(element, 'height');
        final cx = _n(element, 'x') + width / 2;
        final cy = _n(element, 'y') + height / 2;
        _set(element, 'width', width * rx);
        _set(element, 'height', height * ry);
        _set(element, 'x', cx - width * rx / 2);
        _set(element, 'y', cy - height * ry / 2);
      case 'ellipse':
        _set(element, 'rx', _n(element, 'rx') * rx);
        _set(element, 'ry', _n(element, 'ry') * ry);
      case 'circle':
        final radius = _n(element, 'r');
        if ((rx - 1).abs() < 1e-9 && (ry - 1).abs() < 1e-9) return element;
        final ellipse = buildElement(
          'ellipse',
          attributes: {
            for (final attribute in element.attributes)
              if (attribute.name.local != 'r') attribute.name.local: attribute.value,
            'rx': formatNumber(radius * rx),
            'ry': formatNumber(radius * ry),
          },
          children: element.children.map((node) => node.copy()),
        );
        element.replace(ellipse);
        return ellipse;
      case 'line':
        final cx = (_n(element, 'x1') + _n(element, 'x2')) / 2;
        final cy = (_n(element, 'y1') + _n(element, 'y2')) / 2;
        for (final name in ['x1', 'x2']) {
          _set(element, name, cx + (_n(element, name) - cx) * rx);
        }
        for (final name in ['y1', 'y2']) {
          _set(element, name, cy + (_n(element, name) - cy) * ry);
        }
      default: // polygon, polyline
        final points = _points(element.getAttribute('points') ?? '');
        if (points.isEmpty) return element;
        var left = points.first.$1, right = left;
        var top = points.first.$2, bottom = top;
        for (final (x, y) in points) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
        final cx = (left + right) / 2;
        final cy = (top + bottom) / 2;
        element.setAttribute(
          'points',
          points
              .map(
                (p) =>
                    '${formatNumber(cx + (p.$1 - cx) * rx)},${formatNumber(cy + (p.$2 - cy) * ry)}',
              )
              .join(' '),
        );
    }
    return element;
  }

  static List<(double, double)> _points(String text) {
    final numbers = RegExp(
      r'-?\d*\.?\d+(?:e[-+]?\d+)?',
      caseSensitive: false,
    ).allMatches(text).map((m) => double.parse(m.group(0)!)).toList();
    return [for (var i = 0; i + 1 < numbers.length; i += 2) (numbers[i], numbers[i + 1])];
  }
}
