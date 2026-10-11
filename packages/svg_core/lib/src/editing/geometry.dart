import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../xml_support.dart';
import 'hit_test.dart';

/// A 2D affine transform: `x' = a·x + c·y + e`, `y' = b·x + d·y + f` (the
/// order of the SVG `matrix(a b c d e f)`).
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = Affine(1, 0, 0, 1, 0, 0);

  factory Affine.translate(double x, double y) => Affine(1, 0, 0, 1, x, y);

  final double a, b, c, d, e, f;

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  /// This transform applied after [other] (`this · other`).
  Affine multiply(Affine other) => Affine(
    a * other.a + c * other.b,
    b * other.a + d * other.b,
    a * other.c + c * other.d,
    b * other.c + d * other.d,
    a * other.e + c * other.f + e,
    b * other.e + d * other.f + f,
  );

  /// The transform that undoes this one; null when it flattens the plane.
  Affine? get inverse {
    final det = a * d - b * c;
    if (det.abs() < 1e-12) return null;
    return Affine(
      d / det,
      -b / det,
      -c / det,
      a / det,
      (c * f - d * e) / det,
      (b * e - a * f) / det,
    );
  }

  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);

  /// The smallest axis-aligned box holding [box] after the transform.
  SvgBounds applyToBounds(SvgBounds box) {
    final corners = [
      apply(box.left, box.top),
      apply(box.right, box.top),
      apply(box.right, box.bottom),
      apply(box.left, box.bottom),
    ];
    return SvgBounds(
      corners.map((p) => p.$1).reduce(math.min),
      corners.map((p) => p.$2).reduce(math.min),
      corners.map((p) => p.$1).reduce(math.max),
      corners.map((p) => p.$2).reduce(math.max),
    );
  }

  /// `matrix(...)` with six decimals (an inverse scale needs more than the
  /// three [formatNumber] keeps).
  String toSvg() => 'matrix(${[a, b, c, d, e, f].map(_n).join(' ')})';

  static String _n(double v) {
    var text = v.toStringAsFixed(6);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text == '-0' ? '0' : text;
  }

  @override
  bool operator ==(Object other) =>
      other is Affine &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);
}

/// Where elements are, worked out from the markup alone: the box of a shape
/// (paths included) and the transform from its own coordinates to the
/// drawing's (`viewBox`) coordinates. Strokes are not counted in the boxes,
/// and a curve's box is its true extent. Good enough to lay a gradient over
/// several shapes; it does not run animations.
class SvgGeometry {
  const SvgGeometry._();

  /// The box of [element]'s own drawing, in its own coordinates (before its
  /// own `transform`); null when it draws nothing measurable.
  static SvgBounds? localBounds(XmlElement element) {
    switch (element.localName) {
      case 'g' || 'a' || 'svg' || 'switch':
        return _children(element);
      case 'rect':
        final x = _n(element, 'x');
        final y = _n(element, 'y');
        return SvgBounds(x, y, x + _n(element, 'width'), y + _n(element, 'height'));
      case 'circle':
        final r = _n(element, 'r');
        return SvgBounds(
          _n(element, 'cx') - r,
          _n(element, 'cy') - r,
          _n(element, 'cx') + r,
          _n(element, 'cy') + r,
        );
      case 'ellipse':
        final cx = _n(element, 'cx');
        final cy = _n(element, 'cy');
        return SvgBounds(
          cx - _n(element, 'rx'),
          cy - _n(element, 'ry'),
          cx + _n(element, 'rx'),
          cy + _n(element, 'ry'),
        );
      case 'line':
        return _points([
          _n(element, 'x1'),
          _n(element, 'y1'),
          _n(element, 'x2'),
          _n(element, 'y2'),
        ]);
      case 'polygon' || 'polyline':
        return _points(_numbers(element.getAttribute('points') ?? ''));
      case 'path':
        return _pathBounds(element.getAttribute('d') ?? '');
      case 'text':
        final size = double.tryParse(element.getAttribute('font-size') ?? '') ?? 16;
        final width = element.innerText.trim().length * size * 0.6;
        final x = _n(element, 'x');
        final y = _n(element, 'y');
        final left = switch (element.getAttribute('text-anchor')) {
          'middle' => x - width / 2,
          'end' => x - width,
          _ => x,
        };
        return SvgBounds(left, y - size, left + width, y + size * 0.2);
    }
    return null;
  }

