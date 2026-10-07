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
    await tester.tap(find.text('Lado a lado'));
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
    await tester.ensureVisible(find.byKey(const Key('insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-shape')));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);
    expect(find.textContaining('Selecionado: Retângulo'), findsOneWidget);

    // New shapes are hollow; the box fills them.
    CheckboxListTile filled() =>
        tester.widget<CheckboxListTile>(find.byKey(const Key('selected-filled')));
    await tester.ensureVisible(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    expect(filled().value, isFalse);
    await tester.tap(find.byKey(const Key('selected-filled')));
    await tester.pumpAndSettle();
    expect(filled().value, isTrue);
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
    expect(find.text('Ajuste do editor'), findsWidgets, reason: 'resizing adds a transform group');
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
    expect(find.text('SVG inválido'), findsNothing, reason: 'validated only on Apply');
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('SVG inválido'), findsOneWidget);
    expect(save().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('code-field')), _valid);
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('SVG inválido'), findsNothing);
    expect(find.text('Código aplicado'), findsOneWidget, reason: 'a clean apply is confirmed');
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
    expect(find.text('SVG válido, com um aviso'), findsOneWidget);
    expect(save().onPressed, isNotNull);

    await tester.enterText(find.byKey(const Key('code-field')), _valid);
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('SVG válido, com um aviso'), findsNothing);

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
    await tester.ensureVisible(find.byKey(const Key('insert-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-shape')));
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

    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Tamanho');
    expect(find.text('Tamanho do documento'), findsOneWidget);
    expect(find.text('Largura'), findsOneWidget);
    expect(find.text('Altura'), findsOneWidget);
    await tester.drag(find.byType(Slider).first, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull, reason: 'changing the document width is an edit');
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

    await tester.tap(find.bySemanticsLabel('Rosa'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Aparência'))).colorScheme.primary,
      const Color(0xFFFF4D8D),
    );
  });
}
