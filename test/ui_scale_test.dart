import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_motion_gallery/src/data/app_settings.dart';
import 'package:svg_motion_gallery/src/features/gallery/svg_card.dart';
import 'package:svg_motion_gallery/src/services/device_storage_memory.dart';
import 'package:svg_motion_gallery/src/state/settings_controller.dart';

import 'helpers.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="4" height="4"/></svg>';

Future<AppServices> _services(
  WidgetTester tester, {
  double uiScale = AppSettings.defaultUiScale,
  MemoryDeviceStorage? phone,
}) async => (await tester.runAsync(
  () => createTestServices(
    settings: AppSettings(uiScale: uiScale),
    device: phone,
  ),
))!;

/// How many cards sit side by side in the first row of the gallery.
int _columns(WidgetTester tester) {
  final tops = <double>[
    for (final card in find.byType(SvgCard).evaluate())
      tester.getTopLeft(find.byWidget(card.widget)).dy,
  ];
  final firstRow = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((top) => (top - firstRow).abs() < 1).length;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Configurações'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('ui-scale')));
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsController.setUiScale', () {
    test('starts at 70% and keeps the value within the allowed range, in whole percents', () {
      final settings = SettingsController(const SettingsStore());
      expect(settings.value.uiScale, 0.7);

      settings.setUiScale(3);
      expect(settings.value.uiScale, AppSettings.maxUiScale);
      settings.setUiScale(0.1);
      expect(settings.value.uiScale, AppSettings.minUiScale);
      settings.setUiScale(0.7000000000000001);
      expect(settings.value.uiScale, 0.7);
      settings.setUiScale(0.835);
      expect(settings.value.uiScale, 0.84);
    });

    test('is persisted; a missing or out-of-range stored value falls back safely', () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = SettingsController(const SettingsStore());
      await fresh.load();
      expect(fresh.value.uiScale, 0.7, reason: 'existing installs move to the new default');

      fresh.setUiScale(0.85);
      await pumpEventQueue();
      final reloaded = SettingsController(const SettingsStore());
      await reloaded.load();
      expect(reloaded.value.uiScale, 0.85);

      SharedPreferences.setMockInitialValues({'settings.uiScale': 9.0});
      final tooBig = SettingsController(const SettingsStore());
      await tooBig.load();
      expect(tooBig.value.uiScale, AppSettings.maxUiScale);
    });
  });

  group('interface at 70%', () {
    testWidgets('fits three gallery columns where 100% fits two', (tester) async {
      await pumpApp(tester, await _services(tester));
      expect(_columns(tester), 3);

      await pumpApp(tester, await _services(tester, uiScale: 1));
      expect(_columns(tester), 2);
    });

    testWidgets('draws dialogs smaller and still answers taps', (tester) async {
      final services = await _services(tester);
      await pumpApp(tester, services);

      await tester.tap(find.byTooltip('Mais ações').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final laidOut = tester.renderObject<RenderBox>(dialog).size.width;
      expect(tester.getRect(dialog).width, closeTo(laidOut * 0.7, 0.5));
      final panel = find.descendant(of: dialog, matching: find.byType(Material)).first;
      final panelWidth = tester.renderObject<RenderBox>(panel).size.width;
      expect(tester.getRect(panel).width, closeTo(panelWidth * 0.7, 0.5));
      expect(tester.getRect(panel).right, lessThan(390));

      final before = services.library.documents.length;
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(services.library.documents.length, before - 1);
    });

    testWidgets('scrolls a long list with the finger', (tester) async {
      final phone = MemoryDeviceStorage(granted: true);
      for (var i = 0; i < 40; i++) {
        phone.addFile(
          '/storage/emulated/0/Download/file$i.svg',
          _svg,
          modified: DateTime(2024, 1, i + 1),
        );
      }
      await pumpApp(tester, await _services(tester, phone: phone));
      final chip = find.ancestor(
        of: find.text('No celular', skipOffstage: false),
        matching: find.byType(ChoiceChip, skipOffstage: false),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final first = find.byType(SvgCard).first;
      final top = tester.getTopLeft(first).dy;
      await tester.drag(find.byType(GridView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(SvgCard).first).dy, lessThan(top - 100));
    });
  });

  group('size slider in the settings', () {
    testWidgets('resizes only on release and keeps the settings screen open', (tester) async {
      final services = await _services(tester);
      await pumpApp(tester, services);
      await _openSettings(tester);

      final slider = find.descendant(
        of: find.byKey(const Key('ui-scale')),
        matching: find.byType(Slider),
      );
      final rect = tester.getRect(slider);
      final drag = await tester.startGesture(Offset(rect.right - 12, rect.center.dy));
      await drag.moveBy(const Offset(-40, 0));
      await tester.pump();
      await drag.moveBy(const Offset(-40, 0));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('ui-scale')), matching: find.byType(TextField)),
      );
      final shown = int.parse(field.controller!.text);
      expect(shown, inExclusiveRange(70, 120), reason: 'the number follows the thumb meanwhile');
      expect(services.settings.value.uiScale, 0.7, reason: 'still dragging: nothing rescaled yet');

      await drag.up();
      await tester.pumpAndSettle();
      expect(services.settings.value.uiScale, shown / 100);
      expect(find.text('Configurações'), findsOneWidget);
    });

    testWidgets('accepts a typed percentage', (tester) async {
      final services = await _services(tester);
      await pumpApp(tester, services);
      await _openSettings(tester);

      final field = find.descendant(
        of: find.byKey(const Key('ui-scale')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(services.settings.value.uiScale, 0.5);
    });

    testWidgets('"Restaurar padrão" goes back to 70% and is disabled there', (tester) async {
      final services = await _services(tester, uiScale: 1);
      await pumpApp(tester, services);
      await _openSettings(tester);

      TextButton reset() => tester.widget<TextButton>(find.byKey(const Key('ui-scale-reset')));
      expect(reset().onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('ui-scale-reset')));
      await tester.tap(find.byKey(const Key('ui-scale-reset')));
      await tester.pumpAndSettle();
      expect(services.settings.value.uiScale, 0.7);
      expect(reset().onPressed, isNull);
    });
  });
}
