import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const _base = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"></svg>';

String _strokeWidths(String svg) =>
    RegExp(r'stroke-width="([^"]+)"').allMatches(svg).map((m) => m.group(1)).join(',');

void main() {
  group('SvgShapeSize', () {
    test('stretching a rectangle moves its geometry and keeps the outline width', () {
      final inserted = SvgInsertEdit.insert(
        _base,
        SvgShapeKind.rectangle,
        color: '#112233',
        strokeWidth: 3,
      );
      final path = inserted.selection!;
      final stretched = SvgShapeSize.stretch(inserted.svg, path, width: 2, height: 0.5)!;

      expect(_strokeWidths(stretched.svg), '3');
      expect(stretched.svg, isNot(contains('transform')));
      expect(stretched.selection, path);
      final factors = SvgShapeSize.read(stretched.svg, path);
      expect((factors.size, factors.width, factors.height), (1.0, 2.0, 0.5));
      // The original rectangle is a 30 x 30 square at the center.
      expect(stretched.svg, contains('width="60"'));
      expect(stretched.svg, contains('height="15"'));
      expect(stretched.svg, contains('x="20"'), reason: 'still centered');
      expect(stretched.svg, contains('y="42.5"'));
    });

    test('stretching back to 100% restores the shape', () {
      final inserted = SvgInsertEdit.insert(_base, SvgShapeKind.ellipse, color: '#112233');
      final path = inserted.selection!;
      final wide = SvgShapeSize.stretch(inserted.svg, path, width: 3)!;
      final back = SvgShapeSize.stretch(wide.svg, path, width: 1)!;
      expect(back.svg, inserted.svg);
    });

    test('size and width multiply, size alone keeps the proportions', () {
      final inserted = SvgInsertEdit.insert(_base, SvgShapeKind.ellipse, color: '#112233');
      final path = inserted.selection!;
      final big = SvgShapeSize.stretch(inserted.svg, path, size: 2)!;
      final wider = SvgShapeSize.stretch(big.svg, path, width: 1.5)!;
      // 30 side -> rx 21, ry 12; x2 -> 42, 24; width x1.5 -> 63, 24.
      expect(wider.svg, contains('rx="63"'));
      expect(wider.svg, contains('ry="24"'));
      expect(SvgShapeSize.read(wider.svg, path).size, 2);
    });

    test('a circle becomes an ellipse when it is stretched, and stays when not', () {
      final inserted = SvgInsertEdit.insert(
        _base,
        SvgShapeKind.circle,
        color: '#112233',
        strokeWidth: 2,
      );
      final path = inserted.selection!;
      final same = SvgShapeSize.stretch(inserted.svg, path, width: 1)!;
      expect(same.svg, contains('<circle'));

      final oval = SvgShapeSize.stretch(inserted.svg, path, width: 2)!;
      expect(oval.svg, isNot(contains('<circle')));
      expect(oval.svg, contains('<ellipse'));
      expect(oval.svg, contains('rx="30"'));
      expect(oval.svg, contains('ry="15"'));
      expect(_strokeWidths(oval.svg), '2');
    });

    test('lines and stars are stretched too', () {
      final line = SvgInsertEdit.insert(_base, SvgShapeKind.line, color: '#112233');
      final longer = SvgShapeSize.stretch(line.svg, line.selection!, width: 2)!;
      expect(longer.svg, contains('x1="20"'));
      expect(longer.svg, contains('x2="80"'));
      expect(_strokeWidths(longer.svg), _strokeWidths(line.svg));

      final star = SvgInsertEdit.insert(_base, SvgShapeKind.star, color: '#112233', strokeWidth: 4);
      final flat = SvgShapeSize.stretch(star.svg, star.selection!, height: 0.5)!;
      expect(flat.svg, isNot(equals(star.svg)));
      expect(_strokeWidths(flat.svg), '4');
      expect(SvgShapeSize.read(flat.svg, star.selection!).height, 0.5);
    });

    test('the wrapper the editor puts around a shape resolves to the shape', () {
      final inserted = SvgInsertEdit.insert(_base, SvgShapeKind.rectangle, color: '#112233');
      final moved = SvgTransformEdit.apply(
        inserted.svg,
        inserted.selection,
        const SvgTransformValues(translateX: 5, rotation: 20),
      );
      expect(SvgShapeSize.canStretch(moved.svg, moved.selection!), isTrue);
      final stretched = SvgShapeSize.stretch(moved.svg, moved.selection!, width: 2)!;
      expect(stretched.selection, moved.selection);
      expect(stretched.svg, contains('rotate(20)'), reason: 'the turn is kept');
      expect(SvgShapeSize.read(stretched.svg, moved.selection!).width, 2);
    });

    test('paths and text cannot be stretched this way', () {
      final text = SvgInsertEdit.insert(_base, SvgShapeKind.text, color: '#FFFFFF');
      expect(SvgShapeSize.canStretch(text.svg, text.selection!), isFalse);
      expect(SvgShapeSize.stretch(text.svg, text.selection!, width: 2), isNull);

      const withPath =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><path d="M0 0L5 5"/></svg>';
      expect(SvgShapeSize.stretch(withPath, const ElementPath([0]), width: 2), isNull);
      expect(SvgShapeSize.read(withPath, const ElementPath([0])).width, 1);
    });
  });
}
