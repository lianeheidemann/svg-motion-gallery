import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the whole app can be shown in.
enum AppLanguage {
  portuguese(Locale('pt')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  final Locale locale;
}

/// User preferences. Every field is used by at least one screen.
@immutable
class AppSettings {
  const AppSettings({
    this.darkMode = true,
    this.language = AppLanguage.portuguese,
    this.accent = AccentColor.blue,
    this.autoplay = true,
    this.loop = true,
    this.highQualityPreviews = true,
    this.autoBackup = true,
    this.slideshowSeconds = 5,
  });

  /// Toggled by the button on the home screen.
  final bool darkMode;

  /// Toggled by the PT/EN button on the home screen.
  final AppLanguage language;
  final AccentColor accent;

  /// Animations start playing by themselves (gallery and viewer).
  final bool autoplay;

  /// Animations restart when they end.
  final bool loop;

  /// Gallery thumbnails use the live renderer instead of still images.
  final bool highQualityPreviews;

  /// Keep a copy of the previous version when saving an edit.
  final bool autoBackup;

  /// Interval of the viewer's automatic slideshow.
  final int slideshowSeconds;

  AppSettings copyWith({
    bool? darkMode,
    AppLanguage? language,
    AccentColor? accent,
    bool? autoplay,
    bool? loop,
    bool? highQualityPreviews,
    bool? autoBackup,
    int? slideshowSeconds,
  }) => AppSettings(
    darkMode: darkMode ?? this.darkMode,
    language: language ?? this.language,
    accent: accent ?? this.accent,
    autoplay: autoplay ?? this.autoplay,
    loop: loop ?? this.loop,
    highQualityPreviews: highQualityPreviews ?? this.highQualityPreviews,
    autoBackup: autoBackup ?? this.autoBackup,
    slideshowSeconds: slideshowSeconds ?? this.slideshowSeconds,
  );
}

/// Reads and writes [AppSettings] with shared_preferences. Failures (e.g.
/// the plugin missing in tests) fall back to defaults silently.
class SettingsStore {
  const SettingsStore();

  static const _prefix = 'settings.';

  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaults = AppSettings();
      T pick<T>(String key, T fallback) {
        final value = prefs.get('$_prefix$key');
        return value is T ? value : fallback;
      }

      return AppSettings(
        darkMode: pick('darkMode', defaults.darkMode),
        language: AppLanguage.values.asNameMap()[pick('language', '')] ?? defaults.language,
        accent: AccentColor.values.asNameMap()[pick('accent', '')] ?? defaults.accent,
        autoplay: pick('autoplay', defaults.autoplay),
        loop: pick('loop', defaults.loop),
        highQualityPreviews: pick('highQualityPreviews', defaults.highQualityPreviews),
        autoBackup: pick('autoBackup', defaults.autoBackup),
        slideshowSeconds: pick('slideshowSeconds', defaults.slideshowSeconds),
      );
    } on MissingPluginException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool('${_prefix}darkMode', settings.darkMode),
        prefs.setString('${_prefix}language', settings.language.name),
        prefs.setString('${_prefix}accent', settings.accent.name),
        prefs.setBool('${_prefix}autoplay', settings.autoplay),
        prefs.setBool('${_prefix}loop', settings.loop),
        prefs.setBool('${_prefix}highQualityPreviews', settings.highQualityPreviews),
        prefs.setBool('${_prefix}autoBackup', settings.autoBackup),
        prefs.setInt('${_prefix}slideshowSeconds', settings.slideshowSeconds),
      ]);
    } on MissingPluginException {
      // Preferences are optional: the app keeps working in memory.
    }
  }
}
