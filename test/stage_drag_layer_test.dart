import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/features/editor/stage_drag_layer.dart';
import 'package:svg_motion_gallery/src/l10n/l10n.dart';

// A 100 x 100 canvas drawn at 200 x 200 px: two pixels per unit. The square
// sits on 40..60, so it is at 80..120 px.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect x="40" y="40" width="20" height="20"/></svg>';

Future<EditorController> _pump(WidgetTester tester) async {
  final editor = EditorController(_svg);
  addTearDown(editor.dispose);
  editor.select(const ElementPath([0]));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: ListenableBuilder(
            listenable: editor,
            builder: (context, _) => StageDragLayer(editor: editor, padding: EdgeInsets.zero),
          ),
        ),
      ),
    ),
  );
  return editor;
}

SvgTransformValues _values(EditorController editor) =>
    SvgTransformEdit.read(editor.svg, editor.selection);

void main() {
  testWidgets('moving, resizing and turning in a row keep what was done before', (tester) async {
    final editor = await _pump(tester);
    final origin = tester.getTopLeft(find.byType(StageDragLayer));

    // 1. Move 40 px right = 20 units.
    await tester.dragFrom(origin + const Offset(100, 100), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(_values(editor).translateX, closeTo(20, 1.5));

    // 2. Move again, 40 px down = 20 units: the first move must still be there.
    // The square is now centered on (120, 100) px.
    await tester.dragFrom(origin + const Offset(140, 100), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(_values(editor).translateX, closeTo(20, 1.5), reason: 'the first move is kept');
    expect(_values(editor).translateY, closeTo(20, 1.5));

    // 3. Resize with the corner handle: the position must not go back.
    final before = _values(editor);
    final handle = find.byKey(const Key('resize-handle'));
    await tester.drag(handle, const Offset(30, 30));
    await tester.pumpAndSettle();
    final resized = _values(editor);
    expect(resized.scale, greaterThan(before.scale));
    expect(resized.translateX, closeTo(before.translateX, 0.001), reason: 'resizing keeps x');
    expect(resized.translateY, closeTo(before.translateY, 0.001), reason: 'resizing keeps y');

    // 4. Turn with the top handle: neither position nor size go back.
    await tester.drag(find.byKey(const Key('rotate-handle')), const Offset(-40, 30));
    await tester.pumpAndSettle();
    final turned = _values(editor);
    expect(turned.rotation, isNot(0));
    expect(turned.translateX, closeTo(resized.translateX, 0.001));
    expect(turned.translateY, closeTo(resized.translateY, 0.001));
    expect(turned.scale, closeTo(resized.scale, 0.001), reason: 'turning keeps the size');
  });
}
