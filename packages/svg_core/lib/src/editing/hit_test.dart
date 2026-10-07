import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../xml_support.dart';
import 'element_path.dart';
import 'transform.dart';

/// Axis-aligned box in user (viewBox) units.
class SvgBounds {
  const SvgBounds(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  bool contains(double x, double y, {double slop = 0}) =>
      x >= left - slop && x <= right + slop && y >= top - slop && y <= bottom + slop;

  /// This box scaled by [scale] around its center, then moved by ([dx], [dy]).
  SvgBounds transformed({double scale = 1, double dx = 0, double dy = 0}) {
    final halfW = width / 2 * scale;
    final halfH = height / 2 * scale;
    return SvgBounds(
      centerX + dx - halfW,
      centerY + dy - halfH,
      centerX + dx + halfW,
      centerY + dy + halfH,
    );
  }
}

/// A top-level shape the user can grab and drag on the stage.
class SvgMovable {
  const SvgMovable({required this.path, required this.bounds, this.rotation = 0});

  /// Address of the root child to pass to [SvgTransformEdit].
  final ElementPath path;

  /// Where the shape currently is, including its editor transform. The box is
  /// the unrotated one: it turns by [rotation] around its center.
  final SvgBounds bounds;

  /// Degrees, clockwise, around the center of [bounds].
  final double rotation;

  /// Whether the point ([x], [y]) is on the (rotated) shape, with [slop] units
  /// of tolerance.
  bool containsPoint(double x, double y, {double slop = 0}) {
    if (rotation == 0) return bounds.contains(x, y, slop: slop);
    final angle = -rotation * math.pi / 180;
    final dx = x - bounds.centerX;
    final dy = y - bounds.centerY;
    final localX = bounds.centerX + dx * math.cos(angle) - dy * math.sin(angle);
    final localY = bounds.centerY + dx * math.sin(angle) + dy * math.cos(angle);
    return bounds.contains(localX, localY, slop: slop);
  }
}

/// Finds the shapes drawn directly on the canvas (the ones the Insert tab
/// creates) so they can be dragged with a finger.
class SvgHitTest {
  const SvgHitTest._();

  static const _shapes = {'rect', 'circle', 'ellipse', 'line', 'polygon', 'text'};

  /// Movable shapes in paint order (last = on top).
  static List<SvgMovable> movables(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return const [];
    final result = <SvgMovable>[];
    var index = -1;
    for (final child in document.rootElement.childElements) {
      index++;
      if (!isVisual(child) || child.getAttribute(editorAttribute) == 'root') continue;
      final shape = unwrapEditorGroups(child);
      if (!_shapes.contains(shape.localName) || _isHidden(shape) || _isHidden(child)) continue;
      final base = _bounds(shape);
      if (base == null) continue;
      final path = ElementPath([index]);
      final values = SvgTransformEdit.read(svg, path);
      result.add(
        SvgMovable(
          path: path,
          bounds: base.transformed(
            scale: values.scale,
            dx: values.translateX,
            dy: values.translateY,
          ),
          rotation: values.rotation,
        ),
      );
    }
    return result;
  }

  /// The topmost movable shape at ([x], [y]), with [slop] units of tolerance.
  static SvgMovable? at(String svg, double x, double y, {double slop = 0}) {
    for (final movable in movables(svg).reversed) {
      if (movable.containsPoint(x, y, slop: slop)) return movable;
    }
    return null;
  }

  static bool _isHidden(XmlElement element) =>
      element.getAttribute('display') == 'none' ||
      RegExp(r'display\s*:\s*none').hasMatch(element.getAttribute('style') ?? '');

  static double _n(XmlElement element, String name) =>
      double.tryParse(element.getAttribute(name) ?? '') ?? 0;

  static SvgBounds? _bounds(XmlElement e) {
    switch (e.localName) {
      case 'rect':
        final x = _n(e, 'x');
        final y = _n(e, 'y');
        return SvgBounds(x, y, x + _n(e, 'width'), y + _n(e, 'height'));
      case 'circle':
        final r = _n(e, 'r');
        return SvgBounds(_n(e, 'cx') - r, _n(e, 'cy') - r, _n(e, 'cx') + r, _n(e, 'cy') + r);
      case 'ellipse':
        final cx = _n(e, 'cx');
        final cy = _n(e, 'cy');
        return SvgBounds(cx - _n(e, 'rx'), cy - _n(e, 'ry'), cx + _n(e, 'rx'), cy + _n(e, 'ry'));
      case 'line':
        final half = (double.tryParse(e.getAttribute('stroke-width') ?? '') ?? 1) / 2;
        final x1 = _n(e, 'x1');
        final x2 = _n(e, 'x2');
        final y1 = _n(e, 'y1');
        final y2 = _n(e, 'y2');
        return SvgBounds(
          (x1 < x2 ? x1 : x2) - half,
          (y1 < y2 ? y1 : y2) - half,
          (x1 > x2 ? x1 : x2) + half,
          (y1 > y2 ? y1 : y2) + half,
        );
      case 'polygon':
        final numbers = (e.getAttribute('points') ?? '')
            .trim()
            .split(RegExp(r'[\s,]+'))
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (numbers.length < 4) return null;
        var left = numbers[0], right = numbers[0], top = numbers[1], bottom = numbers[1];
        for (var i = 0; i + 1 < numbers.length; i += 2) {
          if (numbers[i] < left) left = numbers[i];
          if (numbers[i] > right) right = numbers[i];
          if (numbers[i + 1] < top) top = numbers[i + 1];
          if (numbers[i + 1] > bottom) bottom = numbers[i + 1];
        }
        return SvgBounds(left, top, right, bottom);
      case 'text':
        final size = double.tryParse(e.getAttribute('font-size') ?? '') ?? 16;
        final width = e.innerText.trim().length * size * 0.6;
        final x = _n(e, 'x');
        final y = _n(e, 'y');
        final left = switch (e.getAttribute('text-anchor')) {
          'middle' => x - width / 2,
          'end' => x - width,
          _ => x,
        };
        final middle = e.getAttribute('dominant-baseline') == 'middle';
        final top = middle ? y - size * 0.6 : y - size;
        return SvgBounds(left, top, left + width, top + size * 1.2);
    }
    return null;
  }
}
