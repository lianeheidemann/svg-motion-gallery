import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/svg_actions_menu.dart';
import '../editor_controller.dart';

/// Layer list (select, show/hide) and actions on the selected layer.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key, required this.editor});

  final EditorController editor;

  static IconData iconFor(SvgLayer layer) => switch (layer.tag) {
    _ when layer.isEditorGroup => Icons.tune_rounded,
    'g' => Icons.folder_outlined,
    'rect' => Icons.crop_square_rounded,
    'circle' || 'ellipse' => Icons.circle_outlined,
    'line' || 'polyline' => Icons.horizontal_rule_rounded,
    'polygon' => Icons.star_outline_rounded,
    'path' => Icons.gesture_rounded,
    'text' || 'tspan' => Icons.text_fields_rounded,
    'image' => Icons.image_outlined,
    _ => Icons.layers_outlined,
  };

  /// Long press on a row: select it and ask before removing it.
  Future<void> _confirmDelete(BuildContext context, SvgLayer layer) async {
    final l10n = context.l10n;
    if (editor.selection != layer.path) editor.select(layer.path);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLayerTitle,
      message: l10n.deleteLayerMessage(l10n.layer(layer)),
      confirm: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed) editor.apply(SvgLayers.remove(editor.svg, layer.path));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layers = editor.layers;
    final selected = editor.selectedLayer;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (selected != null) ...[
          _SelectedLayerActions(editor: editor, layer: selected),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          icon: Icons.layers_outlined,
          title: l10n.layersTitle(layers.length),
          spacing: 0,
          children: [
            if (layers.isEmpty) Text(l10n.layersEmpty),
            for (final layer in layers)
              Material(
                color: layer.path == selected?.path
                    ? scheme.primary.withValues(alpha: .16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => editor.select(layer.path),
                  onLongPress: () => _confirmDelete(context, layer),
                  child: Padding(
                    padding: EdgeInsets.only(left: 4.0 + layer.depth * 16),
                    child: Row(
                      children: [
                        Icon(
                          iconFor(layer),
                          size: 20,
                          color: layer.visible ? null : scheme.outline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.layer(layer),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: layer.visible ? null : scheme.outline,
                              fontWeight: layer.path == selected?.path ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                        if (layer.isAnimated)
                          Tooltip(
                            message: l10n.layerAnimated,
                            child: Icon(Icons.animation_rounded, size: 16, color: scheme.primary),
                          ),
                        IconButton(
                          tooltip: layer.visible ? l10n.hideLayer : l10n.showLayer,
                          onPressed: () =>
                              editor.commit(SvgLayers.toggleVisibility(editor.svg, layer.path)),
                          icon: Icon(
                            layer.visible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SelectedLayerActions extends StatelessWidget {
  const _SelectedLayerActions({required this.editor, required this.layer});

  final EditorController editor;
  final SvgLayer layer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final svg = editor.svg;
    return SectionCard(
      icon: LayersPanel.iconFor(layer),
      title: l10n.layer(layer),
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

  Widget _action(IconData icon, String label, VoidCallback onPressed) =>
      OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
}
