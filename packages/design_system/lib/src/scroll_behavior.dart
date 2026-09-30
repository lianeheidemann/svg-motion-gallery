import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Shows a draggable scrollbar on every scroll view, on every platform and
/// in both axes (Material only does this on desktop by default). Combined
/// with the theme's always-visible thumb, every scrollable area of the app
/// can also be moved by dragging its bar.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (details.controller == null) return child;
    return Scrollbar(controller: details.controller, child: child);
  }
}
