import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';

import 'helpers.dart';

const _red =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#FF0000"/></svg>';

/// Imports `red.svg` and opens it in the editor.
Future<AppServices> _openRedInEditor(WidgetTester tester) async {
  final services = (await tester.runAsync(
    () => createTestServices(importFiles: [(name: 'red.svg', content: _red)]),
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
  return services;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.byTooltip(label, skipOffstage: false);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// Selects the layer named [label] in the Layers tab, then opens Colors.
Future<void> _selectLayerThenColors(WidgetTester tester, String label) async {
  await _tapTab(tester, 'Camadas');
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await _tapTab(tester, 'Cores');
}

/// Taps a swatch of the ready-made palette by its hex code.
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

Future<String> _save(WidgetTester tester, AppServices services) async {
  await tester.tap(find.byKey(const Key('save')));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  expect(find.text('Alterações salvas'), findsOneWidget);
  final doc = services.library.documents.firstWhere((d) => d.name == 'red.svg');
  return services.library.contentOf(doc).toUpperCase();
}

void main() {
  testWidgets('colors: only the selected layers are painted, no document / layer switch', (
    tester,
  ) async {
    await _openRedInEditor(tester);
    await _tapTab(tester, 'Cores');

    // Nothing selected ("Todas"): the palette paints every layer.
    expect(find.text('Documento'), findsNothing);
    expect(find.text('Camada'), findsNothing);
    expect(find.textContaining('Selecione uma camada'), findsNothing);
    expect(find.byKey(const Key('preset-palette')), findsOneWidget);

    await _selectLayerThenColors(tester, 'Retângulo');
    expect(find.textContaining('Selecione uma camada'), findsNothing);
    expect(find.text('Documento'), findsNothing);
    expect(find.byKey(const Key('preset-palette')), findsOneWidget);
  });

  testWidgets('the rainbow swatch opens a free picker that recolors the layer', (tester) async {
    final services = await _openRedInEditor(tester);
    await _selectLayerThenColors(tester, 'Retângulo');

    expect(find.byKey(const Key('color-area')), findsNothing);
    final custom = find.byKey(const Key('custom-color'));
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    await tester.tap(custom);
    await tester.pumpAndSettle();
    final area = find.byKey(const Key('color-area'));
    expect(area, findsOneWidget);

    final box = tester.getRect(
      find.descendant(of: area, matching: find.byType(GestureDetector)).first,
    );
    await tester.tapAt(box.topLeft + const Offset(2, 2)); // white corner
    await tester.pumpAndSettle();
    final saved = await _save(tester, services);
    expect(saved, isNot(contains('#FF0000')));
    expect(saved, matches(RegExp(r'FILL="#F[A-F]{5}"')), reason: 'almost white');
  });

  testWidgets('layer paint: the same palette sets the fill of the selected layer', (tester) async {
    final services = await _openRedInEditor(tester);
    await _tapTab(tester, 'Camadas');
    await tester.tap(find.text('Retângulo'));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Cores');

    await _pickPreset(tester, '#3B82F6');
    final saved = await _save(tester, services);
    expect(saved, contains('FILL="#3B82F6"'));
  });
}
