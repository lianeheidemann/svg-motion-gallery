import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<g><rect width="2" height="2" fill="url(#a)"/><circle r="1" fill="red"/></g>'
    '<rect class="bg" width="1" height="1"/></svg>';

void main() {
  test('painting a group paints the shapes inside it', () {
    final editor = EditorController(_svg)..select(const ElementPath([0]));
    addTearDown(editor.dispose);
    expect(editor.paintTargets, const [
      ElementPath([0, 0]),
      ElementPath([0, 1]),
    ]);
  });

  test('with nothing selected every shape is painted once, groups left out', () {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    expect(editor.paintTargets, const [
      ElementPath([0, 0]),
      ElementPath([0, 1]),
      ElementPath([1]),
    ]);
  });

  test('a fill set on an element with a class also goes inline, to beat the stylesheet', () {
    final out = SvgPaintEdit.setFill(_svg, const ElementPath([1]), '#112233');
    expect(out, contains('fill="#112233"'));
    expect(out, contains('style="fill:#112233"'));
  });
}
