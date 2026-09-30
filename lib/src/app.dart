import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'features/gallery/gallery_screen.dart';
import 'l10n/l10n.dart';

/// Root widget: themes, language and the gallery as home screen.
class SvgMotionGalleryApp extends StatelessWidget {
  const SvgMotionGalleryApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final settings = services.settings.value;
          final accent = settings.accent.color;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => context.l10n.appTitle,
            theme: buildAppTheme(brightness: Brightness.light, accent: accent),
            darkTheme: buildAppTheme(brightness: Brightness.dark, accent: accent),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: settings.language.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            scrollBehavior: const AppScrollBehavior(),
            home: const GalleryScreen(),
          );
        },
      ),
    );
  }
}
