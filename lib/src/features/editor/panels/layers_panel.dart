import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/svg_actions_menu.dart';
import '../editor_controller.dart';
import 'layers/layer_actions.dart';
import 'layers/layer_theme_sheet.dart';
import 'layers/theme_badge.dart';

/// Layer list (select, show/hide) and actions on the selected layer. Double
/// tap a layer to rename it; the arrow on a folder folds it, and two taps on
/// the header fold or open every folder. Layers with the
/// same name next to each other are numbered.
///
/// In a file with light and dark versions, a sun and/or a moon after a
/// layer's name says which version has a setting of its own for it (solid)
/// or takes one from a group around it (outlined, "↳ herda"); the version
/// being edited is in color. Layers not drawn in that version are greyed
/// out, and a tap on the marks opens the layer's theme settings.
class LayersPanel extends StatefulWidget {
  const LayersPanel({
    super.key,
    required this.editor,
    this.themeScheme,
    this.onToggleTheme,
    this.onOpenColors,
  });

  final EditorController editor;

  /// The light/dark version being viewed and edited; null when the file has
  /// no such versions (the toggle is then not shown).
  final SvgColorScheme? themeScheme;

  /// Switches between the light and the dark version.
  final VoidCallback? onToggleTheme;

  /// Goes to the Colors tab (from a layer's theme settings).
  final VoidCallback? onOpenColors;

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

