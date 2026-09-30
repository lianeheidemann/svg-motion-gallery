import 'package:flutter/material.dart';

import 'gallery_colors.dart';
import 'tokens.dart';

/// Builds the Material 3 theme for [brightness] with the chosen [accent].
ThemeData buildAppTheme({required Brightness brightness, Color accent = const Color(0xFF1E7BFF)}) {
  final palette = AppPalette.of(brightness);
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: accent,
    onPrimary: Colors.white,
    surface: palette.surface,
    onSurface: palette.text,
    onSurfaceVariant: palette.muted,
    surfaceContainerLowest: palette.background,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.surfaceHigh,
    surfaceContainerHighest: palette.surfaceHigh,
    outline: palette.outline,
    outlineVariant: palette.outline,
  );
  final radius = BorderRadius.circular(AppSpacing.radiusSmall);
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    dividerColor: palette.outline,
    textTheme: base.textTheme.apply(bodyColor: palette.text, displayColor: palette.text),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: palette.text,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(color: palette.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: palette.text,
        side: BorderSide(color: palette.outline),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: accent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: palette.outline,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.16),
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : palette.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : palette.outline,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      interactive: true,
      thickness: const WidgetStatePropertyAll(5),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(palette.muted.withValues(alpha: isDark ? 0.55 : 0.5)),
      crossAxisMargin: 2,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: accent,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: palette.outline),
      ),
    ),
    extensions: [
      GalleryColors(
        stage: palette.stage,
        stageGrid: palette.stageGrid,
        muted: palette.muted,
        success: const Color(0xFF22C55E),
        danger: const Color(0xFFEF4444),
        favorite: accent,
        codeBackground: isDark ? const Color(0xFF0A1122) : const Color(0xFFF7F9FD),
        codeGutter: palette.muted.withValues(alpha: 0.7),
        codeText: palette.text,
        codeTag: isDark ? const Color(0xFF5CC8FF) : const Color(0xFF0B63CE),
        codeAttribute: isDark ? const Color(0xFFC792EA) : const Color(0xFF8A3FD1),
        codeValue: isDark ? const Color(0xFFFFB86B) : const Color(0xFFB45309),
        codeComment: palette.muted,
        codePunctuation: isDark ? const Color(0xFF7E8BA8) : const Color(0xFF6B7890),
      ),
    ],
  );
}