  /// [element]'s own `transform`. An editor wrapper turns around the center of
  /// what is inside it (`transform-origin:center` on the fill box), the way
  /// the renderer draws it.
  static Affine ownTransform(XmlElement element) {
    final matrix = _parseTransform(element.getAttribute('transform') ?? '');
    if (matrix.isIdentity || element.getAttribute(editorAttribute) == null) return matrix;
    final box = localBounds(element);
    if (box == null) return matrix;
    return Affine.translate(
      box.centerX,
      box.centerY,
    ).multiply(matrix).multiply(Affine.translate(-box.centerX, -box.centerY));
  }

  /// From [element]'s own coordinates (the ones its geometry and `x`/`d`
  /// are written in) to the drawing's: its transform and every ancestor's.
  static Affine toRoot(XmlElement element) {
    var matrix = Affine.identity;
    XmlElement? current = element;
    while (current != null && current.parentElement != null) {
      matrix = ownTransform(current).multiply(matrix);
      current = current.parentElement;
    }
    return matrix;
  }

  /// Where [element] is drawn, in the drawing's coordinates.
  static SvgBounds? rootBounds(XmlElement element) {
    final box = localBounds(element);
    return box == null ? null : toRoot(element).applyToBounds(box);
  }

  static SvgBounds? _children(XmlElement parent) {
    SvgBounds? union;
    for (final child in parent.childElements) {
      if (!isVisual(child)) continue;
      final box = localBounds(child);
      if (box == null) continue;
      final inParent = ownTransform(child).applyToBounds(box);
      union = union == null ? inParent : _union(union, inParent);
    }
    return union;
  }

  /// The smallest box holding both [a] and [b].
  static SvgBounds unionOf(SvgBounds a, SvgBounds b) => _union(a, b);

  static SvgBounds _union(SvgBounds a, SvgBounds b) => SvgBounds(
    math.min(a.left, b.left),
    math.min(a.top, b.top),
    math.max(a.right, b.right),
    math.max(a.bottom, b.bottom),
  );

  static double _n(XmlElement element, String name) => parseLength(element.getAttribute(name)) ?? 0;

  static List<double> _numbers(String text) =>
      text.trim().split(RegExp(r'[\s,]+')).map(double.tryParse).whereType<double>().toList();

  static SvgBounds? _points(List<double> numbers) {
    if (numbers.length < 4) return null;
    final box = _Box()..add(numbers[0], numbers[1]);
    for (var i = 0; i + 1 < numbers.length; i += 2) {
      box.add(numbers[i], numbers[i + 1]);
    }
    return box.toBounds();
  }

  // ------------------------------------------------------------ transforms

  static final _function = RegExp(r'(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)');

  static Affine _parseTransform(String text) {
    var matrix = Affine.identity;
    for (final match in _function.allMatches(text)) {
      final v = _numbers(match.group(2)!);
      final Affine? next = switch (match.group(1)) {
        'matrix' when v.length == 6 => Affine(v[0], v[1], v[2], v[3], v[4], v[5]),
        'translate' when v.isNotEmpty => Affine.translate(v[0], v.length > 1 ? v[1] : 0),
        'scale' when v.isNotEmpty => Affine(v[0], 0, 0, v.length > 1 ? v[1] : v[0], 0, 0),
        'rotate' when v.isNotEmpty => _rotate(
          v[0],
          v.length > 2 ? v[1] : 0,
          v.length > 2 ? v[2] : 0,
        ),
        'skewX' when v.isNotEmpty => Affine(1, 0, math.tan(v[0] * math.pi / 180), 1, 0, 0),
        'skewY' when v.isNotEmpty => Affine(1, math.tan(v[0] * math.pi / 180), 0, 1, 0, 0),
        _ => null,
      };
      if (next != null) matrix = matrix.multiply(next);
    }
    return matrix;
  }

  static Affine _rotate(double degrees, double cx, double cy) {
    final r = degrees * math.pi / 180;
    final rotation = Affine(math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0);
    return Affine.translate(cx, cy).multiply(rotation).multiply(Affine.translate(-cx, -cy));
  }

  // ------------------------------------------------------------------ paths

