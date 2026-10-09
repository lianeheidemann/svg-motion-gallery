import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../../l10n/l10n.dart';
import '../../../../widgets/svg_actions_menu.dart';
import '../../editor_controller.dart';
import '../layers_panel.dart';

/// The box at the top of the Layers tab, always there: select all, clear the
/// selection, and the actions on what is selected (order, duplicate, show or
/// hide, delete). An action that does not fit the current selection (nothing
/// selected, several layers for ordering) stays on screen but greyed out.
class LayerActionsCard extends StatelessWidget {
  const LayerActionsCard({super.key, required this.editor, this.label});

  final EditorController editor;

  /// Name with its number of the selected layer, as the list shows it.
  final String? label;

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

    return SectionCard(
      icon: single != null
          ? LayersPanel.iconFor(single)
          : has
          ? Icons.checklist_rounded
          : Icons.select_all_rounded,
      title: single != null
          ? (label ?? l10n.layer(single))
          : has
          ? l10n.multiSelectCount(count)
          : l10n.noLayerSelected,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
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
              l10n.hideLayer,
              has ? _toggleVisibility : null,
            ),
            action(
              const Key('layer-delete'),
              Icons.delete_outline_rounded,
              l10n.actionDelete,
              has ? () => _delete(context, count) : null,
            ),
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
