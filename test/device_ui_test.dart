import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_motion_gallery/src/services/device_storage_memory.dart';

import 'helpers.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="4" height="4"/></svg>';
const _dir = '/storage/emulated/0/Download';

MemoryDeviceStorage _phone({bool granted = false}) => MemoryDeviceStorage(granted: granted)
  ..addFile('$_dir/alpha.svg', _svg, modified: DateTime(2024, 3))
  ..addFile('$_dir/beta.svg', _svg, modified: DateTime(2024, 2))
  ..addFile('$_dir/gamma.svg', _svg, modified: DateTime(2024, 1));

Future<AppServices> _services(WidgetTester tester, [MemoryDeviceStorage? phone]) async =>
    (await tester.runAsync(() => createTestServices(device: phone)))!;

Future<void> _showDeviceFilter(WidgetTester tester) async {
  final chip = find.ancestor(
    of: find.text('No celular', skipOffstage: false),
    matching: find.byType(ChoiceChip, skipOffstage: false),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// The user leaves for the system screen and comes back.
Future<void> _returnToApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for file access once, then lists the phone files after it is allowed', (
    tester,
  ) async {
    final phone = _phone();
    await pumpApp(tester, await _services(tester, phone));

    expect(find.text('Mostrar seus SVGs'), findsOneWidget);
    await tester.tap(find.byKey(const Key('device-allow')));
    await tester.pumpAndSettle();
    expect(phone.requestCount, 1);

    await _returnToApp(tester);
    expect(
      find.text('Mostrar os SVGs do celular'),
      findsNothing,
      reason: 'banner gone once allowed',
    );
    await _showDeviceFilter(tester);
    expect(find.text('alpha.svg'), findsOneWidget);
    expect(find.text('beta.svg'), findsOneWidget);
    expect(find.text('gamma.svg'), findsOneWidget);
    expect(find.byIcon(Icons.smartphone_rounded), findsWidgets);
  });

  testWidgets('"Not now" leaves a banner that can ask again or be dismissed', (tester) async {
    final phone = _phone();
    await pumpApp(tester, await _services(tester, phone));

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(phone.requestCount, 0);
    expect(find.text('Mostrar os SVGs do celular'), findsOneWidget);

    await tester.tap(find.byKey(const Key('banner-allow')));
    await tester.pumpAndSettle();
    expect(phone.requestCount, 1);

    await tester.tap(find.byTooltip('Agora não'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrar os SVGs do celular'), findsNothing);
  });

  testWidgets('the device filter explains that access is needed when it was refused', (
    tester,
  ) async {
    final phone = _phone();
    await pumpApp(tester, await _services(tester, phone));
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    await _showDeviceFilter(tester);
    expect(find.text('Nenhum SVG no celular'), findsOneWidget);
    expect(find.text('Permita o acesso aos arquivos para ver os SVGs do celular.'), findsOneWidget);
  });

  testWidgets('platforms without file access show nothing about the phone', (tester) async {
    await pumpApp(tester, await _services(tester));

    expect(find.text('Mostrar seus SVGs'), findsNothing);
    expect(find.text('Mostrar os SVGs do celular'), findsNothing);
    expect(find.text('No celular', skipOffstage: false), findsNothing);
  });

  testWidgets('long press selects several files and deletes them from the phone', (tester) async {
    final phone = _phone(granted: true);
    await pumpApp(tester, await _services(tester, phone));
    expect(find.text('Mostrar seus SVGs'), findsNothing);
    await _showDeviceFilter(tester);

    await tester.longPress(find.text('alpha.svg'));
    await tester.pumpAndSettle();
    expect(find.text('1 selecionado'), findsOneWidget);
    expect(find.byKey(const Key('delete-selected')), findsOneWidget);

    await tester.tap(find.text('beta.svg'));
    await tester.pumpAndSettle();
    expect(find.text('2 selecionados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir 2 arquivos?'), findsOneWidget);
    expect(find.textContaining('apagados definitivamente do celular'), findsOneWidget);
    expect(find.textContaining('Esta ação não pode ser desfeita.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(phone.paths, ['$_dir/gamma.svg']);
    expect(find.text('2 arquivos excluídos'), findsOneWidget);
    expect(find.text('alpha.svg'), findsNothing);
    expect(find.text('gamma.svg'), findsOneWidget);
    expect(find.textContaining('selecionado'), findsNothing);
  });

  testWidgets('cancelling the confirmation deletes nothing; back leaves selection mode', (
    tester,
  ) async {
    final phone = _phone(granted: true);
    await pumpApp(tester, await _services(tester, phone));
    await _showDeviceFilter(tester);

    await tester.longPress(find.text('alpha.svg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(phone.paths, hasLength(3));
    expect(find.text('1 selecionado'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('selecionado'), findsNothing);
    expect(find.text('Importar SVG'), findsOneWidget);
  });

  testWidgets('select all covers what the filter shows, including gallery files', (tester) async {
    final phone = _phone(granted: true);
    final services = await _services(tester, phone);
    await pumpApp(tester, services);

    await tester.longPress(find.text('butterfly.svg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Selecionar todos'));
    await tester.pumpAndSettle();
    expect(find.text('${services.library.visible.length} selecionados'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-selected')));
    await tester.pumpAndSettle();
    expect(find.textContaining('removidos da galeria'), findsOneWidget);
    expect(find.textContaining('apagados definitivamente do celular'), findsOneWidget);
  });

  testWidgets('a phone file card offers rename, share and delete — not duplicate', (tester) async {
    final phone = _phone(granted: true);
    await pumpApp(tester, await _services(tester, phone));
    await _showDeviceFilter(tester);

    await tester.tap(find.byTooltip('Mais ações').first);
    await tester.pumpAndSettle();
    expect(find.text('Renomear'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Duplicar'), findsNothing);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir do celular?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(phone.contains('$_dir/alpha.svg'), isFalse);
    expect(find.text('alpha.svg excluído'), findsOneWidget);
  });

  testWidgets('the viewer shows where a phone file lives and editing saves back to it', (
    tester,
  ) async {
    final phone = _phone(granted: true);
    await pumpApp(tester, await _services(tester, phone));
    await _showDeviceFilter(tester);

    await tester.tap(find.text('alpha.svg'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(_dir),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Local'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-svg')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('edit-svg')));
    await tester.pumpAndSettle();

    final insertTab = find.byTooltip('Inserir', skipOffstage: false);
    await tester.ensureVisible(insertTab);
    await tester.pumpAndSettle();
    await tester.tap(insertTab);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-rectangle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Alterações salvas'), findsOneWidget);
    expect(phone.contentAt('$_dir/alpha.svg'), contains('rx='), reason: 'the inserted rectangle');
  });
}
