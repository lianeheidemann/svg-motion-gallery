import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_view/svg_view.dart';

import 'helpers.dart';

const _red =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#FF0000"/></svg>';

/// Imports `red.svg` and opens it in the editor.
Future<AppServices> _openRedInEditor(WidgetTester tester, {String svg = _red}) async {
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

  testWidgets('colors: the stage compares before and after with a draggable divider', (
    tester,
  ) async {
    await _openRedInEditor(tester);
    expect(find.byKey(const Key('before-after')), findsNothing);

    await _tapTab(tester, 'Cores');
    final compare = find.byKey(const Key('before-after'));
    expect(compare, findsOneWidget);
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Depois'), findsOneWidget);

    final handle = find.byIcon(Icons.compare_arrows_rounded);
    final before = tester.getCenter(handle).dx;
    await tester.dragFrom(tester.getCenter(handle), const Offset(80, 0));
    await tester.pump();
    expect(tester.getCenter(handle).dx, greaterThan(before + 40));

    await _tapTab(tester, 'Camadas');
    expect(find.byKey(const Key('before-after')), findsNothing);
  });

  testWidgets('colors: both previews sit still at the start so they show the same frame', (
    tester,
  ) async {
    await _openRedInEditor(tester);
    SvgPlaybackController? stage() =>
        tester.widgetList<SvgView>(find.byType(SvgView)).map((v) => v.controller).nonNulls.first;
    expect(stage()!.isPlaying, isTrue);

    // The stage's play button pauses and resumes.
    await tester.tap(find.byKey(const Key('stage-play')));
    await tester.pump();
    expect(stage()!.isPlaying, isFalse);
    await tester.tap(find.byKey(const Key('stage-play')));
    await tester.pump();
    expect(stage()!.isPlaying, isTrue);

    await _tapTab(tester, 'Cores');
    expect(stage()!.isPlaying, isFalse);
    expect(tester.widget<IconButton>(find.byKey(const Key('stage-play'))).onPressed, isNull);
    final views = tester.widgetList<SvgView>(find.byType(SvgView)).toList();
    expect(views, hasLength(2));
    final before = views.firstWhere((v) => v.controller == null);
    expect(before.autoplay, isFalse, reason: 'the original starts paused');

    await _tapTab(tester, 'Camadas');
    expect(stage()!.isPlaying, isTrue);
  });

  testWidgets('colors: painting everything leaves outline-only shapes alone', (tester) async {
    final services = await _openRedInEditor(
      tester,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<rect width="10" height="10" fill="#FF0000"/>'
          '<path d="M1 5 Q5 9 9 5" fill="none" stroke="#00FF00"/></svg>',
    );
    await _tapTab(tester, 'Cores');
    expect(find.text('Remover preenchimento'), findsNothing);
    await _pickPreset(tester, '#3B82F6');
    final saved = await _save(tester, services);
    expect(saved, contains('#3B82F6'));
    expect(saved, contains('FILL="NONE"'));
  });

  testWidgets('colors: the eyedropper takes the color of the shape that is tapped', (tester) async {
    final services = await _openRedInEditor(
      tester,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<rect width="5" height="10" fill="#0000FF"/>'
          '<rect x="5" width="5" height="10" fill="#00FF00"/></svg>',
    );
    await _tapTab(tester, 'Cores');
    await tester.tap(find.byKey(const Key('eyedropper')));
    await tester.pumpAndSettle();
    expect(find.text('Toque no desenho para pegar uma cor'), findsOneWidget);

    final layer = find.byKey(const Key('eyedropper-layer'));
    await tester.tapAt(tester.getCenter(layer) + const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eyedropper-layer')), findsNothing, reason: 'one pick per tap');

    final saved = await _save(tester, services);
    expect(saved, contains('#00FF00'));
    expect(saved, isNot(contains('#0000FF')), reason: 'everything took the picked green');
  });

  testWidgets('light/dark: the icon switches the version and colors go to that one only', (
    tester,
  ) async {
    final services = await _openRedInEditor(
      tester,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>.bg{fill:#000011}@media (prefers-color-scheme: light){.bg{fill:#EEEEFF}}</style>'
          '<rect class="bg" width="10" height="10"/></svg>',
    );
    // The test app is dark: that is the version shown first.
    final icon = find.byKey(const Key('theme-variant'));
    expect(icon, findsOneWidget);
    expect(find.byTooltip('Editando a versão escura — toque para a clara'), findsOneWidget);

    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Editando a versão clara — toque para a escura'), findsOneWidget);

    await _tapTab(tester, 'Cores');
    await _pickPreset(tester, '#3B82F6');
    final saved = await _save(tester, services);
    expect(saved, contains('#3B82F6'));
    expect(saved, contains('#000011'), reason: 'the dark version is untouched');
  });

  testWidgets('light/dark: a file without both versions has no icon', (tester) async {
    await _openRedInEditor(tester);
    expect(find.byKey(const Key('theme-variant')), findsNothing);
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
