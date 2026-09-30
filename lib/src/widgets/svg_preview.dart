import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../app_scope.dart';

/// The app's color scheme as an [SvgColorScheme].
SvgColorScheme schemeOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? SvgColorScheme.dark : SvgColorScheme.light;

/// An SVG on a [Stage], rendered with the user's playback settings.
///
/// Adaptive SVGs follow the app theme unless [scheme] forces a variant.
class SvgPreview extends StatelessWidget {
  const SvgPreview({
    super.key,
    required this.svg,
    this.scheme,
    this.thumbnail = false,
    this.controller,
    this.showGrid = false,
    this.interactive = false,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = AppSpacing.radius,
    this.semanticLabel,
  });

  final String svg;
  final SvgColorScheme? scheme;

  /// Thumbnails honour "high quality previews" and render still otherwise.
  final bool thumbnail;
  final SvgPlaybackController? controller;
  final bool showGrid;
  final bool interactive;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final value = settings.value;
        final still = thumbnail && (!value.highQualityPreviews || !value.autoplay);
        return Stage(
          showGrid: showGrid,
          borderRadius: borderRadius,
          padding: padding,
          child: SvgView(
            svg: svg,
            scheme: scheme ?? schemeOf(context),
            mode: still ? SvgRenderMode.still : SvgRenderMode.live,
            autoplay: value.autoplay,
            loop: value.loop,
            controller: controller,
            interactive: interactive,
            semanticLabel: semanticLabel,
          ),
        );
      },
    );
  }
}
