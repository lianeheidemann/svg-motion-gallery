import 'package:flutter/widgets.dart';

import 'live_svg_config.dart';

/// No live renderer on this platform; `SvgView` falls back to flutter_svg.
bool get platformSupportsLiveSvg => false;

Widget buildLiveSvg(LiveSvgConfig config) => const SizedBox.shrink();
