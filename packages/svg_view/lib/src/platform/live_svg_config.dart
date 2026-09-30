import 'package:svg_core/svg_core.dart';

import '../playback_controller.dart';

/// Everything a live (scripted) renderer needs.
class LiveSvgConfig {
  const LiveSvgConfig({
    required this.svg,
    required this.scheme,
    required this.autoplay,
    required this.interactive,
    this.controller,
  });

  /// Already prepared markup (sanitized, theme-resolved).
  final String svg;
  final SvgColorScheme scheme;
  final bool autoplay;
  final bool interactive;

  /// When set, the JavaScript bridge is enabled and wired to it.
  final SvgPlaybackController? controller;
}
