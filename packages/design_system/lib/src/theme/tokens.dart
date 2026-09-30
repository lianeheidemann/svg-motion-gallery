import 'package:flutter/material.dart';

/// Base colors of one theme, taken from the reference mockup (dark) and its
/// light counterpart.
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.text,
    required this.muted,
    required this.stage,
    required this.stageGrid,
  });

  static const dark = AppPalette(
    background: Color(0xFF070D1A),
    surface: Color(0xFF0E1628),
    surfaceHigh: Color(0xFF15203A),
    outline: Color(0xFF1F2A44),
    text: Color(0xFFE9EEF8),
    muted: Color(0xFF8C9AB5),
    stage: Color(0xFF050B16),
    stageGrid: Color(0xFF111B30),
  );

  static const light = AppPalette(
    background: Color(0xFFF3F6FC),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEAF0FA),
    outline: Color(0xFFD8E0EE),
    text: Color(0xFF0E1628),
    muted: Color(0xFF5B6883),
    stage: Color(0xFFF8FAFF),
    stageGrid: Color(0xFFE3E9F4),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color text;
  final Color muted;

  /// Backdrop behind SVG previews.
  final Color stage;
  final Color stageGrid;
}

/// Accent colors offered in Settings.
enum AccentColor {
  blue(Color(0xFF1E7BFF)),
  purple(Color(0xFFA04BFF)),
  pink(Color(0xFFFF4D8D)),
  cyan(Color(0xFF16B9D8)),
  orange(Color(0xFFFF8A1F));

  const AccentColor(this.color);

  final Color color;
}

/// Spacing and radius scale.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const radius = 16.0;
  static const radiusSmall = 12.0;
  static const pageGutter = 16.0;
}

/// Shared component dimensions. Keep interactive controls aligned across
/// gallery, viewer, editor, settings and dialogs.
abstract final class AppSizes {
  static const controlHeight = 48.0;
  static const compactControlHeight = 40.0;
  static const inputHeight = 48.0;
  static const iconButton = 44.0;
  static const tabHeight = 44.0;
  static const sliderFieldWidth = 76.0;
  static const sliderTrackHeight = 4.0;
  static const sliderThumbRadius = 9.0;
  static const dialogMaxWidth = 440.0;
  static const cardIcon = 20.0;
}

/// Typography scale used by the app UI. SVG source code keeps its own
/// adjustable monospace size in the code editor.
abstract final class AppTypeScale {
  static const caption = 12.0;
  static const bodySmall = 13.0;
  static const body = 14.0;
  static const label = 14.0;
  static const titleSmall = 15.0;
  static const title = 16.0;
  static const heading = 20.0;
  static const appBar = 20.0;
}
