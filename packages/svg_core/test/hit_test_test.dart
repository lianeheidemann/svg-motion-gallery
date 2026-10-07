import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<defs/>'
    '<rect x="10" y="10" width="20" height="20" fill="red"/>'
    '<circle cx="70" cy="70" r="10" fill="blue"/>'
    '<path d="M0 0L5 5" stroke="red"/>'
    '</svg>';

void main() {
  group('SvgHitTest', () {
    test('finds top-level shapes and ignores paths', () {
      final movables = SvgHitTest.movables(_svg);
      expect(movables.map((m) => m.path), [
        const ElementPath([1]),
        const ElementPath([2]),
      ]);
    });

    test('hits the shape under a point, with tolerance', () {
      expect(SvgHitTest.at(_svg, 20, 20)?.path, const ElementPath([1]));
      expect(SvgHitTest.at(_svg, 70, 70)?.path, const ElementPath([2]));
      expect(SvgHitTest.at(_svg, 50, 50), isNull);
      expect(SvgHitTest.at(_svg, 33, 20), isNull);
      expect(SvgHitTest.at(_svg, 33, 20, slop: 5)?.path, const ElementPath([1]));
    });

    test('follows the shape after it was moved', () {
      final moved = SvgTransformEdit.apply(
        _svg,
        const ElementPath([1]),
        const SvgTransformValues(translateX: 40),
      );
      expect(SvgHitTest.at(moved.svg, 20, 20), isNull);
      expect(SvgHitTest.at(moved.svg, 60, 20), isNotNull);
    });

    test('measures text by anchor', () {
      final inserted = SvgInsertEdit.insert(_svg, SvgShapeKind.text, color: '#FFFFFF', text: 'Oi');
      final hit = SvgHitTest.at(inserted.svg, 50, 50);
      expect(hit?.path, inserted.selection);
    });
  });
}
