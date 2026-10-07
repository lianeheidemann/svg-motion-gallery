import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNull);
    await tester.tap(find.byTooltip('Refazer'));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Código');
    expect(
      tester.widget<TextField>(find.byKey(const Key('code-field'))).style?.fontSize,
      11,
      reason: 'the code editor starts at font size 11',
    );
    await tester.enterText(find.byKey(const Key('code-field')), '<svg><g></svg>');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SVG inválido'), findsOneWidget);
    expect(save().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('code-field')), _valid);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SVG válido'), findsNothing, reason: 'shown only after saving');

    await tester.tap(find.byKey(const Key('save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Alterações salvas'), findsOneWidget);
    expect(find.text('SVG válido'), findsOneWidget);
    expect(services.library.contentOf(services.library.byId(wave.id)!), _valid);
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
