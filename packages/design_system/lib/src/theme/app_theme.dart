import 'package:flutter/material.dart';

import 'gallery_colors.dart';
import 'tokens.dart';

/// Builds the Material 3 theme for [brightness] with the chosen [accent].
ThemeData buildAppTheme({
  required Brightness brightness,
  Color accent = const Color(0xFF1E7BFF),
}) {
  final palette = AppPalette.of(brightness);
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
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
  final radius = BorderRadius.circular(14);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );

  final textTheme = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontSize: AppTypeScale.heading,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: AppTypeScale.appBar,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: AppTypeScale.title,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: AppTypeScale.titleSmall,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: AppTypeScale.body,
      height: 1.4,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: AppTypeScale.body,
      height: 1.4,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: AppTypeScale.bodySmall,
      height: 1.35,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: AppTypeScale.label,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: AppTypeScale.bodySmall,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: AppTypeScale.caption,
      fontWeight: FontWeight.w600,
    ),
  ).apply(bodyColor: palette.text, displayColor: palette.text);

  ButtonStyle buttonStyle({
    Color? foregroundColor,
    BorderSide? side,
  }) =>
      ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(48, AppSizes.controlHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w700,
          ),
        ),
        foregroundColor:
            foregroundColor == null ? null : WidgetStatePropertyAll(foregroundColor),
        side: side == null ? null : WidgetStatePropertyAll(side),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    dividerColor: palette.outline.withValues(alpha: .7),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(letterSpacing: -.2),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(color: palette.outline.withValues(alpha: .62)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.outline.withValues(alpha: .75)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle(foregroundColor: accent).copyWith(
        minimumSize: const WidgetStatePropertyAll(
          Size(40, AppSizes.compactControlHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size.square(AppSizes.iconButton),
        ),
        iconSize: const WidgetStatePropertyAll(20),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 1,
      extendedTextStyle: const TextStyle(
        fontSize: AppTypeScale.label,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceHigh,
      selectedColor: accent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: palette.text,
        fontSize: AppTypeScale.bodySmall,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppTypeScale.bodySmall,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceHigh,
      isDense: true,
      constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(
        color: palette.muted,
        fontSize: AppTypeScale.bodySmall,
      ),
      hintStyle: TextStyle(
        color: palette.muted,
        fontSize: AppTypeScale.body,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: palette.outline,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.16),
      trackHeight: AppSizes.sliderTrackHeight,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: AppSizes.sliderThumbRadius,
      ),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : palette.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : palette.outline,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      interactive: true,
      thickness: const WidgetStatePropertyAll(5),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(
        palette.muted.withValues(alpha: isDark ? 0.48 : 0.42),
      ),
      crossAxisMargin: 2,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.outline.withValues(alpha: .7)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, AppSizes.controlHeight),
        selectedBackgroundColor: accent,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: palette.outline.withValues(alpha: .7)),
        textStyle: const TextStyle(
          fontSize: AppTypeScale.label,
          fontWeight: FontWeight.w600,
        ),
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
        codeBackground:
            isDark ? const Color(0xFF0A1122) : const Color(0xFFF7F9FD),
        codeGutter: palette.muted.withValues(alpha: 0.7),
        codeText: palette.text,
        codeTag:
            isDark ? const Color(0xFF5CC8FF) : const Color(0xFF0B63CE),
        codeAttribute:
            isDark ? const Color(0xFFC792EA) : const Color(0xFF8A3FD1),
        codeValue:
            isDark ? const Color(0xFFFFB86B) : const Color(0xFFB45309),
        codeComment: palette.muted,
        codePunctuation:
            isDark ? const Color(0xFF7E8BA8) : const Color(0xFF6B7890),
      ),
    ],
  );
}
