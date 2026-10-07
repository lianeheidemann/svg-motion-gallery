import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/animation_panel.dart';
import 'package:svg_motion_gallery/src/l10n/l10n.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<rect width="10" height="10"><animate attributeName="x" from="0" to="5" dur="2s"/></rect>'
    '</svg>';

void main() {
  testWidgets('the speed bar keeps its value and never compounds', (tester) async {
    final editor = EditorController(_svg);
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: editor,
            builder: (context, _) => AnimationPanel(editor: editor),
          ),
        ),
      ),
    );

    Slider bar() => tester.widget<Slider>(find.byType(Slider).first);

    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();
    final first = bar().value;
    expect(first, greaterThan(1), reason: 'the bar stays where it was released');
    expect(editor.svg, contains('dur="${formatClockValue(2 / first)}"'));

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    final second = bar().value;
    expect(second, isNot(first));
    expect(
      editor.svg,
      contains('dur="${formatClockValue(2 / second)}"'),
      reason: 'computed from the original, not from the previous change',
    );

    editor.undo();
    await tester.pumpAndSettle();
    expect(bar().value, 1, reason: 'after undo the bar starts over from the document');
  });
}
