import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../l10n/l10n.dart';
import '../../widgets/svg_preview.dart';
import 'before_after.dart';
import 'editor_controller.dart';
import 'editor_tabs.dart';
import 'panels/layers_panel.dart';
import 'selection_highlight.dart';
import 'selection_outlines.dart';
import 'stage_drag_layer.dart';
import 'stage_geometry.dart';

/// The editor's preview with everything drawn over it (before/after compare,
/// eyedropper, drag to move, selection outline) and the line under it: what
/// is selected, play/pause, clear selection, preview background and reset.
class EditorStage extends StatelessWidget {
  const EditorStage({
    super.key,
    required this.editor,
    required this.tab,
    required this.playback,
    required this.scheme,
    required this.background,
    required this.onBackgroundChanged,
    required this.documentName,
    required this.onReset,
  });

  final EditorController editor;
  final EditorTab tab;
  final SvgPlaybackController playback;

  /// The light/dark version shown (null: the file has no such versions).
  final SvgColorScheme? scheme;

  /// What the preview sits on. Only a viewing aid: never saved.
  final StageBackground background;
  final ValueChanged<StageBackground> onBackgroundChanged;
  final String documentName;
  final VoidCallback onReset;

  /// Colors compares two previews with a divider that is dragged.
  bool get showsDragLayer => tab != EditorTab.colors;

  bool get isInsertTab => tab == EditorTab.insert || tab == EditorTab.text;

  bool _selectedIsInserted() {
    final selection = editor.selection;
    return selection != null && SvgInsertEdit.isInserted(editor.svg, selection);
  }

  bool _selectedIsShape() {
    final selection = editor.selection;
    return selection != null && SvgHitTest.movables(editor.svg).any((m) => m.path == selection);
  }