  /// Folds every folder; when they are all folded already, opens them all.
  void _toggleFoldAll(List<SvgLayer> layers) {
    final folders = <ElementPath>{
      for (var i = 0; i + 1 < layers.length; i++)
        if (layers[i + 1].depth > layers[i].depth) layers[i].path,
    };
    setState(() {
      if (folders.isNotEmpty && folders.every(_folded.contains)) {
        _folded.clear();
      } else {
        _folded
          ..clear()
          ..addAll(folders);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layers = editor.layers;
    if (layers.length != _layerCount) {
      _layerCount = layers.length;
      _folded.clear();
    }
    final multi = editor.multiMode;
    final ticked = editor.multiSelection.toSet();
    final scheme = Theme.of(context).colorScheme;
    final labels = l10n.layerLabels(layers);
    // The nearest hidden folder around each layer: what is in it is hidden too.
    final hiddenBy = <ElementPath, SvgLayer>{};
    final open = <SvgLayer>[];
    for (final layer in layers) {
      while (open.isNotEmpty && open.last.depth >= layer.depth) {
        open.removeLast();
      }
      final folder = open.reversed.where((l) => !l.visible).firstOrNull;
      if (folder != null) hiddenBy[layer.path] = folder;
      open.add(layer);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        LayerActionsCard(
          editor: editor,
          themeScheme: widget.themeScheme,
          onToggleTheme: widget.onToggleTheme,
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.layers_outlined,
          title: l10n.layersTitle(layers.length),
          // Small box in the corner: ticked, a tap on a layer ticks it instead
          // of selecting only it.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: l10n.multiSelect,
                child: Semantics(
                  label: l10n.multiSelect,
                  child: Checkbox(
                    key: const Key('multi-select'),
                    value: multi,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) => editor.setMultiMode(value ?? false),
                  ),
                ),
              ),
            ],
          ),
          // Two taps on the header fold every folder, or open them all again.
          onTitleDoubleTap: () => _toggleFoldAll(layers),
          spacing: 0,
          children: [
            if (layers.isEmpty) Text(l10n.layersEmpty),
            if (multi && ticked.isEmpty && layers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.multiSelectNone, style: TextStyle(color: scheme.outline)),
              ),
            for (var i = 0; i < layers.length; i++)
              if (!_hidden(layers[i]))
                _row(context, layers, i, ticked, scheme, labels, hiddenBy[layers[i].path]),
          ],
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    List<SvgLayer> layers,
    int index,
    Set<ElementPath> ticked,
    ColorScheme scheme,
    Map<ElementPath, String> labels,
    SvgLayer? hiddenFolder,
  ) {
    final l10n = context.l10n;
    final layer = layers[index];
    final isFolder = index + 1 < layers.length && layers[index + 1].depth > layer.depth;
    final folded = _folded.contains(layer.path);
    var insideCount = 0;
    for (var j = index + 1; j < layers.length && layers[j].depth > layer.depth; j++) {
      insideCount++;
    }
    final multi = editor.multiMode;
    final isSelected = multi ? ticked.contains(layer.path) : layer.path == editor.selection;
    // A folder with only some of its layers ticked shows a dash.
    final partly =
        multi &&
        !isSelected &&
        [for (var j = index + 1; j <= index + insideCount; j++) layers[j].path]
            .any(ticked.contains);
    final theme = widget.themeScheme;
    final mark = theme == null || layer.isEditorGroup ? null : editor.themeMarks[layer.path];
    // Hidden, by itself or by a folder around it: greyed out. A layer the
    // version being edited does not draw keeps its open eye and its colors.
    final shown = layer.visible && hiddenFolder == null;
    final dim = !shown;
    // What the layers inside a folded folder set for each version.
    final inside = folded && theme != null
        ? {
            for (var j = index + 1; j <= index + insideCount; j++)
              for (final scheme in SvgColorScheme.values)
                if (editor.themeMarks[layers[j].path]?.originIn(scheme) == SvgThemeOrigin.own)
                  scheme,
          }
        : const <SvgColorScheme>{};
    // The arrow, the marks and the eye sit outside the InkWell: it waits for a
    // possible second tap (rename), which would make them feel slow.
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
                // Rename and delete are for one layer; skip them while ticking.
                onDoubleTap: layer.isEditorGroup || multi
                    ? null
                    : () => widget._rename(context, layer),
                onLongPress: multi ? null : () => widget._confirmDelete(context, layer),
                child: Row(
                  children: [
                    if (multi)
                      IgnorePointer(
                        child: Checkbox(
                          key: ValueKey('tick-${layer.path}'),
                          tristate: true,
                          value: isSelected ? true : (partly ? null : false),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (_) {},
                        ),
                      ),
                    Icon(LayersPanel.iconFor(layer), size: 20, color: dim ? scheme.outline : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labels[layer.path] ?? l10n.layer(layer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dim ? scheme.outline : null,
                          fontWeight: isSelected ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (folded)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+$insideCount',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                            ),
                            if (inside.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              ThemeInsideMarks(schemes: inside, active: theme!),
                            ],
                          ],
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
            if (mark != null && theme != null) _themeMarks(context, layer, mark, theme),
            // The eye is for both versions; one version alone is hidden in the
            // theme settings. Inside a hidden folder it is closed and off:
            // showing the folder brings each layer back as it was.
            if (hiddenFolder != null)
              Tooltip(
                message: l10n.hiddenByFolder(labels[hiddenFolder.path] ?? l10n.layer(hiddenFolder)),
                child: IconButton(
                  key: ValueKey('eye-${layer.path}'),
                  onPressed: null,
                  icon: const Icon(Icons.visibility_off_outlined, size: 20),
                ),
              )
            else
              IconButton(
                key: ValueKey('eye-${layer.path}'),
                tooltip: theme == null
                    ? (layer.visible ? l10n.hideLayer : l10n.showLayer)
                    : (layer.visible ? l10n.hideLayerBoth : l10n.showLayerBoth),
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

  /// The sun/moon of [layer], which open its theme settings; nothing when it
  /// has no setting for either version.
  Widget _themeMarks(
    BuildContext context,
    SvgLayer layer,
    SvgThemeMark mark,
    SvgColorScheme theme,
  ) {
    final l10n = context.l10n;
    void open() => showLayerThemeSheet(
      context,
      editor: editor,
      path: layer.path,
      onOpenColors: widget.onOpenColors,
    );
    if (mark.isEmpty) return const SizedBox.shrink();
    final layers = editor.layers;
    // The folder right around the layer (its editor groups are not layers).
    final rows = {for (final l in layers) l.path};
    var parent = layer.path.parent;
    while (parent != null && !parent.isRoot && !rows.contains(parent)) {
      parent = parent.parent;
    }
    return ThemeMarkBadge(
      key: ValueKey('theme-mark-${layer.path}'),
      mark: mark,
      active: theme,
      startsHere: SvgColorScheme.values.any((scheme) => mark.sourceIn(scheme) == parent),
      label: themeMarkSummary(l10n, mark, theme, (path) {
        if (path.isRoot) return l10n.themeWholeDrawing;
        final source = layers.where((l) => l.path == path).firstOrNull;
        return source == null ? '' : l10n.layerLabel(source, layers);
      }),
      onTap: open,
    );
  }
}
