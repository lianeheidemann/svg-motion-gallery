// Web preview that pretends to be a phone, for checking the "SVGs on the
// phone" screens in a browser (permission dialog, banner, filter, selection,
// delete). Browsers cannot read a device's files, so a memory-backed
// `DeviceStorage` stands in for Android. This entry point is not shipped:
//
//   flutter build web -t tool/preview_device_main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:svg_motion_gallery/src/app.dart';
import 'package:svg_motion_gallery/src/app_scope.dart';
import 'package:svg_motion_gallery/src/data/app_settings.dart';
import 'package:svg_motion_gallery/src/data/svg_repository.dart';
import 'package:svg_motion_gallery/src/data/svg_storage.dart';
import 'package:svg_motion_gallery/src/services/device_storage_memory.dart';
import 'package:svg_motion_gallery/src/services/svg_io_services.dart';
import 'package:svg_motion_gallery/src/state/library_controller.dart';
import 'package:svg_motion_gallery/src/state/settings_controller.dart';

/// Starts without access, like a fresh install; "allowing" grants it and
/// triggers the rescan the real app does when it returns from the system screen.
class _PreviewPhone extends MemoryDeviceStorage {
  _PreviewPhone() : super(granted: false);

  void Function()? onGranted;

  @override
  Future<void> requestAccess() async {
    await super.requestAccess();
    onGranted?.call();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final phone = _PreviewPhone();
  const folders = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/WhatsApp/Media',
  ];
  var index = 0;
  for (final asset in demoAssets) {
    phone.addFile(
      '${folders[index % folders.length]}/phone-$asset',
      await rootBundle.loadString('assets/svgs/$asset'),
      modified: DateTime(2026, 9, 30).subtract(Duration(hours: index)),
    );
    index++;
  }

  final library = LibraryController(SvgRepository(MemorySvgStorage()), device: phone);
  phone.onGranted = library.refreshDevice;
  await library.load();

  runApp(
    SvgMotionGalleryApp(
      services: AppServices(
        settings: SettingsController(const SettingsStore()),
        library: library,
        importer: const FilePickerSvgImporter(),
        sharer: const SharePlusSvgSharer(),
      ),
    ),
  );
}
