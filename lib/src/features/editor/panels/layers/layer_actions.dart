import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../../l10n/l10n.dart';
import '../../../../widgets/svg_actions_menu.dart';
import '../../editor_controller.dart';
import '../layers_panel.dart';

/// Actions on the one selected layer (order, duplicate, delete).
class SelectedLayerActions extends StatelessWidget {
  const SelectedLayerActions({super.key, required this.editor, required this.layer, this.label});

  final EditorController editor;
  final SvgLayer layer;

  /// Name with its number, as the list shows it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final svg = editor.svg;
    return SectionCard(
      icon: LayersPanel.iconFor(layer),
      title: label ?? l10n.layer(layer),
      trailing: IconButton(
        tooltip: l10n.clearSelection,
        onPressed: () => editor.select(null),
        icon: const Icon(Icons.close_rounded),
      ),
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _action(
              Icons.flip_to_front_rounded,
              l10n.bringForward,
              () => editor.apply(SvgLayers.bringForward(svg, layer.path)),
            ),
            _action(
              Icons.flip_to_back_rounded,
              l10n.sendBackward,
              () => editor.apply(SvgLayers.sendBackward(svg, layer.path)),
            ),
            _action(
              Icons.copy_all_rounded,
              l10n.actionDuplicate,
              () => editor.apply(SvgLayers.duplicate(svg, layer.path)),
            ),
            _action(
              Icons.delete_outline_rounded,
              l10n.actionDelete,
              () => editor.apply(SvgLayers.remove(svg, layer.path)),
            ),
          ],
        ),
        if (layer.tag == 'text')
          TextFormField(
            key: ValueKey('text-${layer.path}-${layer.text}'),
            initialValue: layer.text ?? '',
            decoration: InputDecoration(labelText: l10n.textContent),
            onFieldSubmitted: (text) => editor.commit(SvgLayers.setText(svg, layer.path, text)),
          ),
      ],
    );
  }

  /// Icon only (the meaning is in the tooltip).
  Widget _action(IconData icon, String label, VoidCallback onPressed) =>
      IconButton.outlined(tooltip: label, onPressed: onPressed, icon: Icon(icon, size: 20));
}

/// Actions on every ticked layer (multi-selection).
/// Actions on every ticked layer at once.
class MultiLayerActions extends StatelessWidget {
  const MultiLayerActions({super.key, required this.editor});

  final EditorController editor;

  Future<void> _delete(BuildContext context, int count) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLayersTitle,
      message: l10n.deleteLayersMessage(count),
      confirm: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed) editor.removeTargets();
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
    final count = editor.multiSelection.length;
    return SectionCard(
      icon: Icons.checklist_rounded,
      title: l10n.multiSelectCount(count),
      trailing: IconButton(
        tooltip: l10n.clearSelection,
        onPressed: () => editor.select(null),
        icon: const Icon(Icons.close_rounded),
      ),
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            IconButton.outlined(
              key: const Key('select-all-actions'),
              tooltip: l10n.selectAllLayers,
              onPressed: editor.selectAllLayers,
              icon: const Icon(Icons.select_all_rounded, size: 20),
            ),
            IconButton.outlined(
              tooltip: l10n.actionDuplicate,
              onPressed: editor.duplicateTargets,
              icon: const Icon(Icons.copy_all_rounded, size: 20),
            ),
            IconButton.outlined(
              tooltip: l10n.hideLayer,
              onPressed: _toggleVisibility,
              icon: const Icon(Icons.visibility_outlined, size: 20),
            ),
            IconButton.outlined(
              tooltip: l10n.actionDelete,
              onPressed: () => _delete(context, count),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
