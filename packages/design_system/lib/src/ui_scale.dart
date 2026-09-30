import 'package:flutter/widgets.dart';

/// Shrinks (or enlarges) everything below it uniformly: text, icons, buttons,
/// cards, spacing, dialogs and menus.
///
/// The subtree is laid out on a "virtual" screen of `size / scale` and then
/// drawn scaled into the real one, so a [scale] of `0.7` gives every screen
/// 1/0.7 times more room and renders it 30% smaller. Touches keep landing on
/// the right widget because [Transform] maps them back.
///
/// [MediaQuery] is adjusted to the virtual screen (size, paddings, insets), so
/// the status bar, the keyboard and every `MediaQuery.sizeOf` based layout keep
/// working. Place it in `MaterialApp.builder` so routes, dialogs, menus and
/// snack bars scale too.
///
/// The widget structure does not change with [scale]: at `1` the transform is
/// the identity, which paints the child directly, and route state survives
/// when the user changes the scale.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.child});

  /// 1 keeps the normal size; below 1 shrinks the interface.
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(scale > 0, 'scale must be positive');
    final media = MediaQuery.of(context);
    final size = media.size / scale;
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
