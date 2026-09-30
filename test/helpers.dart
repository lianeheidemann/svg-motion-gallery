import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svg_motion_gallery/src/app.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_motion_gallery/src/data/app_settings.dart';
import 'package:svg_motion_gallery/src/data/svg_repository.dart';
import 'package:svg_motion_gallery/src/data/svg_storage.dart';
import 'package:svg_motion_gallery/src/services/device_storage.dart';
import 'package:svg_motion_gallery/src/services/svg_io_services.dart';
import 'package:svg_motion_gallery/src/state/library_controller.dart';
import 'package:svg_motion_gallery/src/state/settings_controller.dart';
import 'package:svg_view/svg_view.dart';

class FakeImporter implements SvgImporter {
  FakeImporter([this.files = const []]);

  List<ImportedSvg> files;

  @override
  Future<List<ImportedSvg>> pick() async => files;
}

class FakeSharer implements SvgSharer {
  final shared = <String>[];

  @override
  Future<void> share(String name, String content, {Rect? origin}) async => shared.add(name);
}

/// Services backed by memory storage, with the bundled demos loaded.
Future<AppServices> createTestServices({
  MemorySvgStorage? storage,
  DeviceStorage? device,
  List<ImportedSvg> importFiles = const [],
  AppSettings settings = const AppSettings(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final library = LibraryController(SvgRepository(storage ?? MemorySvgStorage()), device: device);
  await library.load();
  return AppServices(
    settings: SettingsController(const SettingsStore(), settings),
    library: library,
    importer: FakeImporter(importFiles),
    sharer: FakeSharer(),
  );
}

/// Pumps the whole app on a phone-sized screen.
Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SvgViewScope(forceStill: true, child: SvgMotionGalleryApp(services: services)),
  );
  await tester.pumpAndSettle();
}
