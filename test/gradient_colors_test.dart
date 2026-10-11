import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';

import 'helpers.dart';

const _red =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#FF0000"/></svg>';

/// Imports `red.svg`, opens it in the editor, selects the rectangle and opens
/// the Colors tab.
Future<AppServices> _openColors(
  WidgetTester tester, {
  String svg = _red,
  bool select = true,
}) async {
  final services = (await tester.runAsync(
    () => createTestServices(importFiles: [(name: 'red.svg', content: svg)]),
  ))!;
  await pumpApp(tester, services);
  await tester.tap(find.text('Importar SVG'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 6)); // let the snack bar go
  await tester.pumpAndSettle();
  await tester.tap(find.text('red.svg'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('edit-svg')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('edit-svg')));
  await tester.pumpAndSettle();
  if (select) {
    await _tapTab(tester, 'Camadas');
    await tester.tap(find.text('Retângulo'));
    await tester.pumpAndSettle();
  }
  await _tapTab(tester, 'Cores');
  return services;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.byTooltip(label, skipOffstage: false);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickPreset(WidgetTester tester, String hex) async {
  final swatch = find.descendant(
    of: find.byKey(const Key('preset-palette')),
    matching: find.bySemanticsLabel(hex),
  );
  await tester.ensureVisible(swatch);
  await tester.pumpAndSettle();
  await tester.tap(swatch);
  await tester.pumpAndSettle();
}

Future<void> _pickKind(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byKey(const Key('paint-kind')),
    matching: find.text(label),
  );
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

Future<String> _save(WidgetTester tester, AppServices services) async {
  await tester.tap(find.byKey(const Key('save')));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  final doc = services.library.documents.firstWhere((d) => d.name == 'red.svg');
  return services.library.contentOf(doc).toUpperCase();
}

int _count(String text, String pattern) => RegExp(pattern).allMatches(text).length;

void main() {
  testWidgets('gradient: Linear turns the fill into a gradient that starts at its color', (
    tester,
  ) async {
    final services = await _openColors(tester);
    expect(find.byKey(const Key('gradient-bar')), findsNothing);

    await _pickKind(tester, 'Linear');
    expect(find.byKey(const Key('gradient-bar')), findsOneWidget);
    expect(find.byKey(const Key('gradient-angle')), findsOneWidget);

    final saved = await _save(tester, services);
    expect(saved, contains('FILL="URL(#SM-GRAD-1)"'));
    expect(saved, contains('<LINEARGRADIENT'));
    expect(saved, contains('STOP-COLOR="#FF0000"'));
  });

  testWidgets('gradient: the palette paints the selected stop', (tester) async {
    final services = await _openColors(tester);
    await _pickKind(tester, 'Linear');

    await _tapKey(tester, 'gradient-stop-1'); // the stop is already selected by tapping
    await _pickPreset(tester, '#3B82F6');
    final saved = await _save(tester, services);
    expect(saved, contains('STOP-COLOR="#FF0000"'));
    expect(saved, contains('STOP-COLOR="#3B82F6"'));
  });

  testWidgets('gradient: add, remove, reverse and the radial kind', (tester) async {
    final services = await _openColors(tester);
    await _pickKind(tester, 'Linear');
    // One row, with the stop buttons right under the strip and "add" filled.
    double middle(String key) => tester.getCenter(find.byKey(Key(key))).dy;
    expect(middle('gradient-reverse'), middle('gradient-remove'));
    expect(middle('gradient-remove'), middle('gradient-add'));
    expect(
      middle('gradient-add'),
      greaterThan(tester.getBottomLeft(find.byKey(const Key('gradient-bar'))).dy),
    );
    expect(
      middle('gradient-add'),
      lessThan(tester.getTopLeft(find.byKey(const Key('gradient-angle'))).dy),
    );
    expect(find.byType(FilledButton), findsWidgets);
    expect(tester.widget(find.byKey(const Key('gradient-add'))), isA<FilledButton>());
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('gradient-remove'))).onPressed,
      isNull,
      reason: 'a gradient keeps two stops',
    );

    await _tapKey(tester, 'gradient-add');
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('gradient-remove'))).onPressed,
      isNotNull,
    );
    await _tapKey(tester, 'gradient-reverse');
    await _pickKind(tester, 'Radial');
    expect(find.byKey(const Key('gradient-angle')), findsNothing);

    final saved = await _save(tester, services);
    expect(_count(saved, '<STOP '), 3);
    expect(saved, contains('<RADIALGRADIENT'));
    expect(saved, isNot(contains('LINEARGRADIENT')));

    await _tapKey(tester, 'gradient-remove');
    expect(_count(await _save(tester, services), '<STOP '), 2);
  });

  testWidgets('gradient: Solid brings back a plain color and drops the gradient; undo returns it', (
    tester,
  ) async {
    final services = await _openColors(tester);
    await _pickKind(tester, 'Linear');
    await _pickKind(tester, 'Sólido');
    expect(find.byKey(const Key('gradient-bar')), findsNothing);
    var saved = await _save(tester, services);
    expect(saved, contains('FILL="#FF0000"'));
    expect(saved, isNot(contains('GRADIENT')));

    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gradient-bar')), findsOneWidget);
    saved = await _save(tester, services);
    expect(saved, contains('<LINEARGRADIENT'));
  });

  testWidgets('gradient: the hue ruler turns every stop and the reset puts them back', (
    tester,
  ) async {
    final services = await _openColors(tester);
    await _pickKind(tester, 'Linear');
    await _pickPreset(tester, '#3B82F6');

    final ruler = find.byKey(const Key('ruler'));
    await tester.ensureVisible(ruler);
    await tester.pumpAndSettle();
    await tester.drag(ruler, const Offset(-120, 0));
    await tester.pumpAndSettle();
    final turned = await _save(tester, services);
    expect(turned, isNot(contains('STOP-COLOR="#3B82F6"')));
    expect(turned, isNot(contains('STOP-COLOR="#FF0000"')));
    expect(_count(turned, '<STOP '), 2);

    await _tapKey(tester, 'adjust-reset');
    final back = await _save(tester, services);
    expect(back, contains('STOP-COLOR="#3B82F6"'));
  });

  testWidgets('gradient: shapes whose color is not on them (default, stylesheet) get it too', (
    tester,
  ) async {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<style>.eye{fill:#223344}.smile{fill:none;stroke:#112233;stroke-width:3}</style>'
        '<rect width="10" height="10" fill="#FF0000"/>'
        '<rect x="20" width="10" height="10"/>'
        '<circle class="eye" cx="50" cy="5" r="5"/>'
        '<path class="smile" d="M60 5 Q65 15 70 5"/>'
        '</svg>';
    final services = await _openColors(tester, svg: svg, select: false);
    await _pickKind(tester, 'Linear');

    final saved = await _save(tester, services);
    expect(_count(saved, 'FILL="URL\\(#SM-GRAD'), 3, reason: 'both rects and the circle');
    expect(_count(saved, 'STROKE="URL\\(#SM-GRAD'), 1, reason: 'the outline-only smile');
    expect(saved, contains('STOP-COLOR="#000000"'), reason: 'the default black fill');
    expect(saved, contains('STOP-COLOR="#223344"'), reason: 'the stylesheet color');
    expect(saved, contains('STOP-COLOR="#112233"'));
  });

  testWidgets('gradient: one continuous gradient across the selection, and back', (tester) async {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<rect width="10" height="10" fill="#FF0000"/>'
        '<rect x="90" width="10" height="10" fill="#00FF00"/>'
        '</svg>';
    final services = await _openColors(tester, svg: svg, select: false);
    await _pickKind(tester, 'Linear');
    var saved = await _save(tester, services);
    expect(saved, isNot(contains('DATA-SM-SPAN')), reason: 'a gradient on each shape at first');
    expect(_count(saved, '<LINEARGRADIENT'), 2);

    await _tapKey(tester, 'gradient-span');
    saved = await _save(tester, services);
    expect(saved, contains('GRADIENTUNITS="USERSPACEONUSE"'));
    expect(saved, contains('DATA-SM-SPAN="0 0 100 10"'));
    expect(_count(saved, '<LINEARGRADIENT'), 1, reason: 'both shapes share the coordinates');
    expect(saved, contains('X1="0"'));
    expect(saved, contains('X2="100"'));

    // The angle keeps working across the whole box.
    final slider = find.byKey(const Key('gradient-angle'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pumpAndSettle();
    saved = await _save(tester, services);
    expect(saved, contains('DATA-SM-SPAN="0 0 100 10"'));
    expect(saved, isNot(contains('X1="0" Y1="5" X2="100"')));

    await _tapKey(tester, 'gradient-span');
    saved = await _save(tester, services);
    expect(saved, isNot(contains('DATA-SM-SPAN')));
    expect(saved, isNot(contains('USERSPACEONUSE')));
  });

  testWidgets('gradient: the continuous mode needs more than one shape', (tester) async {
    await _openColors(tester);
    await _pickKind(tester, 'Linear');
    expect(tester.widget<IconButton>(find.byKey(const Key('gradient-span'))).onPressed, isNull);
  });
}
