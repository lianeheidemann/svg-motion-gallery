import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_view/svg_view.dart';

import '../../app_scope.dart';
import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_actions_menu.dart';
import '../../widgets/svg_preview.dart';
import 'editor_controller.dart';
import 'panels/animation_panel.dart';
import 'panels/code_panel.dart';
import 'panels/colors_panel.dart';
import 'panels/insert_panel.dart';
import 'panels/layers_panel.dart';
import 'panels/transform_panel.dart';
import 'stage_drag_layer.dart';
import 'stage_geometry.dart';

enum _EditorTab { layers, transform, colors, animation, insert, code }

/// The single editor: live stage on top, one tab per kind of edit, a
/// validation/status line at the bottom and one Save button.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorController? _editor;
  SvgDocument? _document;
  final _playback = SvgPlaybackController();
  var _tab = _EditorTab.layers;
  var _saving = false;

  /// The "valid SVG" banner only shows after a save, until the next edit.
  var _justSaved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editor != null) return;
    final library = AppScope.of(context).library;
    _document = library.byId(widget.documentId);
    if (_document != null) _editor = EditorController(library.contentOf(_document!));
  }

  @override
  void dispose() {
    _editor?.dispose();
    _playback.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    final editor = _editor!;
    if (!editor.canSave || _saving) return editor.canSave;
    setState(() => _saving = true);
    final services = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _document = await services.library.save(
        _document!,
        editor.svg,
        backup: services.settings.value.autoBackup,
      );
      editor.markSaved();
      _justSaved = true;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.saved)));
      return true;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final editor = _editor!;
    if (editor.validation.isValid && editor.canSave) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.unsavedTitle),
          content: Text(l10n.unsavedMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.discard)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
          ],
        ),
      );
      if (choice == null) return;
      if (choice && !await _save()) return;
      navigator.pop();
      return;
    }
    if (!mounted) return;
    final discard = await showConfirmDialog(
      context,
      title: l10n.unsavedTitle,
      message: l10n.discardMessage,
      confirm: l10n.discard,
      destructive: true,
    );
    if (discard) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editor = _editor;
    if (editor == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.hide_image_outlined, title: l10n.fileMissing),
      );
    }
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) => PopScope(
        canPop: !editor.hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmLeave();
        },
        child: Scaffold(
          appBar: _appBar(context, editor),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stage(context, editor),
                Expanded(child: _panel(editor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: PillTabs(
                    labelSelectedOnly: true,
                    selectedIndex: _tab.index,
                    onChanged: (index) => setState(() => _tab = _EditorTab.values[index]),
                    tabs: [
                      // Always first and highlighted; another color while the
                      // whole drawing (every layer) is the target.
                      PillTab(
                        l10n.tabLayers,
                        icon: Icons.layers_outlined,
                        emphasized: true,
                        accent: editor.selection == null ? GalleryColors.of(context).success : null,
                      ),
                      PillTab(l10n.tabTransform, icon: Icons.open_with_rounded),
                      PillTab(l10n.tabColors, icon: Icons.palette_outlined),
                      PillTab(l10n.tabAnimation, icon: Icons.animation_rounded),
                      PillTab(l10n.tabInsert, icon: Icons.add_box_outlined),
                      PillTab(l10n.tabCode, icon: Icons.code_rounded),
                    ],
                  ),
                ),
                _statusBar(context, editor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editorTitle),
          Text(
            _document!.name,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: GalleryColors.of(context).muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: l10n.undo,
          onPressed: editor.canUndo ? editor.undo : null,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: l10n.redo,
          onPressed: editor.canRedo ? editor.redo : null,
          icon: const Icon(Icons.redo_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: FilledButton(
            key: const Key('save'),
            onPressed: editor.canSave && !_saving ? _save : null,
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }

  Widget _stage(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    final height = MediaQuery.sizeOf(context).height;
    final stageHeight = _tab == _EditorTab.code
        ? math.min(height * .22, 200.0)
        : math.min(height * .32, 320.0);
    final layer = editor.selectedLayer;
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
                  child: SvgPreview(
                    svg: editor.displaySvg,
                    controller: _playback,
                    showGrid: true,
                    padding: const EdgeInsets.all(16),
                    semanticLabel: l10n.previewOf(_document!.name),
                  ),
                ),
                Positioned.fill(
                  child: CanvasFrame(svg: editor.displaySvg, padding: const EdgeInsets.all(16)),
                ),
                if (_tab == _EditorTab.insert)
                  Positioned.fill(
                    child: StageDragLayer(editor: editor, padding: const EdgeInsets.all(16)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Icon(
                  layer == null ? Icons.select_all_rounded : LayersPanel.iconFor(layer),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    layer == null ? l10n.selectionNone : l10n.selectionLayer(l10n.layer(layer)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (layer != null)
                  TextButton(
                    onPressed: () => editor.select(null),
                    child: Text(l10n.clearSelection),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(EditorController editor) => switch (_tab) {
    _EditorTab.transform => TransformPanel(editor: editor),
    _EditorTab.colors => ColorsPanel(editor: editor),
    _EditorTab.animation => AnimationPanel(editor: editor, playback: _playback),
    _EditorTab.layers => LayersPanel(editor: editor),
    _EditorTab.insert => InsertPanel(editor: editor),
    _EditorTab.code => CodePanel(editor: editor),
  };

  Widget _statusBar(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    final issue = editor.validation.issue;
    final metadata = editor.metadata;
    final warning = editor.validation.warning;
    final showValid = _justSaved && !editor.hasUnsavedChanges;
    if (issue == null && warning == null && !showValid) return const SizedBox.shrink();
    if (issue == null && warning != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: StatusBanner(
          ok: false,
          warning: true,
          title: l10n.svgWarning,
          message: l10n.issueMessage(warning),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: StatusBanner(
        ok: issue == null,
        title: issue == null ? l10n.svgValid : l10n.svgInvalid,
        message: issue == null
            ? l10n.statusSummary(
                l10n.dimensions(metadata),
                l10n.elementCount(metadata.elementCount),
              )
            : l10n.issueMessage(issue),
      ),
    );
  }
}
