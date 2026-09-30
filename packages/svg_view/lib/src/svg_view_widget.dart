import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:svg_core/svg_core.dart';

import 'platform/live_svg_config.dart';
import 'platform/platform_svg.dart';
import 'playback_controller.dart';
import 'render_pipeline.dart';

/// How an [SvgView] renders.
enum SvgRenderMode {
  /// Live renderer (WebView/iframe) with CSS/SMIL animation when available,
  /// otherwise the static fallback.
  live,

  /// Lightweight flutter_svg rendering without animation.
  still,
}

/// Overrides rendering for a subtree, e.g. to force still rendering in tests.
class SvgViewScope extends InheritedWidget {
  const SvgViewScope({super.key, required super.child, this.forceStill = false});

  final bool forceStill;

  static bool forceStillOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SvgViewScope>()?.forceStill ?? false;

  @override
  bool updateShouldNotify(SvgViewScope oldWidget) => oldWidget.forceStill != forceStill;
}

/// Displays an SVG document in the given light/dark [scheme].
///
/// The markup goes through [prepareSvgForDisplay] (sanitize, resolve the
/// theme variant, loop) and is then rendered live when possible, so CSS and
/// SMIL animations play exactly like in a browser.
class SvgView extends StatelessWidget {
  const SvgView({
    super.key,
    required this.svg,
    required this.scheme,
    this.mode = SvgRenderMode.live,
    this.autoplay = true,
    this.loop = false,
    this.interactive = false,
    this.controller,
    this.semanticLabel,
  });

  final String svg;
  final SvgColorScheme scheme;
  final SvgRenderMode mode;
  final bool autoplay;

  /// Forces every animation to repeat forever (render-time only).
  final bool loop;

  /// Lets pointer events reach the SVG (links are still blocked).
  final bool interactive;

  /// Enables play/pause/seek. Ignored by the still renderer.
  final SvgPlaybackController? controller;
  final String? semanticLabel;

  /// Whether this platform has a live renderer at all.
  static bool get supportsLiveRendering => platformSupportsLiveSvg;

  @override
  Widget build(BuildContext context) {
    final live =
        mode == SvgRenderMode.live &&
        platformSupportsLiveSvg &&
        !SvgViewScope.forceStillOf(context);
    // flutter_svg ignores <style>, so the still renderer gets inlined CSS.
    final prepared = prepareSvgForDisplay(svg, scheme: scheme, loop: loop, inlineCss: !live);
    final child = live
        ? buildLiveSvg(
            LiveSvgConfig(
              svg: prepared,
              scheme: scheme,
              autoplay: autoplay,
              interactive: interactive,
              controller: controller,
            ),
          )
        : _StillSvg(svg: prepared, scheme: scheme);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}

class _StillSvg extends StatelessWidget {
  const _StillSvg({required this.svg, required this.scheme});

  final String svg;
  final SvgColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final hex = SvgThemeResolver.defaultCurrentColor[scheme]!.substring(1);
    return SvgPicture.string(
      svg,
      fit: BoxFit.contain,
      theme: SvgTheme(currentColor: Color(0xFF000000 | int.parse(hex, radix: 16))),
      errorBuilder: (context, error, stackTrace) =>
          Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).disabledColor)),
    );
  }
}
