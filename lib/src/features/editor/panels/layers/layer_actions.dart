import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../../l10n/l10n.dart';
import '../../../../widgets/svg_actions_menu.dart';
import '../../editor_controller.dart';
import 'theme_badge.dart';

/// The box at the top of the Layers tab, always there: select all, clear the
/// selection, and the actions on what is selected (order, duplicate, show or
/// hide, delete). An action that does not fit the current selection (nothing
/// selected, several layers for ordering) stays on screen but greyed out.
class LayerActionsCard extends StatelessWidget {
  const LayerActionsCard({super.key, required this.editor, this.themeScheme, this.onToggleTheme});

  final EditorController editor;

  /// The theme being edited (null when the drawing has no light/dark variants)
  /// and the switch between them, shown first and highlighted.
  final SvgColorScheme? themeScheme;
  final VoidCallback? onToggleTheme;

  Future<void> _delete(BuildContext context, int count) async {
    final l10n = context.l10n;
    if (count > 1) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.deleteLayersTitle,
        message: l10n.deleteLayersMessage(count),
        confirm: l10n.actionDelete,
        destructive: true,
      );
      if (!confirmed) return;
    }
    editor.removeTargets();
  }

  /// Hides the visible ones; when they are all hidden already, shows them.
  void _toggleVisibility() {
    final targets = editor.targets.toSet();
    final layers = editor.layers.where((layer) => targets.contains(layer.path)).toList();
    final hide = layers.any((layer) => layer.visible);
    final change = {
      for (final layer in layers)
        if (layer.visible == hide) layer.path,
    };
    editor.applyToTargets(
      (svg, path) => change.contains(path) ? SvgLayers.toggleVisibility(svg, path) : svg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targets = editor.targets;
    final count = targets.length;
    final has = count > 0;
    final single = count == 1
        ? editor.layers.where((l) => l.path == targets.first).firstOrNull
        : null;
    final svg = editor.svg;

    Widget action(Key key, IconData icon, String tip, VoidCallback? onPressed) =>
        IconButton.outlined(
          key: key,
          tooltip: tip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        );

    final theme = themeScheme;
    final actions = [
      action(
        const Key('select-all-layers'),
        Icons.select_all_rounded,
        l10n.selectAllLayers,
        editor.selectAllLayers,
      ),
      action(
        const Key('clear-selection'),
        Icons.deselect_rounded,
        l10n.clearSelection,
        has ? () => editor.select(null) : null,
      ),
      action(
        const Key('layer-forward'),
        Icons.flip_to_front_rounded,
        l10n.bringForward,
        single == null ? null : () => editor.apply(SvgLayers.bringForward(svg, single.path)),
      ),
      action(
        const Key('layer-backward'),
        Icons.flip_to_back_rounded,
        l10n.sendBackward,
        single == null ? null : () => editor.apply(SvgLayers.sendBackward(svg, single.path)),
      ),
      action(
        const Key('layer-duplicate'),
        Icons.copy_all_rounded,
        l10n.actionDuplicate,
        !has
            ? null
            : single != null
            ? () => editor.apply(SvgLayers.duplicate(svg, single.path))
            : editor.duplicateTargets,
      ),
      action(
        const Key('layer-visibility'),
        Icons.visibility_outlined,
        // In a light/dark file it hides in both versions; one version
        // alone is hidden in a layer's theme settings.
        themeScheme == null ? l10n.hideLayer : l10n.hideLayerBoth,
        has ? _toggleVisibility : null,
      ),
      action(
        const Key('layer-delete'),
        Icons.delete_outline_rounded,
        l10n.actionDelete,
        has ? () => _delete(context, count) : null,
      ),
    ];

    // No title: the line above the box already says what is selected. The
    // version being edited stays in front; the actions slide sideways.
    return SectionCard(
      children: [
        Row(
          children: [
            if (theme != null) ...[
              Tooltip(
                message: theme == SvgColorScheme.light ? l10n.editingLight : l10n.editingDark,
                child: FilledButton(
                  key: const Key('theme-variant'),
                  onPressed: onToggleTheme,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 12, 0),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(themeIcon(theme), size: 20),
                      const SizedBox(width: 6),
                      Text(l10n.themeTitle(theme)),
                      const SizedBox(width: 6),
                      const Icon(Icons.swap_horiz_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _SlidingRow(children: actions)),
          ],
        ),
        if (single != null && single.tag == 'text')
          TextFormField(
            key: ValueKey('text-${single.path}-${single.text}'),
            initialValue: single.text ?? '',
            decoration: InputDecoration(labelText: l10n.textContent),
            onFieldSubmitted: (text) => editor.commit(SvgLayers.setText(svg, single.path, text)),
          ),
      ],
    );
  }
}

/// A row of buttons that never wraps: what does not fit slides in with a
/// finger, and the end fades out to show there is more.
class _SlidingRow extends StatelessWidget {
  const _SlidingRow({required this.children});

  final List<Widget> children;

  static const _fade = 24.0;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0, 1 - _fade / bounds.width, 1],
      ).createShader(bounds),
      // No scrollbar over the buttons: the fade says there is more.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          key: const Key('layer-actions-row'),
          scrollDirection: Axis.horizontal,
          // Room at the end, so the last button can leave the fade.
          padding: const EdgeInsetsDirectional.only(end: _fade),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
