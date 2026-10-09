import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';

import 'helpers.dart';

const _valid =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

Future<AppServices> _services(
  WidgetTester tester, {
  List<({String name, String content})> files = const [],
}) async => (await tester.runAsync(() => createTestServices(importFiles: files)))!;

/// Scrolls the viewer until the single "Edit SVG" button is built.
Future<void> _scrollToEdit(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(const Key('edit-svg')),
  300,
  scrollable: find.byType(Scrollable).first,
);

/// Taps an editor tab (icon-only tabs expose their label as tooltip).
Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.byTooltip(label, skipOffstage: false);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  testWidgets('home shows the demos with the theme and language buttons', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    expect(find.text('butterfly.svg'), findsOneWidget);
    expect(find.text('Importar SVG'), findsOneWidget);
    expect(_brightness(tester), Brightness.dark);

    expect(find.byTooltip('Mudar para o modo claro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light);
    expect(services.settings.value.darkMode, isFalse);
    expect(find.byTooltip('Mudar para o modo escuro'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Import SVG'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('View and edit your SVG animations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('filters favorites and adaptive SVGs', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    await tester.tap(find.byTooltip('Adicionar aos favoritos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('butterfly.svg'), findsOneWidget);
    expect(find.text('wave.svg'), findsNothing);

    final adaptiveChip = find.ancestor(
      of: find.text('Claro/Escuro', skipOffstage: false),
      matching: find.byType(ChoiceChip, skipOffstage: false),
    );
    await tester.ensureVisible(adaptiveChip);
    await tester.pumpAndSettle();
    await tester.tap(adaptiveChip);
    await tester.pumpAndSettle();
    expect(services.library.visible.map((d) => d.name), ['butterfly.svg', 'sun-moon.svg']);
  });

  testWidgets('adaptive cards show only the contrast icon, without the label', (tester) async {
    await pumpApp(tester, await _services(tester));

    expect(find.byIcon(Icons.contrast_rounded), findsNWidgets(2));
    expect(find.byTooltip('Claro/Escuro'), findsNWidgets(2), reason: 'kept as tooltip');
    expect(
      find.text('Claro/Escuro', skipOffstage: false),
      findsOneWidget,
      reason: 'the text remains only on the filter chip',
    );
  });

  testWidgets('imports files and reports invalid ones', (tester) async {
    final services = await _services(
      tester,
      files: [(name: 'new.svg', content: _valid), (name: 'bad.svg', content: '<svg>')],
    );
    await pumpApp(tester, services);

    await tester.tap(find.text('Importar SVG'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 arquivo importado'), findsOneWidget);
    expect(find.textContaining('bad.svg'), findsOneWidget);
    expect(services.library.documents.first.name, 'new.svg');
  });

  testWidgets('viewer offers light/dark variants only for adaptive SVGs', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    await tester.tap(find.text('butterfly.svg'));
    await tester.pumpAndSettle();
    expect(find.text('Versão clara e escura'), findsOneWidget);
    // Light, dark and side by side are icons only; the name is the tooltip.
    expect(find.text('Lado a lado'), findsNothing);
    expect(find.text('Clara'), findsNothing);
    await tester.tap(find.byTooltip('Lado a lado'));
    await tester.pumpAndSettle();
    expect(find.text('Clara'), findsWidgets);
    expect(find.text('Escura'), findsWidgets);

    await tester.tap(find.byTooltip('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('wave.svg'), findsWidgets);
    expect(find.text('Versão clara e escura'), findsNothing);

    await _scrollToEdit(tester);
    expect(find.text('Editar SVG'), findsOneWidget, reason: 'a single edit button');
  });

  testWidgets('editor crops the window and has a separate text tab', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Texto');
    expect(find.text('Inserir texto'), findsOneWidget);
    expect(find.text('Retângulo'), findsNothing);
    await _tapTab(tester, 'Inserir');
    expect(find.text('Retângulo'), findsOneWidget);

    await _tapTab(tester, 'Janela');
    expect(find.byKey(const Key('ratio-1:1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ratio-1:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ratio-9:16')));
    await tester.pumpAndSettle();
    final restore = tester.widget<IconButton>(find.byKey(const Key('window-restore')));
    expect(restore.onPressed, isNotNull, reason: 'the window was cropped');
    await tester.tap(find.byKey(const Key('window-restore')));
    await tester.pumpAndSettle();
  });

  testWidgets('wrapping lines in the code tab is not an unapplied edit', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');

    String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
    String text() => tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    final before = squash(text());
    await tester.tap(find.text('Quebrar linhas'));
    await tester.pumpAndSettle();
    expect(squash(text()), before, reason: 'only whitespace changes');
    expect(tester.widget<FilledButton>(find.byKey(const Key('apply-code'))).onPressed, isNull);
    await tester.tap(find.text('Quebrar linhas'));
    await tester.pumpAndSettle();
    expect(squash(text()), before);
  });

  testWidgets('editor inserts a shape, undoes, validates code and saves', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    final wave = services.library.documents.firstWhere((d) => d.name == 'wave.svg');

    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save().onPressed, isNull);

    await _tapTab(tester, 'Inserir');
    expect(find.byKey(const Key('insert-shape')), findsNothing, reason: 'no Add button');
    // Tapping a shape adds it right away.
    await tester.ensureVisible(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);
    expect(find.textContaining('Selecionado: Retângulo'), findsOneWidget);
    expect(find.text('Contorno'), findsWidgets);
    expect(find.text('Preenchimento'), findsNothing, reason: 'hollow: no fill color yet');

    // New shapes are hollow; the box fills them.
    CheckboxListTile filled() =>
        tester.widget<CheckboxListTile>(find.byKey(const Key('selected-filled')));
    await tester.ensureVisible(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    expect(filled().value, isFalse);
    await tester.tap(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    expect(filled().value, isTrue);
    expect(find.text('Preenchimento'), findsOneWidget, reason: 'filled: pick the fill color too');
    // The fill colors pushed the box down.
    await tester.ensureVisible(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    expect(filled().value, isFalse);
    // Back to the state right after inserting (two undoable steps).
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('delete-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-shape')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecionado: Retângulo'), findsNothing);
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecionado: Retângulo'), findsOneWidget);

    await tester.drag(find.byKey(const Key('resize-handle')), const Offset(30, 30));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Camadas');
    expect(
      find.text('Ajuste do editor'),
      findsNothing,
      reason: 'resizing changes the shape itself, with no transform group',
    );
    expect(save().onPressed, isNotNull);
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Inserir');

    await tester.drag(find.byKey(const Key('rotate-handle')), const Offset(-40, 30));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Camadas');
    expect(find.text('Ajuste do editor'), findsWidgets, reason: 'turning adds a transform group');
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Inserir');

    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNull);
    await tester.tap(find.byTooltip('Refazer'));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Camadas');
    await tester.ensureVisible(find.textContaining('Retângulo').last);
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('Retângulo').last);
    await tester.pumpAndSettle();
    expect(find.text('Excluir camada?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecionado: Retângulo'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Retângulo').last);
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('Retângulo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecionado: Retângulo'), findsNothing);
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Código');
    expect(
      tester.widget<TextField>(find.byKey(const Key('code-field'))).style?.fontSize,
      11,
      reason: 'the code editor starts at font size 11',
    );
    await tester.enterText(find.byKey(const Key('code-field')), '<svg><g></svg>');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // the editor hears about the error, then Save rebuilds
    expect(find.text('SVG inválido'), findsNothing, reason: 'never the banner below the code');
    // The error is told once, under the code, without the parser's English text.
    expect(find.byKey(const Key('code-error')), findsOneWidget);
    expect(find.textContaining('expected'), findsNothing);
    expect(find.textContaining('XML malformado'), findsOneWidget);
    // Apply becomes the way to the error, and Save explains itself when tapped.
    expect(
      find.descendant(of: find.byKey(const Key('apply-code')), matching: find.text('Ver erro')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();
    expect(find.textContaining('Não dá para salvar'), findsOneWidget);
    expect(services.library.contentOf(services.library.byId(wave.id)!), isNot(contains('<g>')));

    await tester.enterText(find.byKey(const Key('code-field')), _valid);
    await tester.pump();
    // Right after typing the old error no longer counts: Apply applies again.
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-error')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('apply-code')), matching: find.text('Aplicado')),
      findsOneWidget,
      reason: 'a clean apply shows in the button, not in a message over the tabs',
    );
    expect(find.text('Código aplicado'), findsNothing);
    expect(find.text('SVG válido'), findsNothing, reason: 'shown only after saving');

    // Nonsense inside <style> is still XML: a warning, and saving stays possible.
    await tester.enterText(
      find.byKey(const Key('code-field')),
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
      '<style>.a { fill red; }</style><rect width="10" height="10"/></svg>',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-hint')), findsOneWidget);
    expect(
      find.text('SVG válido, com um aviso'),
      findsNothing,
      reason: 'told once, under the code',
    );
    expect(save().onPressed, isNotNull);

    await tester.enterText(find.byKey(const Key('code-field')), _valid);
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-hint')), findsNothing);

    await tester.tap(find.byKey(const Key('save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Alterações salvas'), findsOneWidget);
    expect(find.text('SVG válido'), findsOneWidget);
    expect(services.library.contentOf(services.library.byId(wave.id)!), formatSvg(_valid));
  });

  testWidgets('insert: a color picked in the row repaints the selected shape', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Inserir');
    await tester.ensureVisible(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();

    // The second swatch is purple (#A04BFF); the shape is hollow, so its
    // outline changes.
    final swatch = find.descendant(
      of: find.byKey(const Key('insert-colors')),
      matching: find.byType(ColorDot),
    );
    await tester.ensureVisible(swatch.at(1));
    await tester.pumpAndSettle();
    await tester.tap(swatch.at(1));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Código');
    final code = tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    expect(code, contains('stroke="#A04BFF"'));
    expect(code, contains('fill="none"'), reason: 'still hollow');
  });

  testWidgets('layers: arrow folds a folder, double tap renames, header folds all', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    expect(find.text('Selecionado: Todas'), findsOneWidget);

    // Same-named siblings are numbered, nested like the tree.
    expect(find.textContaining(RegExp(r'^Grupo \d')), findsWidgets);

    // The arrow on a folder hides what is inside, and opens it again.
    final circles = find.textContaining('Círculo');
    final before = circles.evaluate().length;
    expect(before, greaterThan(0));
    final fold = find.byTooltip('Dobrar pasta').first;
    await tester.ensureVisible(fold);
    await tester.pumpAndSettle();
    await tester.tap(fold);
    await tester.pumpAndSettle();
    expect(circles.evaluate().length, lessThan(before), reason: 'the folder hides its layers');
    await tester.tap(find.byTooltip('Abrir pasta').first);
    await tester.pumpAndSettle();
    expect(circles.evaluate().length, before, reason: 'the arrow opens it again');

    // Two taps on a layer ask for a new name.
    final rect = find.text('Retângulo').first;
    await tester.ensureVisible(rect);
    await tester.pumpAndSettle();
    await tester.tap(rect);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rect);
    await tester.pumpAndSettle();
    expect(find.text('Renomear camada'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Fundo da lua');
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    expect(find.text('Fundo da lua'), findsWidgets);
    expect(find.text('Selecionado: Fundo da lua'), findsOneWidget);

    // Two taps on the "N camadas" header fold every folder, and again open them.
    final header = find.textContaining(RegExp(r'^\d+ camadas$'));
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    Future<void> twoTaps() async {
      await tester.tap(header);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(header);
      await tester.pumpAndSettle();
    }

    final shown = circles.evaluate().length;
    await twoTaps();
    expect(find.byTooltip('Dobrar pasta'), findsNothing, reason: 'every folder is folded');
    expect(circles.evaluate().length, lessThan(shown));
    await twoTaps();
    expect(find.byTooltip('Abrir pasta'), findsNothing, reason: 'every folder is open');
    expect(circles.evaluate().length, shown);
  });

  testWidgets('layers: the corner box ticks several layers, even from different folders', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    final box = find.byKey(const Key('multi-select'));
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(box).value, isFalse);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(box).value, isTrue);
    expect(find.text('Toque nas camadas para selecioná-las'), findsOneWidget);

    // Tapping a layer ticks it; tapping another one keeps the first ticked.
    for (final name in ['Retângulo', 'Círculo']) {
      final row = find.textContaining(name).first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
    expect(find.text('2 camadas selecionadas'), findsWidgets);

    // Unticking the corner box goes back to a single selection.
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(find.text('2 camadas selecionadas'), findsNothing);
  });

  testWidgets('transform: width and height can be changed on their own', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Transformar');
    // The pair for the selection (%) sits right after Escala.
    expect(find.text('Largura'), findsOneWidget);
    expect(find.text('Altura'), findsOneWidget);
    expect(find.text('Escala'), findsOneWidget);
    expect(find.text('Tamanho do documento'), findsNothing, reason: 'it has its own tab');

    FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save().onPressed, isNull);
    await tester.drag(find.byType(Slider).at(3), const Offset(60, 0)); // Largura (%)
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull, reason: 'stretching the width is an edit');

    // The card is just "Transformar", and the document size has no tab.
    expect(find.text('Transformar'), findsWidgets);
    expect(find.byTooltip('Tamanho'), findsNothing);
  });

  testWidgets('code: the magnifier opens a search that finds and steps through matches', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');

    expect(find.byKey(const Key('code-search-field')), findsNothing);
    await tester.tap(find.byKey(const Key('code-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-search-field')), findsOneWidget);

    // Letter case does not matter, and every match is counted.
    await tester.enterText(find.byKey(const Key('code-search-field')), 'CIRCLE');
    await tester.pumpAndSettle();
    final code = tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    final total = RegExp('circle').allMatches(code).length;
    expect(total, greaterThan(1));
    final count = find.byKey(const Key('code-search-count'));
    expect(tester.widget<Text>(count).data, '1/$total');

    await tester.tap(find.byKey(const Key('code-search-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '2/$total');
    await tester.tap(find.byKey(const Key('code-search-previous')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '1/$total');
    await tester.tap(find.byKey(const Key('code-search-previous')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '$total/$total', reason: 'goes around');

    await tester.enterText(find.byKey(const Key('code-search-field')), 'zzzz-not-there');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '0');

    await tester.tap(find.byKey(const Key('code-search-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-search-field')), findsNothing);
  });

  testWidgets('code: a broken SVG shows a red message, a wrong value an amber hint', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');

    final field = find.byKey(const Key('code-field'));
    const open = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">';
    Future<void> type(String text) async {
      await tester.enterText(field, text);
      // The check waits for typing to pause.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.byKey(const Key('code-error')), findsNothing);
    expect(find.byKey(const Key('code-hint')), findsNothing);

    // Valid XML with a color that is not one: a hint, not an error.
    await type('$open\n<circle r="4" fill="#FFC----@83D"/>\n</svg>');
    expect(find.byKey(const Key('code-hint')), findsOneWidget);
    expect(find.byKey(const Key('code-error')), findsNothing);
    expect(find.textContaining('Valor inválido'), findsOneWidget);
    expect(find.textContaining('#FFC----@83D'), findsWidgets);
    expect(find.textContaining('linha 2'), findsOneWidget);

    // Broken XML: a red error that names the line.
    await type('$open\n<rect width="1" height=">\n</svg>');
    expect(find.byKey(const Key('code-error')), findsOneWidget);
    expect(find.byKey(const Key('code-hint')), findsNothing);
    expect(find.textContaining('XML malformado'), findsOneWidget);

    // The button jumps to the problem without breaking anything.
    await tester.tap(find.byKey(const Key('code-problem-go')));
    await tester.pumpAndSettle();

    // Fixed: both go away.
    await type('$open\n<circle r="4" fill="#FFC83D"/>\n</svg>');
    expect(find.byKey(const Key('code-error')), findsNothing);
    expect(find.byKey(const Key('code-hint')), findsNothing);
  });

  /// Opens wave.svg in the editor on the Code tab.
  Future<AppServices> openCodeTab(WidgetTester tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');
    return services;
  }

  const rectOnly =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="5" height="5"/></svg>';

  /// Types [text] in the code field and lets the editor hear about it.
  Future<void> typeCode(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('code-field')), text);
    await tester.pump(const Duration(milliseconds: 700)); // the check runs
    await tester.pump(); // the editor hears, Save rebuilds
  }

  testWidgets('code: typed text waits with a dot and is applied when leaving the tab', (
    tester,
  ) async {
    await openCodeTab(tester);
    expect(find.byKey(const Key('code-pending-dot')), findsNothing);

    await typeCode(tester, rectOnly);
    // Valid, but not applied by itself: the dot stays, however long it waits.
    expect(find.byKey(const Key('code-pending-dot')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('code-pending-dot')), findsOneWidget);
    expect(find.text('Aplicado'), findsNothing);

    // Leaving the tab applies it.
    await _tapTab(tester, 'Camadas');
    expect(find.text('Retângulo'), findsWidgets, reason: 'the typed rectangle is a layer now');
    await _tapTab(tester, 'Código');
    expect(find.byKey(const Key('code-pending-dot')), findsNothing);
  });

  testWidgets('code: Save applies valid typed code and saves it', (tester) async {
    final services = await openCodeTab(tester);
    final wave = services.library.documents.firstWhere((d) => d.name == 'wave.svg');

    await typeCode(tester, rectOnly);
    FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save().onPressed, isNotNull, reason: 'typed code that works can be saved');
    await tester.tap(find.byKey(const Key('save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Alterações salvas'), findsOneWidget);
    expect(services.library.contentOf(services.library.byId(wave.id)!), contains('<rect'));
  });

  testWidgets('code: an error hides "SVG válido", is never applied, and Save explains', (
    tester,
  ) async {
    final services = await openCodeTab(tester);
    final wave = services.library.documents.firstWhere((d) => d.name == 'wave.svg');

    await typeCode(tester, rectOnly);
    await tester.tap(find.byKey(const Key('save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('SVG válido'), findsOneWidget, reason: 'shown after a save');

    await typeCode(tester, '<svg><g></svg>');
    expect(find.byKey(const Key('code-error')), findsOneWidget);
    expect(find.text('SVG válido'), findsNothing, reason: 'not while there is an error');

    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Não dá para salvar'), findsOneWidget);
    expect(
      services.library.contentOf(services.library.byId(wave.id)!),
      isNot(contains('<g>')),
      reason: 'broken code is never written',
    );
  });

  testWidgets('code: leaving the editor with typed code that was not applied asks first', (
    tester,
  ) async {
    await openCodeTab(tester);
    await typeCode(tester, rectOnly);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Alterações não salvas'), findsOneWidget);
  });

  testWidgets('text: width and height bars stretch the text, without an outline bar', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Texto');

    // Before the text is added, the bars set how the next one is born.
    expect(find.byKey(const Key('new-width')), findsOneWidget);
    expect(find.byKey(const Key('new-height')), findsOneWidget);
    expect(find.text('Contorno'), findsNothing, reason: 'text has no outline');

    await tester.ensureVisible(find.byKey(const Key('insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-shape')));
    await tester.pumpAndSettle();

    final width = find.byKey(const Key('selected-width'));
    final height = find.byKey(const Key('selected-height'));
    await tester.ensureVisible(width);
    await tester.pumpAndSettle();
    expect(find.descendant(of: width, matching: find.text('Largura')), findsOneWidget);
    expect(find.descendant(of: height, matching: find.text('Altura')), findsOneWidget);
    expect(find.text('Contorno'), findsNothing);

    // Each bar stretches on its own axis.
    await tester.drag(
      find.descendant(of: width, matching: find.byType(Slider)),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(height);
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(of: height, matching: find.byType(Slider)),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');
    final code = tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    final scale = RegExp(r'scale\(([-\d.]+) ([-\d.]+)\)').firstMatch(code);
    expect(scale, isNotNull, reason: 'width and height give the text two different scales');
    expect(double.parse(scale!.group(1)!), greaterThan(double.parse(scale.group(2)!)));
  });

  testWidgets('insert: width and height stretch the selected shape', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Inserir');
    await tester.ensureVisible(find.byKey(const Key('insert-circle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-circle')));
    await tester.pumpAndSettle();

    final width = find.byKey(const Key('selected-width'));
    final height = find.byKey(const Key('selected-height'));
    await tester.ensureVisible(width);
    await tester.pumpAndSettle();
    expect(find.descendant(of: width, matching: find.text('Largura')), findsOneWidget);
    expect(find.descendant(of: height, matching: find.text('Altura')), findsOneWidget);

    await tester.drag(
      find.descendant(of: width, matching: find.byType(Slider)),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Código');
    final code = tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    // The shape itself got wider (no scaling wrapper), so its outline keeps its width.
    expect(code, contains('data-sm-w='));
    expect(code, isNot(contains('data-sm-edit="element"')));
  });

  testWidgets('animation: only the duration is shown, and it follows the speed bar', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Animação');

    expect(find.textContaining('Sim ('), findsNothing, reason: 'no CSS / SMIL jargon');
    final duration = find.textContaining('Duração:');
    expect(duration, findsOneWidget);
    double seconds() => double.parse(
      tester.widget<Text>(duration).data!.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.'),
    );
    final before = seconds();

    // Faster: the cycle gets shorter while the bar is still moving.
    final bar = find.byType(Slider).first;
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(seconds(), lessThan(before));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(seconds(), lessThan(before), reason: 'and it stays after the speed is applied');
  });

  testWidgets('animation: with nothing selected a motion applies to all and the chip follows', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Animação');

    bool chosen(String label) => tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label, skipOffstage: false))
        .selected;
    Future<void> tap(String label) async {
      final chip = find.widgetWithText(ChoiceChip, label, skipOffstage: false);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await tap('Girar');
    expect(chosen('Girar'), isTrue);
    await tap('Pulsar');
    expect(chosen('Pulsar'), isTrue);
    expect(chosen('Girar'), isFalse);
    await tap('Nenhum');
    expect(chosen('Nenhum'), isTrue);
  });

  testWidgets('animation: a motion applies as soon as it is tapped and "None" removes it', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    // A layer that has no motion yet.
    await tester.tap(find.text('Retângulo').first);
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Animação');
    await tester.ensureVisible(find.byKey(const Key('preset-none')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('apply-preset')), findsNothing, reason: 'no apply button');
    ChoiceChip none() => tester.widget<ChoiceChip>(find.byKey(const Key('preset-none')));
    expect(none().selected, isTrue);

    await tester.tap(find.text('Girar'));
    await tester.pumpAndSettle();
    expect(none().selected, isFalse, reason: 'the layer now has a motion');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Girar')).selected, isTrue);

    await tester.ensureVisible(find.byKey(const Key('preset-none')));
    await tester.tap(find.byKey(const Key('preset-none')));
    await tester.pumpAndSettle();
    expect(none().selected, isTrue, reason: '"None" took the motion off');
  });

  testWidgets('animation: the intensity bar changes how strong the chosen motion is', (
    tester,
  ) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('sun-moon.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retângulo').first);
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Animação');

    final bar = find.byKey(const Key('preset-intensity'));
    Slider slider() =>
        tester.widget<Slider>(find.descendant(of: bar, matching: find.byType(Slider)));
    await tester.ensureVisible(bar);
    await tester.pumpAndSettle();
    expect(find.text('Intensidade'), findsOneWidget);
    expect(slider().onChanged, isNull, reason: 'no motion chosen yet');

    // A spin is a full turn whatever the strength: nothing to adjust.
    await tester.tap(find.text('Girar'));
    await tester.pumpAndSettle();
    expect(slider().onChanged, isNull);

    await tester.ensureVisible(find.text('Pulsar'));
    await tester.tap(find.text('Pulsar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(bar);
    await tester.pumpAndSettle();
    expect(slider().onChanged, isNotNull);
    expect(slider().value, 100, reason: 'starts at the original strength');

    await tester.drag(find.descendant(of: bar, matching: find.byType(Slider)), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(slider().value, greaterThan(100));

    await _tapTab(tester, 'Código');
    final code = tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text;
    expect(code, contains('--sm-i:'));
    expect(code, isNot(contains('--sm-i:1;')), reason: 'the new strength was written');
  });

  testWidgets('editor: the preview background can be switched', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);
    await tester.tap(find.text('wave.svg'));
    await tester.pumpAndSettle();
    await _scrollToEdit(tester);
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    StageBackground shown() => tester.widget<Stage>(find.byType(Stage).first).background;
    expect(shown(), StageBackground.current);

    for (final (key, expected) in [
      ('preview-bg-light', StageBackground.light),
      ('preview-bg-dark', StageBackground.dark),
      ('preview-bg-checkerboard', StageBackground.checkerboard),
      ('preview-bg-current', StageBackground.current),
    ]) {
      await tester.tap(find.byKey(const Key('preview-bg')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(shown(), expected, reason: key);
    }
  });

  testWidgets('pause-all stops the gallery for now without touching the settings', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    expect(find.byTooltip('Pausar animações'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pause-all')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retomar animações'), findsOneWidget);
    expect(services.settings.value.autoplay, isTrue, reason: 'the setting stays as it was');

    await tester.tap(find.byKey(const Key('pause-all')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pausar animações'), findsOneWidget);
  });

  testWidgets('settings change playback and appearance', (tester) async {
    final services = await _services(tester);
    await pumpApp(tester, services);

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir animação'));
    await tester.pumpAndSettle();
    expect(services.settings.value.loop, isFalse);

    // Repeating needs autoplay: switching it off turns repeat off and locks it.
    await tester.tap(find.text('Repetir animação'));
    await tester.pumpAndSettle();
    expect(services.settings.value.loop, isTrue);
    await tester.tap(find.text('Reprodução automática'));
    await tester.pumpAndSettle();
    expect(services.settings.value.loop, isFalse);
    await tester.tap(find.text('Repetir animação'));
    await tester.pumpAndSettle();
    expect(services.settings.value.loop, isFalse, reason: 'disabled while autoplay is off');
    await tester.tap(find.text('Reprodução automática'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Rosa'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Aparência'))).colorScheme.primary,
      const Color(0xFFFF4D8D),
    );
  });
}
