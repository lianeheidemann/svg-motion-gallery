import 'package:flutter/widgets.dart';

import 'services/svg_io_services.dart';
import 'state/library_controller.dart';
import 'state/settings_controller.dart';

/// Everything screens depend on, created once in `main` (or in a test).
class AppServices {
  const AppServices({
    required this.settings,
    required this.library,
    required this.importer,
    required this.sharer,
  });

  final SettingsController settings;
  final LibraryController library;
  final SvgImporter importer;
  final SvgSharer sharer;
}

/// Makes [AppServices] available to the widget tree (simple DI).
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
