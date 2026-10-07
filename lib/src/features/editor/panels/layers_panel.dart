import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/svg_actions_menu.dart';
import '../editor_controller.dart';

/// Layer list (select, show/hide) and actions on the selected layer. Double
/// tap a layer to rename it; the arrow on a folder folds it. Layers with the
/// same name next to each other are numbered.
class LayersPanel extends StatefulWidget {
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

  /// Double tap on a row: asks for a new name. An empty name goes back to the
  /// default one. Editor wrappers have no name to change.
  Future<void> _rename(BuildContext context, SvgLayer layer) async {
    if (layer.isEditorGroup) return;
    final l10n = context.l10n;
    final current = l10n.layer(layer);
    if (editor.selection != layer.path) editor.select(layer.path);
    final name = await showTextInputDialog(
      context,
      title: l10n.renameLayerTitle,
      label: l10n.renameLayerLabel,
      initial: current,
      confirm: l10n.renameConfirm,
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed == current) return;
    editor.commit(SvgLayers.rename(editor.svg, layer.path, trimmed));
  }

  /// Long press on a row: select it and ask before removing it.
  Future<void> _confirmDelete(BuildContext context, SvgLayer layer) async {
    final l10n = context.l10n;
    if (editor.selection != layer.path) editor.select(layer.path);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLayerTitle,
      message: l10n.deleteLayerMessage(l10n.layerLabel(layer, editor.layers)),
      confirm: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed) editor.apply(SvgLayers.remove(editor.svg, layer.path));
  }

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  /// Folded folders. Cleared when layers are added or removed, since paths
  /// would then point at other elements.
  final _folded = <ElementPath>{};
  var _layerCount = -1;

  EditorController get editor => widget.editor;

  /// Whether [layer] sits inside a folded folder.
  bool _hidden(SvgLayer layer) => _folded.any(
    (folder) =>
        folder.depth < layer.path.depth &&
        [for (var i = 0; i < folder.depth; i++) folder.indices[i] == layer.path.indices[i]]
            .every((same) => same),
  );

  void _toggleFold(ElementPath path) =>
      setState(() => _folded.contains(path) ? _folded.remove(path) : _folded.add(path));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layers = editor.layers;
    if (layers.length != _layerCount) {
      _layerCount = layers.length;
      _folded.clear();
    }
    final selected = editor.selectedLayer;
    final scheme = Theme.of(context).colorScheme;
    final labels = l10n.layerLabels(layers);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (selected != null) ...[
          _SelectedLayerActions(editor: editor, layer: selected, label: labels[selected.path]),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          icon: Icons.layers_outlined,
          title: l10n.layersTitle(layers.length),
          // Two taps on the header select every layer: the whole drawing.
          onTitleDoubleTap: () => editor.select(null),
          spacing: 0,
          children: [
            if (layers.isEmpty) Text(l10n.layersEmpty),
            for (var i = 0; i < layers.length; i++)
              if (!_hidden(layers[i])) _row(context, layers, i, selected, scheme, labels),
          ],
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    List<SvgLayer> layers,
    int index,
    SvgLayer? selected,
    ColorScheme scheme,
    Map<ElementPath, String> labels,
  ) {
    final l10n = context.l10n;
    final layer = layers[index];
    final isFolder = index + 1 < layers.length && layers[index + 1].depth > layer.depth;
    final folded = _folded.contains(layer.path);
    var inside = 0;
    for (var j = index + 1; j < layers.length && layers[j].depth > layer.depth; j++) {
      inside++;
    }
    final isSelected = layer.path == selected?.path;
    // The arrow and the eye sit outside the InkWell: it waits for a possible
    // second tap (rename), which would make them feel slow.
    return Material(
      color: isSelected ? scheme.primary.withValues(alpha: .16) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.only(left: 4.0 + layer.depth * 16),
        child: Row(
          children: [
            if (isFolder)
              IconButton(
                key: ValueKey('fold-${layer.path}'),
                tooltip: folded ? l10n.unfoldFolder : l10n.foldFolder,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _toggleFold(layer.path),
                icon: Icon(
                  folded ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                  size: 22,
                ),
              )
            else
              const SizedBox(width: 32),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => editor.select(layer.path),
                onDoubleTap: layer.isEditorGroup ? null : () => widget._rename(context, layer),
                onLongPress: () => widget._confirmDelete(context, layer),
                child: Row(
                  children: [
                    Icon(
                      LayersPanel.iconFor(layer),
                      size: 20,
                      color: layer.visible ? null : scheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labels[layer.path] ?? l10n.layer(layer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: layer.visible ? null : scheme.outline,
                          fontWeight: isSelected ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (folded)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '+$inside',
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (layer.isAnimated)
                      Tooltip(
                        message: l10n.layerAnimated,
                        child: Icon(Icons.animation_rounded, size: 16, color: scheme.primary),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: layer.visible ? l10n.hideLayer : l10n.showLayer,
              onPressed: () => editor.commit(SvgLayers.toggleVisibility(editor.svg, layer.path)),
              icon: Icon(
                layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLayerActions extends StatelessWidget {
  const _SelectedLayerActions({required this.editor, required this.layer, this.label});

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
