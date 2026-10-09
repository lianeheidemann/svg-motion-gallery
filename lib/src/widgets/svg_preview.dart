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
    this.forceStill = false,
    this.controller,
    this.showGrid = false,
    this.background = StageBackground.current,
    this.interactive = false,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = AppSpacing.radius,
    this.semanticLabel,
    this.autoplay,
  });

  final String svg;
  final SvgColorScheme? scheme;

  /// Thumbnails honour "high quality previews" and render still otherwise.
  final bool thumbnail;

  /// Renders the lightweight still image regardless of settings. The gallery
  /// uses it while scrolling so hundreds of files never spin up hundreds of
  /// web views.
  final bool forceStill;
  final SvgPlaybackController? controller;
  final bool showGrid;
  final StageBackground background;
  final bool interactive;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final String? semanticLabel;

  /// Overrides the "autoplay" setting (false renders paused at the start).
  final bool? autoplay;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final value = settings.value;
        final still = forceStill || (thumbnail && (!value.highQualityPreviews || !value.autoplay));
        return Stage(
          showGrid: showGrid,
          background: background,
          borderRadius: borderRadius,
          padding: padding,
          child: SvgView(
            svg: svg,
            scheme: scheme ?? schemeOf(context),
            mode: still ? SvgRenderMode.still : SvgRenderMode.live,
            autoplay: autoplay ?? value.autoplay,
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
