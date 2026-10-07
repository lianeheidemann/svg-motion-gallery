import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/window_panel.dart';
import 'package:svg_motion_gallery/src/l10n/l10n.dart';
import 'package:svg_view/src/playback_controller.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100">'
    '<rect x="150" y="20" width="100" height="60"/></svg>';

class _Renderer implements SvgPlaybackTarget {
  final calls = <String>[];

  @override
  void invoke(String method, [List<Object?> arguments = const []]) => calls.add(method);
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
            builder: (context, _) => WindowPanel(editor: editor, playback: playback),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a new proportion refits the drawing; there are no position sliders', (tester) async {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    final playback = SvgPlaybackController();
    final renderer = _Renderer();
    // ignore: invalid_use_of_internal_member
    playback.attach(renderer);
    await _pump(tester, editor, playback);

    expect(find.text('Posição X'), findsNothing);
    expect(find.text('Posição Y'), findsNothing);

    await tester.tap(find.byKey(const Key('ratio-1:1')));
    await tester.pump();
    expect(renderer.calls, contains('measure'));
    // The drawing: 100 x 60 at (150, 20), plus the 4 % margin of its larger side.
    // ignore: invalid_use_of_internal_member
    playback.reportMeasure([150, 20, 100, 60]);
    await tester.pumpAndSettle();
    final window = editor.metadata.canvas;
    expect(window.width, closeTo(window.height, 0.001), reason: 'square now');
    expect(window.width, closeTo(108, 0.001), reason: '100 + 2 x 4 margin, the larger side');
    expect(window.centerX, closeTo(200, 0.001));
    expect(window.centerY, closeTo(50, 0.001));
  });

  testWidgets('without a measure the window grows around itself, cutting nothing', (tester) async {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    await _pump(tester, editor, SvgPlaybackController());
    await tester.tap(find.byKey(const Key('ratio-1:1')));
    await tester.pumpAndSettle();
    final window = editor.metadata.canvas;
    expect(window.width, closeTo(400, 0.001));
    expect(window.height, closeTo(400, 0.001));
    expect(window.centerY, closeTo(50, 0.001));
  });
}
