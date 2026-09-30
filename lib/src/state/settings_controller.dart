import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';

import '../data/app_settings.dart';

/// Exposes [AppSettings] to the UI and persists every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, [this._value = const AppSettings()]);

  final SettingsStore _store;
  AppSettings _value;

  AppSettings get value => _value;

  Future<void> load() async {
    _value = await _store.load();
    notifyListeners();
  }

  void _update(AppSettings next) {
    _value = next;
    notifyListeners();
    unawaited(_store.save(next));
  }

  /// Home screen button: switches between the light and dark theme.
  void toggleTheme() => _update(_value.copyWith(darkMode: !_value.darkMode));

  /// Home screen button: switches the whole app between Portuguese and English.
  void toggleLanguage() => _update(
    _value.copyWith(
      language: _value.language == AppLanguage.portuguese
          ? AppLanguage.english
          : AppLanguage.portuguese,
    ),
  );

  void setAccent(AccentColor accent) => _update(_value.copyWith(accent: accent));
  void setAutoplay(bool enabled) => _update(_value.copyWith(autoplay: enabled));
  void setLoop(bool enabled) => _update(_value.copyWith(loop: enabled));
  void setHighQualityPreviews(bool enabled) =>
      _update(_value.copyWith(highQualityPreviews: enabled));
  void setAutoBackup(bool enabled) => _update(_value.copyWith(autoBackup: enabled));
  void setSlideshowSeconds(int seconds) => _update(_value.copyWith(slideshowSeconds: seconds));

  /// Interface size (1 = design size). Kept within the allowed range and to
  /// whole percents so the slider and the stored value always agree.
  void setUiScale(double scale) {
    final clamped = scale.clamp(AppSettings.minUiScale, AppSettings.maxUiScale);
    _update(_value.copyWith(uiScale: (clamped * 100).round() / 100));
  }
}