  static SvgBounds? _pathBounds(String d) {
    final scan = _PathScanner(d);
    final box = _Box();
    var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
    // The previous control point, for the smooth commands S and T.
    var lastCx = 0.0, lastCy = 0.0;
    String? command;
    var previous = '';
    while (!scan.done) {
      final next = scan.command();
      if (next != null) command = next;
      if (command == null) return null;
      final relative = command.toLowerCase() == command;
      final kind = command.toLowerCase();
      if (kind == 'z') {
        x = startX;
        y = startY;
        previous = 'z';
        command = null;
        continue;
      }
      final ox = relative ? x : 0.0;
      final oy = relative ? y : 0.0;
      switch (kind) {
        case 'm':
          final p = scan.numbers(2);
          if (p == null) return box.toBounds();
          x = ox + p[0];
          y = oy + p[1];
          startX = x;
          startY = y;
          box.add(x, y);
          // More pairs after a moveto are linetos.
          command = relative ? 'l' : 'L';
        case 'l':
          final p = scan.numbers(2);
          if (p == null) return box.toBounds();
          x = ox + p[0];
          y = oy + p[1];
          box.add(x, y);
        case 'h':
          final p = scan.numbers(1);
          if (p == null) return box.toBounds();
          x = ox + p[0];
          box.add(x, y);
        case 'v':
          final p = scan.numbers(1);
          if (p == null) return box.toBounds();
          y = oy + p[0];
          box.add(x, y);
        case 'c' || 's':
          final p = scan.numbers(kind == 'c' ? 6 : 4);
          if (p == null) return box.toBounds();
          final x1 = kind == 'c' ? ox + p[0] : (previous == 'c' ? 2 * x - lastCx : x);
          final y1 = kind == 'c' ? oy + p[1] : (previous == 'c' ? 2 * y - lastCy : y);
          final k = kind == 'c' ? 2 : 0;
          final x2 = ox + p[k], y2 = oy + p[k + 1];
          final x3 = ox + p[k + 2], y3 = oy + p[k + 3];
          _cubic(box, x, y, x1, y1, x2, y2, x3, y3);
          lastCx = x2;
          lastCy = y2;
          x = x3;
          y = y3;
        case 'q' || 't':
          final p = scan.numbers(kind == 'q' ? 4 : 2);
          if (p == null) return box.toBounds();
          final x1 = kind == 'q' ? ox + p[0] : (previous == 'q' ? 2 * x - lastCx : x);
          final y1 = kind == 'q' ? oy + p[1] : (previous == 'q' ? 2 * y - lastCy : y);
          final k = kind == 'q' ? 2 : 0;
          final x2 = ox + p[k], y2 = oy + p[k + 1];
          _quadratic(box, x, y, x1, y1, x2, y2);
          lastCx = x1;
          lastCy = y1;
          x = x2;
          y = y2;
        case 'a':
          final p = scan.arc();
          if (p == null) return box.toBounds();
          final ex = ox + p[5], ey = oy + p[6];
          _arc(box, x, y, p[0], p[1], p[2], p[3] != 0, p[4] != 0, ex, ey);
          x = ex;
          y = ey;
        default:
          return box.toBounds();
      }
      previous = kind == 's' ? 'c' : (kind == 't' ? 'q' : kind);
    }
    return box.toBounds();
  }

  static void _cubic(
    _Box box,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    box.add(x0, y0);
    box.add(x3, y3);
    for (final t in [..._roots(x0, x1, x2, x3), ..._roots(y0, y1, y2, y3)]) {
      final u = 1 - t;
      double at(double p0, double p1, double p2, double p3) =>
          u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
      box.add(at(x0, x1, x2, x3), at(y0, y1, y2, y3));
    }
  }

  /// The `t` in (0, 1) where one coordinate of a cubic stops growing.
  static List<double> _roots(double p0, double p1, double p2, double p3) {
    final a = -p0 + 3 * p1 - 3 * p2 + p3;
    final b = 2 * (p0 - 2 * p1 + p2);
    final c = p1 - p0;
    final roots = <double>[];
    if (a.abs() < 1e-12) {
      if (b.abs() > 1e-12) roots.add(-c / b);
    } else {
      final disc = b * b - 4 * a * c;
      if (disc >= 0) {
        final s = math.sqrt(disc);
        roots
          ..add((-b + s) / (2 * a))
          ..add((-b - s) / (2 * a));
      }
    }
    return roots.where((t) => t > 0 && t < 1).toList();
  }

  static void _quadratic(
    _Box box,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    box.add(x0, y0);
    box.add(x2, y2);
    double? root(double p0, double p1, double p2) {
      final denom = p0 - 2 * p1 + p2;
      if (denom.abs() < 1e-12) return null;
      final t = (p0 - p1) / denom;
      return t > 0 && t < 1 ? t : null;
    }

    for (final t in [root(x0, x1, x2), root(y0, y1, y2)].whereType<double>()) {
      final u = 1 - t;
      box.add(u * u * x0 + 2 * u * t * x1 + t * t * x2, u * u * y0 + 2 * u * t * y1 + t * t * y2);
    }
  }

