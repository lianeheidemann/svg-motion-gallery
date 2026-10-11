import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement _first(String body, {String tag = 'path'}) {
  final doc = XmlDocument.parse('<svg xmlns="http://www.w3.org/2000/svg">$body</svg>');
  return doc.rootElement.descendantElements.firstWhere((e) => e.localName == tag);
}

SvgBounds _bounds(String body, {String tag = 'path'}) =>
    SvgGeometry.rootBounds(_first(body, tag: tag))!;

void main() {
  group('shapes', () {
    test('rect, circle, ellipse, line, polygon', () {
      final rect = _bounds('<rect x="2" y="3" width="10" height="4"/>', tag: 'rect');
      expect([rect.left, rect.top, rect.right, rect.bottom], [2, 3, 12, 7]);
      final circle = _bounds('<circle cx="5" cy="5" r="2"/>', tag: 'circle');
      expect([circle.left, circle.bottom], [3, 7]);
      final poly = _bounds('<polygon points="0,0 10,2 4,8"/>', tag: 'polygon');
      expect([poly.right, poly.bottom], [10, 8]);
    });
  });

  group('paths', () {
    test('lines with absolute and relative commands', () {
      final box = _bounds('<path d="M10 10 L20 10 l0 15 h-5 v-5 z"/>');
      expect([box.left, box.top, box.right, box.bottom], [10, 10, 20, 25]);
    });

    test('a curve is measured by its real extent, not its control points', () {
      // The control points reach y=0, the curve itself only y=7.5.
      final box = _bounds('<path d="M0 10 C0 0 10 0 10 10"/>');
      expect(box.top, closeTo(2.5, 1e-9));
      expect(box.bottom, 10);
      final quad = _bounds('<path d="M0 10 Q5 0 10 10"/>');
      expect(quad.top, closeTo(5, 1e-9));
    });

    test('arcs: a circle drawn as two arcs, flags glued to the numbers', () {
      final circle = _bounds('<path d="M10 20a10 10 0 1 0 20 0a10 10 0 1 0-20 0z"/>');
      expect(circle.left, closeTo(10, 0.1));
      expect(circle.right, closeTo(30, 0.1));
      expect(circle.top, closeTo(10, 0.1));
      expect(circle.bottom, closeTo(30, 0.1));
      final glued = _bounds('<path d="M0 0a5 5 0 0110 0"/>');
      expect(glued.top, closeTo(-5, 0.1));
    });

    test('smooth curves and number formats', () {
      final box = _bounds('<path d="M0 0c1-1 2-1 3 0s2 1 3 0 T9 0"/>');
      expect(box.right, 9);
      expect(_bounds('<path d="M.5.5L1.5,2.5"/>').bottom, 2.5);
    });
  });

  group('transforms', () {
    test('an element, its group and nested groups', () {
      final box = _bounds(
        '<g transform="translate(100 0)"><g transform="scale(2)">'
        '<rect width="10" height="5" transform="translate(1 1)"/></g></g>',
        tag: 'rect',
      );
      expect([box.left, box.top, box.right, box.bottom], [102, 2, 122, 12]);
    });

    test('rotate and matrix', () {
      final box = _bounds('<rect width="10" height="2" transform="rotate(90)"/>', tag: 'rect');
      expect([box.left, box.right], [closeTo(-2, 1e-9), closeTo(0, 1e-9)]);
      expect(
        SvgGeometry.toRoot(_first('<g transform="matrix(2 0 0 2 5 5)"><rect/></g>', tag: 'rect')),
        const Affine(2, 0, 0, 2, 5, 5),
      );
    });

    test('an editor wrapper turns around the center of what is inside it', () {
      final box = _bounds(
        '<g data-sm-edit="element" transform="rotate(90)"><rect x="0" y="0" width="10" height="2"/></g>',
        tag: 'rect',
      );
      // Turned a quarter around (5, 1): 10 wide, 2 tall becomes 2 wide, 10 tall.
      expect(box.width, closeTo(2, 1e-9));
      expect(box.height, closeTo(10, 1e-9));
      expect(box.centerX, closeTo(5, 1e-9));
      expect(box.centerY, closeTo(1, 1e-9));
    });

    test('an inverse undoes it', () {
      const m = Affine(2, 1, -1, 3, 7, -4);
      final p = m.apply(3, 5);
      final back = m.inverse!.apply(p.$1, p.$2);
      expect(back.$1, closeTo(3, 1e-9));
      expect(back.$2, closeTo(5, 1e-9));
      expect(const Affine(0, 0, 0, 0, 1, 1).inverse, isNull);
    });
  });

  test('a group is the union of its children', () {
    final box = SvgGeometry.rootBounds(
      _first('<g><rect width="4" height="4"/><circle cx="20" cy="20" r="2"/></g>', tag: 'g'),
    )!;
    expect([box.left, box.top, box.right, box.bottom], [0, 0, 22, 22]);
  });
}
