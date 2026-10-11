import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/layers/theme_badge.dart';

import 'helpers.dart';

/// Dark by default; light has its own background color and shows the sun.
const _themed =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<style>.bg{fill:#000011}.sun{display:none}'
    '@media (prefers-color-scheme: light){.bg{fill:#EEEEFF}.sun{display:inline}}</style>'
    '<rect class="bg" width="10" height="10"/>'
    '<g class="sun"><circle r="2" fill="#FFCC00"/></g>'
    '<circle id="dot" r="1" fill="#FF0000"/></svg>';

const _rect = ElementPath([1]);
const _sun = ElementPath([2]);
const _sunCircle = ElementPath([2, 0]);
const _dot = ElementPath([3]);

/// Imports `themed.svg` and opens it in the editor (the test app is dark).
Future<AppServices> _openInEditor(WidgetTester tester, {String svg = _themed}) async {
  final services = (await tester.runAsync(
    () => createTestServices(importFiles: [(name: 'themed.svg', content: svg)]),
  ))!;
  await pumpApp(tester, services);
  await tester.tap(find.text('Importar SVG'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 6)); // let the snack bar go
  await tester.pumpAndSettle();
  await tester.tap(find.text('themed.svg'));
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

Future<String> _save(WidgetTester tester, AppServices services) async {
  await tester.tap(find.byKey(const Key('save')));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  expect(find.text('Alterações salvas'), findsOneWidget);
  final doc = services.library.documents.firstWhere((d) => d.name == 'themed.svg');
  return services.library.contentOf(doc);
}

Finder _mark(ElementPath path) => find.byKey(ValueKey('theme-mark-$path'));

/// The color of the sun or moon icon of the marks of [path].
Color? _iconColor(WidgetTester tester, ElementPath path, IconData icon) =>
    tester.widget<Icon>(find.descendant(of: _mark(path), matching: find.byIcon(icon))).color;

void main() {
  testWidgets('layers show a sun for own light settings, "herda" for inherited ones', (
    tester,
  ) async {
    await _openInEditor(tester);
    expect(_mark(_rect), findsOneWidget);
    expect(_mark(_sun), findsOneWidget);
    expect(_mark(_sunCircle), findsOneWidget);
    expect(_mark(_dot), findsNothing, reason: 'the same in both themes');
    // Only the circle in the group takes everything from the group.
    expect(find.descendant(of: _mark(_sunCircle), matching: find.text('herda')), findsOneWidget);
    expect(find.text('herda'), findsOneWidget);
    // Own: solid sun; inherited: outlined sun.
    expect(
      find.descendant(of: _mark(_rect), matching: find.byIcon(Icons.light_mode_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _mark(_sunCircle), matching: find.byIcon(Icons.light_mode_outlined)),
      findsOneWidget,
    );
    expect(find.byTooltip('Ajuste próprio no tema claro'), findsOneWidget);
    expect(
      find.byTooltip('Ajuste próprio no tema claro\nNão aparece no tema escuro'),
      findsOneWidget,
      reason: 'the sun group is not drawn in the dark version being edited',
    );
  });

  testWidgets('switching the theme colors the marks of the version being edited', (tester) async {
    await _openInEditor(tester);
    final colors = GalleryColors.of(tester.element(_mark(_rect)));
    expect(_iconColor(tester, _rect, Icons.light_mode_rounded), isNot(colors.sun));

    await tester.tap(find.byKey(const Key('theme-variant')));
    await tester.pumpAndSettle();
    expect(_iconColor(tester, _rect, Icons.light_mode_rounded), colors.sun);
    expect(
      find.byTooltip('Ajuste próprio no tema claro\nNão aparece no tema escuro'),
      findsNothing,
    );
  });

  testWidgets('the theme button names the version, and the stage says it quietly', (tester) async {
    await _openInEditor(tester);
    final button = find.byKey(const Key('theme-variant'));
    expect(find.descendant(of: button, matching: find.text('Escuro')), findsOneWidget);
    expect(find.descendant(of: button, matching: find.byIcon(Icons.swap_horiz_rounded)), findsOne);
    final tag = find.byKey(const Key('stage-theme'));
    expect(find.descendant(of: tag, matching: find.text('Escuro')), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.descendant(of: button, matching: find.text('Claro')), findsOneWidget);
    expect(find.descendant(of: tag, matching: find.text('Claro')), findsOneWidget);
  });

  testWidgets('the layer actions stay on one line and slide sideways', (tester) async {
    await _openInEditor(tester);
    final keys = [
      'select-all-layers',
      'clear-selection',
      'layer-forward',
      'layer-backward',
      'layer-duplicate',
      'layer-visibility',
      'layer-delete',
    ];
    final tops = {for (final key in keys) tester.getTopLeft(find.byKey(Key(key))).dy};
    expect(tops, hasLength(1), reason: 'no second line');
    final row = find.byKey(const Key('layer-actions-row'));
    final delete = find.byKey(const Key('layer-delete'));
    final before = tester.getTopLeft(delete).dx;
    await tester.drag(row, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(delete).dx, lessThan(before), reason: 'slid in from the side');
    expect(
      tester.getTopLeft(find.byKey(const Key('theme-variant'))).dx,
      lessThan(tester.getTopLeft(row).dx),
      reason: 'the theme button stays in front',
    );
  });

  testWidgets('theme settings: visibility changes the edited version only', (tester) async {
    final services = await _openInEditor(tester);
    await tester.tap(_mark(_rect));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-sheet')), findsOneWidget);
    expect(find.text('Escuro · editando'), findsOneWidget);
    expect(find.textContaining('Você edita'), findsNothing, reason: 'the columns say it');
    for (final word in ['Próprio', 'Herdado', 'Comum']) {
      expect(find.text(word), findsNothing, reason: 'a mark, not a word: $word');
    }
    // The light fill of the rect is its own: a solid sun; dark shows the shared one.
    expect(find.byKey(const Key('theme-own-fill-light')), findsOneWidget);
    expect(find.byKey(const Key('theme-own-fill-dark')), findsNothing);
    expect(find.byTooltip('Próprio'), findsOneWidget);
    expect(find.byKey(const Key('theme-reset-fill')), findsNothing, reason: 'dark is shared');

    await tester.tap(find.byKey(const Key('theme-visible-switch')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('theme-sheet')))).pop();
    await tester.pumpAndSettle();

    final saved = await _save(tester, services);
    expect(SvgThemeEdit.isShown(saved, _rect, SvgColorScheme.dark), isFalse);
    expect(SvgThemeEdit.isShown(saved, _rect, SvgColorScheme.light), isTrue);
    expect(SvgThemeEdit.fillFor(saved, _rect, SvgColorScheme.light), '#EEEEFF');
  });

  testWidgets('theme settings: the title sits next to the layer name', (tester) async {
    await _openInEditor(tester);
    await tester.tap(_mark(_rect));
    await tester.pumpAndSettle();
    final name = tester.getRect(
      find.descendant(of: find.byKey(const Key('theme-sheet')), matching: find.text('Retângulo')),
    );
    final title = tester.getRect(find.text('Ajustes de tema'));
    expect((title.center.dy - name.center.dy).abs(), lessThan(4), reason: 'one line');
    expect(title.left, greaterThan(name.right));
  });

  testWidgets('theme settings: the other column switches, and its own value can be reset', (
    tester,
  ) async {
    final services = await _openInEditor(tester);
    await tester.tap(_mark(_rect));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-switch-light')));
    await tester.pumpAndSettle();
    expect(find.text('Claro · editando'), findsOneWidget);

    await tester.tap(find.byKey(const Key('theme-reset-fill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-reset-fill')), findsNothing, reason: 'shared again');
    Navigator.of(tester.element(find.byKey(const Key('theme-sheet')))).pop();
    await tester.pumpAndSettle();
    expect(_mark(_rect), findsNothing, reason: 'nothing of its own for either theme');

    final saved = await _save(tester, services);
    expect(SvgThemeEdit.fillFor(saved, _rect, SvgColorScheme.light), '#000011');
    expect(SvgThemeEdit.fillFor(saved, _rect, SvgColorScheme.dark), '#000011');
  });

  testWidgets('theme settings: an inherited setting says where it comes from', (tester) async {
    await _openInEditor(tester);
    await tester.ensureVisible(_mark(_sunCircle));
    await tester.pumpAndSettle();
    await tester.tap(_mark(_sunCircle));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('theme-inherited-display-light')),
      findsOneWidget,
      reason: 'drawn or not, from the group in light: an outlined sun',
    );
    await tester.tap(find.byKey(const Key('theme-switch-light')));
    await tester.pumpAndSettle();
    final from = find.byKey(const Key('theme-comes-from'));
    expect(from, findsOneWidget);
    await tester.ensureVisible(from);
    await tester.pumpAndSettle();
    await tester.tap(from);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-sheet')), findsNothing);
    expect(find.textContaining('Selecionado: Grupo'), findsOneWidget);
  });

  testWidgets('a layer without theme settings shows nothing for them, even selected', (
    tester,
  ) async {
    await _openInEditor(tester);
    await tester.tap(find.textContaining('#dot'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selecionado:'), findsOneWidget);
    expect(_mark(_dot), findsNothing);
    expect(find.byIcon(Icons.contrast_rounded), findsNothing);
  });

  testWidgets('a layer hidden in both themes has no theme marks', (tester) async {
    await _openInEditor(
      tester,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: light){.a{fill:#EEEEEE}}</style>'
          '<circle r="2" display="none"/></svg>',
    );
    expect(_mark(const ElementPath([1])), findsNothing);
    expect(find.text('herda'), findsNothing);
  });

  testWidgets('a folded folder shows the themes set inside it', (tester) async {
    await _openInEditor(
      tester,
      svg:
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: light){.a{fill:#EEEEEE}}</style>'
          '<g><circle class="a" r="2"/><circle r="1"/></g></svg>',
    );
    expect(find.byType(ThemeInsideMarks), findsNothing, reason: 'open: the row itself shows it');
    await tester.tap(find.byTooltip('Dobrar pasta').first);
    await tester.pumpAndSettle();
    expect(find.byType(ThemeInsideMarks), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('colors: the strip says which version changes and switches to the other', (
    tester,
  ) async {
    final services = await _openInEditor(tester);
    await tester.tap(find.textContaining('#dot'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final tab = find.byTooltip('Cores', skipOffstage: false);
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('colors-theme-strip')), findsOneWidget);
    expect(find.textContaining('Só o tema'), findsNothing, reason: 'the strip says it');
    expect(find.byTooltip('Escuro · editando'), findsOneWidget);
    expect(find.byTooltip('Mudar para o tema claro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('colors-theme-light')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Claro · editando'), findsOneWidget);
    final swatch = find.descendant(
      of: find.byKey(const Key('preset-palette')),
      matching: find.bySemanticsLabel('#3B82F6'),
    );
    await tester.ensureVisible(swatch);
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    final saved = await _save(tester, services);
    expect(SvgThemeEdit.fillFor(saved, _dot, SvgColorScheme.light), '#3B82F6');
    expect(SvgThemeEdit.fillFor(saved, _dot, SvgColorScheme.dark), '#FF0000');
  });

  group('EditorController theme', () {
    test('a file without versions has no theme, whatever was started', () {
      final editor = EditorController('<svg><rect fill="red"/></svg>')
        ..startTheme(SvgColorScheme.dark);
      expect(editor.themeScheme, isNull);
      expect(editor.themeMarks, isEmpty);
    });

    test('the first version is the one started with, and the toggle switches it', () {
      final editor = EditorController(_themed)
        ..startTheme(SvgColorScheme.dark)
        ..startTheme(SvgColorScheme.light);
      expect(editor.themeScheme, SvgColorScheme.dark, reason: 'set once');
      editor.toggleTheme();
      expect(editor.themeScheme, SvgColorScheme.light);
      expect(editor.themeMarks[_rect]!.originIn(SvgColorScheme.light), SvgThemeOrigin.own);
    });

    test('switching moves the selection to its twin in the other version', () {
      const doc =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>.sun{display:none}'
          '@media (prefers-color-scheme: light){.sun{display:inline}.night{display:none}}</style>'
          '<g class="night"><circle r="1"/></g><g class="sun"><circle r="2"/></g></svg>';
      final editor = EditorController(doc)
        ..startTheme(SvgColorScheme.dark)
        ..select(const ElementPath([1]));
      editor.toggleTheme();
      expect(editor.selection, const ElementPath([2]));
    });

    test('marks follow edits', () {
      final editor = EditorController(_themed)..startTheme(SvgColorScheme.dark);
      expect(editor.themeMarks[_dot]!.isEmpty, isTrue);
      editor.commit(SvgThemeEdit.setFill(editor.svg, _dot, '#00FF00', SvgColorScheme.dark));
      expect(editor.themeMarks[_dot]!.originIn(SvgColorScheme.dark), SvgThemeOrigin.own);
    });
  });
}