  /// An elliptical arc by its endpoints (SVG spec, appendix B.2.4), measured
  /// by walking along it.
  static void _arc(
    _Box box,
    double x1,
    double y1,
    double rx,
    double ry,
    double degrees,
    bool large,
    bool sweep,
    double x2,
    double y2,
  ) {
    box.add(x1, y1);
    box.add(x2, y2);
    rx = rx.abs();
    ry = ry.abs();
    if (rx == 0 || ry == 0 || (x1 == x2 && y1 == y2)) return;
    final phi = degrees * math.pi / 180;
    final cosPhi = math.cos(phi), sinPhi = math.sin(phi);
    final dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
    final x1p = cosPhi * dx + sinPhi * dy;
    final y1p = -sinPhi * dx + cosPhi * dy;
    final scale = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry);
    if (scale > 1) {
      rx *= math.sqrt(scale);
      ry *= math.sqrt(scale);
    }
    final numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    final denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    final factor = (large == sweep ? -1 : 1) * math.sqrt(math.max(0, numerator / denominator));
    final cxp = factor * rx * y1p / ry;
    final cyp = -factor * ry * x1p / rx;
    final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
    final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;
    double angle(double ux, double uy, double vx, double vy) {
      final dot = ux * vx + uy * vy;
      final length = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
      final a = math.acos((dot / length).clamp(-1.0, 1.0));
      return ux * vy - uy * vx < 0 ? -a : a;
    }

    final start = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    var sweepAngle = angle(
      (x1p - cxp) / rx,
      (y1p - cyp) / ry,
      (-x1p - cxp) / rx,
      (-y1p - cyp) / ry,
    );
    if (!sweep && sweepAngle > 0) sweepAngle -= 2 * math.pi;
    if (sweep && sweepAngle < 0) sweepAngle += 2 * math.pi;
    const steps = 48;
    for (var i = 1; i < steps; i++) {
      final t = start + sweepAngle * i / steps;
      box.add(
        cx + rx * math.cos(t) * cosPhi - ry * math.sin(t) * sinPhi,
        cy + rx * math.cos(t) * sinPhi + ry * math.sin(t) * cosPhi,
      );
    }
  }
}

/// A box that grows to hold the points added to it.
class _Box {
  double? _l, _t, _r, _b;

  void add(double x, double y) {
    _l = _l == null ? x : math.min(_l!, x);
    _r = _r == null ? x : math.max(_r!, x);
    _t = _t == null ? y : math.min(_t!, y);
    _b = _b == null ? y : math.max(_b!, y);
  }

  SvgBounds? toBounds() => _l == null ? null : SvgBounds(_l!, _t!, _r!, _b!);
}

/// Reads path data (`M 0 0 l 1-2 a 1 1 0 011 1 z`): commands, then numbers,
/// with the separators SVG allows (none before a minus, the arc flags glued
/// to what follows).
class _PathScanner {
  _PathScanner(this._text);

  final String _text;
  var _i = 0;

  static final _number = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

  void _skip() {
    while (_i < _text.length && (' \t\r\n,'.contains(_text[_i]))) {
      _i++;
    }
  }

  bool get done {
    _skip();
    return _i >= _text.length;
  }

  /// The command letter at the cursor, or null when numbers follow (the
  /// previous command repeats).
  String? command() {
    _skip();
    if (_i < _text.length && RegExp('[A-Za-z]').hasMatch(_text[_i])) return _text[_i++];
    return null;
  }

  double? _one() {
    _skip();
    final match = _number.matchAsPrefix(_text, _i);
    if (match == null) return null;
    _i = match.end;
    return double.tryParse(match.group(0)!);
  }

  List<double>? numbers(int count) {
    final out = <double>[];
    for (var k = 0; k < count; k++) {
      final v = _one();
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  /// rx ry rotation large-arc sweep x y; the two flags are one digit each.
  List<double>? arc() {
    final head = numbers(3);
    if (head == null) return null;
    final flags = <double>[];
    for (var k = 0; k < 2; k++) {
      _skip();
      if (_i >= _text.length || (_text[_i] != '0' && _text[_i] != '1')) return null;
      flags.add(_text[_i] == '1' ? 1 : 0);
      _i++;
    }
    final tail = numbers(2);
    return tail == null ? null : [...head, ...flags, ...tail];
  }
}
