import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/align_panel.dart';
import 'package:svg_motion_gallery/src/l10n/l10n.dart';
import 'package:svg_view/src/playback_controller.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect x="40" y="40" width="20" height="20"/></svg>';

class _Renderer implements SvgPlaybackTarget {
  final calls = <(String, List<Object?>)>[];

  @override
  void invoke(String method, [List<Object?> arguments = const []]) =>
      calls.add((method, arguments));
}

Future<void> _pump(WidgetTester tester, EditorController editor, SvgPlaybackController playback) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: editor,
            builder: (context, _) => AlignPanel(editor: editor, playback: playback),
          ),
        ),
      ),
    );

void main() {
  testWidgets('align buttons are off until a layer is selected', (tester) async {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    await _pump(tester, editor, SvgPlaybackController());
    expect(tester.widget<IconButton>(find.byKey(const Key('align-left'))).onPressed, isNull);
    editor.select(const ElementPath([0]));
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(const Key('align-left'))).onPressed, isNotNull);
  });

  testWidgets('aligning moves the layer by what the renderer measured', (tester) async {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    final playback = SvgPlaybackController();
    final renderer = _Renderer();
    // ignore: invalid_use_of_internal_member
    playback.attach(renderer);
    editor.select(const ElementPath([0]));
    playback.selectElement([0]);
    await _pump(tester, editor, playback);

    await tester.tap(find.byKey(const Key('align-left')));
    await tester.pump();
    expect(renderer.calls.last.$1, 'alignSelection');
    expect(renderer.calls.last.$2, ['start', '']);
    // ignore: invalid_use_of_internal_member
    playback.reportMeasure([-40, 0, 0, 0]);
    await tester.pumpAndSettle();
    expect(SvgTransformEdit.read(editor.svg, editor.selection!).translateX, -40);

    // A second alignment adds to the first move instead of starting over.
    await tester.tap(find.byKey(const Key('align-top')));
    await tester.pump();
    // ignore: invalid_use_of_internal_member
    playback.reportMeasure([0, -40, 0, 0]);
    await tester.pumpAndSettle();
    final values = SvgTransformEdit.read(editor.svg, editor.selection!);
    expect((values.translateX, values.translateY), (-40, -40));
  });
}