  /// While the eyedropper is on, a tap on the drawing picks the color of the
  /// shape under the finger (read from the document, so it is exact).
  Widget _eyedropperLayer(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.all(16);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('eyedropper-layer'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final map = StageGeometry.of(editor.svg, constraints.biggest, padding);
                final hit = map.isUsable
                    ? SvgHitTest.at(
                        editor.svg,
                        (d.localPosition.dx - map.originX) / map.scale,
                        (d.localPosition.dy - map.originY) / map.scale,
                      )
                    : null;
                final scheme = this.scheme;
                final picked = hit == null || scheme == null
                    ? null
                    : SvgThemeEdit.fillFor(editor.svg, hit.path, scheme);
                final hex = hit == null
                    ? null
                    : scheme == null
                    ? SvgPaintEdit.sampleFill(editor.svg, hit.path)
                    : (picked != null && picked.startsWith('#') ? picked : null);
                if (hex == null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l10n.eyedropperNoColor)));
                } else {
                  editor.onColorPicked?.call(hex);
                }
              },
              child: const MouseRegion(cursor: SystemMouseCursors.precise),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      l10n.eyedropperHint,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final height = MediaQuery.sizeOf(context).height;
    final stageHeight = tab == EditorTab.code
        ? math.min(height * .22, 200.0)
        : math.min(height * .32, 320.0);
    final layer = editor.selectedLayer;
    final ticked = editor.multiMode ? editor.multiSelection.length : 0;
    final selected = editor.selection;
    final multi = ticked > 1;
    final selectedOutlinedByDrag = showsDragLayer && _selectedIsShape();
    // Shapes on the canvas among the ticked ones: outlined from the document.
    final outlined = multi
        ? movablesAmong(editor.displaySvg, editor.multiSelection)
        : const <SvgMovable>[];
    final selectedIsOutlined = outlined.any((shape) => shape.path == selected);
    final outlines = [
      for (final shape in outlined)
        if (!(selectedOutlinedByDrag && shape.path == selected)) shape,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: stageHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: tab == EditorTab.colors
                      // Colors: the original on the left, the edit on the right.
                      ? BeforeAfter(
                          beforeLabel: l10n.compareBefore,
                          afterLabel: l10n.compareAfter,
                          handleLabel: l10n.compareHandle,
                          before: SvgPreview(
                            // The original drawing in the window being edited, so both
                            // halves have the same crop and size.
                            svg: SvgDocumentEdit.copyWindow(
                              editor.initialSvg,
                              from: editor.displaySvg,
                            ),
                            scheme: scheme,
                            autoplay: false,
                            showGrid: true,
                            background: background,
                            padding: const EdgeInsets.all(16),
                            semanticLabel: l10n.compareBefore,
                          ),
                          after: SvgPreview(
                            svg: editor.displaySvg,
                            scheme: scheme,
                            controller: playback,
                            showGrid: true,
                            background: background,
                            padding: const EdgeInsets.all(16),
                            semanticLabel: l10n.previewOf(documentName),
                          ),
                        )
                      : SvgPreview(
                          svg: editor.displaySvg,
                          scheme: scheme,
                          controller: playback,
                          showGrid: true,
                          background: background,
                          padding: const EdgeInsets.all(16),
                          semanticLabel: l10n.previewOf(documentName),
                        ),
                ),
                Positioned.fill(
                  child: CanvasFrame(svg: editor.displaySvg, padding: const EdgeInsets.all(16)),
                ),
                // The drag layer draws its own outline (with handles) for the
                // selected shape. With several ticked, the other shapes get
                // an outline from the document (turning and resizing with
                // them); only what is not a shape on the canvas (a group, a
                // nested element) is outlined by the renderer's measurement.
                if (!selectedOutlinedByDrag || multi)
                  Positioned.fill(
                    child: SelectionHighlight(
                      controller: playback,
                      padding: const EdgeInsets.all(16),
                      skipSelected: selectedOutlinedByDrag || (multi && selectedIsOutlined),
                    ),
                  ),
                if (outlines.isNotEmpty)
                  Positioned.fill(
                    child: SelectionOutlines(
                      svg: editor.displaySvg,
                      shapes: outlines,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                if (tab == EditorTab.colors && editor.eyedropper)
                  Positioned.fill(child: _eyedropperLayer(context)),
                if (showsDragLayer)
                  Positioned.fill(
                    child: StageDragLayer(
                      editor: editor,
                      padding: const EdgeInsets.all(16),
                      // Insert and Text work on what they added only; the other
                      // tabs move any shape that is dragged.
                      canTouch: isInsertTab
                          ? (shape) => SvgInsertEdit.isInserted(editor.svg, shape.path)
                          : null,
                      showHandles: isInsertTab && _selectedIsInserted(),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Icon(
                  ticked > 1
                      ? Icons.checklist_rounded
                      : layer == null
                      ? Icons.select_all_rounded
                      : LayersPanel.iconFor(layer),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ticked > 1
                        ? l10n.multiSelectCount(ticked)
                        : layer == null
                        ? l10n.selectionNone
                        : l10n.selectionLayer(l10n.layerLabel(layer, editor.layers)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ListenableBuilder(
                  listenable: playback,
                  builder: (context, _) => IconButton(
                    key: const Key('stage-play'),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      fixedSize: const Size(28, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: playback.isPlaying ? l10n.pause : l10n.play,
                    // Colors starts still (see _switchTab) but can still be played.
                    onPressed: playback.toggle,
                    icon: Icon(
                      playback.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                    ),
                  ),
                ),
                PopupMenuButton<StageBackground>(
                  key: const Key('preview-bg'),
                  tooltip: l10n.previewBackground,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: const Icon(Icons.wallpaper_rounded),
                  initialValue: background,
                  onSelected: onBackgroundChanged,
                  itemBuilder: (context) => [
                    for (final option in StageBackground.values)
                      CheckedPopupMenuItem(
                        key: Key('preview-bg-${option.name}'),
                        value: option,
                        checked: option == background,
                        child: Text(l10n.backgroundName(option)),
                      ),
                  ],
                ),
                IconButton(
                  key: const Key('reset-all'),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.resetAll,
                  onPressed: editor.canReset ? onReset : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
