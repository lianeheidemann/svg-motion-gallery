import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../app_scope.dart';
import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_bar_toggles.dart';
import '../../widgets/svg_actions_menu.dart';
import '../../widgets/svg_preview.dart';
import 'before_after.dart';
import 'editor_controller.dart';
import 'panels/align_panel.dart';
import 'panels/animation_panel.dart';
import 'panels/code_panel.dart';
import 'panels/colors_panel.dart';
import 'panels/insert_panel.dart';
import 'panels/layers_panel.dart';
import 'panels/transform_panel.dart';
import 'panels/window_panel.dart';
import 'selection_highlight.dart';
import 'stage_drag_layer.dart';
import 'stage_geometry.dart';

enum _EditorTab { layers, transform, window, align, colors, animation, insert, text, code }

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
  bool get _isInsertTab => _tab == _EditorTab.insert || _tab == _EditorTab.text;
  var _saving = false;

  /// What the preview sits on. Only a viewing aid: never saved.
  var _background = StageBackground.current;

  /// Selection last sent to the renderer, which then reports where it is.
  ElementPath? _sentSelection;
  List<ElementPath> _sentAlso = const [];

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
    editor.flushCode?.call(); // typed code that works goes in first
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

  Future<void> _confirmReset(EditorController editor) async {
    final l10n = context.l10n;
    final reset = await showConfirmDialog(
      context,
      title: l10n.resetTitle,
      message: l10n.resetMessage,
      confirm: l10n.resetConfirm,
      destructive: true,
    );
    if (reset) editor.resetAll();
  }

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final editor = _editor!;
    editor.flushCode?.call();
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
      builder: (context, _) {
        _syncSelection(editor);
        return _scaffold(context, editor);
      },
    );
  }

  /// Tells the stage's renderer which element to outline. Deferred because
  /// the renderer's controller notifies listeners that are building now.
  void _syncSelection(EditorController editor) {
    final selection = editor.selection;
    // The other ticked layers (multi-selection) are outlined too.
    final also = [
      if (editor.multiMode)
        for (final path in editor.multiSelection)
          if (path != selection) path,
    ];
    if (selection == _sentSelection && listEquals(also, _sentAlso)) return;
    _sentSelection = selection;
    _sentAlso = also;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playback.selectElement(selection?.indices, also: [for (final path in also) path.indices]);
      }
    });
  }

  Widget _scaffold(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !(editor.hasUnsavedChanges || editor.codePending),
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
                    PillTab(l10n.tabWindow, icon: Icons.crop_rounded),
                    PillTab(l10n.tabAlign, icon: Icons.align_horizontal_center_rounded),
                    PillTab(l10n.tabColors, icon: Icons.palette_outlined),
                    PillTab(l10n.tabAnimation, icon: Icons.animation_rounded),
                    PillTab(l10n.tabInsert, icon: Icons.add_box_outlined),
                    PillTab(l10n.tabText, icon: Icons.text_fields_rounded),
                    PillTab(l10n.tabCode, icon: Icons.code_rounded),
                  ],
                ),
              ),
              _statusBar(context, editor),
            ],
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
        // Always reachable while editing, whatever the tab.
        const ThemeToggleButton(),
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
          child: _saveButton(context, editor),
        ),
      ],
    );
  }

  /// Save. When it cannot save because of the code (an error, or typed text
  /// that was not applied), it looks off but a tap says why, instead of doing
  /// nothing.
  Widget _saveButton(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    // Typed code that works is applied by Save itself; broken code is not.
    final liveError = editor.codeError;
    final typedOk = editor.codePending && liveError == null;
    final canSave = !_saving && liveError == null && (typedOk || editor.canSave);
    final blocked = !_saving && !canSave && (liveError ?? editor.validation.issue) != null;
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      key: const Key('save'),
      onPressed: canSave ? _save : (blocked ? () => _explainBlockedSave(editor) : null),
      style: blocked
          ? FilledButton.styleFrom(
              backgroundColor: scheme.onSurface.withValues(alpha: .12),
              foregroundColor: scheme.onSurface.withValues(alpha: .38),
            )
          : null,
      child: Text(l10n.save),
    );
  }

  void _explainBlockedSave(EditorController editor) {
    final l10n = context.l10n;
    final error = editor.codeError ?? editor.validation.issue;
    if (error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.saveBlockedError(l10n.issueMessage(error)))));
  }

  bool _selectedIsShape(EditorController editor) {
    final selection = editor.selection;
    return selection != null && SvgHitTest.movables(editor.svg).any((m) => m.path == selection);
  }

  Widget _stage(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    final height = MediaQuery.sizeOf(context).height;
    final stageHeight = _tab == _EditorTab.code
        ? math.min(height * .22, 200.0)
        : math.min(height * .32, 320.0);
    final layer = editor.selectedLayer;
    final ticked = editor.multiMode ? editor.multiSelection.length : 0;
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
                  child: _tab == _EditorTab.colors
                      // Colors: the original on the left, the edit on the right.
                      ? BeforeAfter(
                          beforeLabel: l10n.compareBefore,
                          afterLabel: l10n.compareAfter,
                          handleLabel: l10n.compareHandle,
                          before: SvgPreview(
                            svg: editor.initialSvg,
                            showGrid: true,
                            background: _background,
                            padding: const EdgeInsets.all(16),
                            semanticLabel: l10n.compareBefore,
                          ),
                          after: SvgPreview(
                            svg: editor.displaySvg,
                            controller: _playback,
                            showGrid: true,
                            background: _background,
                            padding: const EdgeInsets.all(16),
                            semanticLabel: l10n.previewOf(_document!.name),
                          ),
                        )
                      : SvgPreview(
                          svg: editor.displaySvg,
                          controller: _playback,
                          showGrid: true,
                          background: _background,
                          padding: const EdgeInsets.all(16),
                          semanticLabel: l10n.previewOf(_document!.name),
                        ),
                ),
                Positioned.fill(
                  child: CanvasFrame(svg: editor.displaySvg, padding: const EdgeInsets.all(16)),
                ),
                // The Insert tab draws its own outline (with handles) for shapes.
                if (!(_isInsertTab && _selectedIsShape(editor)))
                  Positioned.fill(
                    child: SelectionHighlight(
                      controller: _playback,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                if (_isInsertTab)
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
                  ticked > 1
                      ? Icons.checklist_rounded
                      : layer == null
                      ? Icons.select_all_rounded
                      : LayersPanel.iconFor(layer),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
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
                if (layer != null)
                  TextButton(
                    onPressed: () => editor.select(null),
                    child: Text(l10n.clearSelection),
                  ),
                PopupMenuButton<StageBackground>(
                  key: const Key('preview-bg'),
                  tooltip: l10n.previewBackground,
                  icon: const Icon(Icons.wallpaper_rounded),
                  initialValue: _background,
                  onSelected: (value) => setState(() => _background = value),
                  itemBuilder: (context) => [
                    for (final option in StageBackground.values)
                      CheckedPopupMenuItem(
                        key: Key('preview-bg-${option.name}'),
                        value: option,
                        checked: option == _background,
                        child: Text(l10n.backgroundName(option)),
                      ),
                  ],
                ),
                IconButton(
                  key: const Key('reset-all'),
                  tooltip: l10n.resetAll,
                  onPressed: editor.canReset ? () => _confirmReset(editor) : null,
                  icon: const Icon(Icons.restart_alt_rounded),
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
    _EditorTab.window => WindowPanel(editor: editor, playback: _playback),
    _EditorTab.align => AlignPanel(editor: editor, playback: _playback),
    _EditorTab.colors => ColorsPanel(editor: editor),
    _EditorTab.animation => AnimationPanel(editor: editor, playback: _playback),
    _EditorTab.layers => LayersPanel(editor: editor),
    _EditorTab.insert => InsertPanel(editor: editor),
    _EditorTab.text => InsertPanel(key: const Key('text-panel'), editor: editor, text: true),
    _EditorTab.code => CodePanel(editor: editor),
  };

  Widget _statusBar(BuildContext context, EditorController editor) {
    final l10n = context.l10n;
    final issue = editor.validation.issue;
    final metadata = editor.metadata;
    final warning = editor.validation.warning;
    // Typed code that is waiting, or broken, makes "valid" untrue: the Code
    // tab says what is going on.
    final showValid =
        _justSaved && !editor.hasUnsavedChanges && !editor.codePending && editor.codeError == null;
    if (issue == null && warning == null && !showValid) return const SizedBox.shrink();
    // The Code tab says what is wrong right under the code, with a button to
    // go there; saying it again down here would only repeat it.
    if (_tab == _EditorTab.code && (issue != null || warning != null)) {
      return const SizedBox.shrink();
    }
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
