import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/app_scope.dart';
import 'src/data/app_settings.dart';
import 'src/data/platform_storage.dart';
import 'src/data/svg_repository.dart';
import 'src/services/platform_device_storage.dart';
import 'src/services/svg_io_services.dart';
import 'src/state/library_controller.dart';
import 'src/state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(const SettingsStore());
  await settings.load();
  final library = LibraryController(
    SvgRepository(createPlatformStorage()),
    device: createPlatformDeviceStorage(),
  );
  unawaited(library.load());
  runApp(
    SvgMotionGalleryApp(
      services: AppServices(
        settings: settings,
        library: library,
        importer: const FilePickerSvgImporter(),
        sharer: const SharePlusSvgSharer(),
      ),
    ),
  );
}
