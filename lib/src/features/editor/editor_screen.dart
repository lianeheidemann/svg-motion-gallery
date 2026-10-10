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
import 'editor_controller.dart';
import 'editor_stage.dart';
import 'editor_status_bar.dart';
import 'editor_tabs.dart';
import 'panels/align_panel.dart';
import 'panels/animation_panel.dart';
import 'panels/code_panel.dart';
import 'panels/colors_panel.dart';
import 'panels/insert_panel.dart';
import 'panels/layers_panel.dart';
import 'panels/transform_panel.dart';
import 'panels/window_panel.dart';
import 'selection_outlines.dart';

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

  /// The variant (light/dark) being edited; chosen with the Layers tab icon.
  /// Null until the first read, which takes the app's theme once.
  SvgColorScheme? _variant;

  /// The variant being viewed and edited, or null when the file has no
  /// light/dark versions in its code.
  SvgColorScheme? _editScheme(BuildContext context, EditorController editor) {
    if (!SvgThemeEdit.canEdit(editor.svg)) return null;
    // The version is fixed when editing starts (the app's theme then); the
    // theme button in the bar changes the app, not the version being edited.
    return _variant ??= schemeOf(context);
  }

  /// Switches between the light and the dark version. What is selected moves
  /// to its twin in the other version (the "night" group to the "day" one),
  /// since the selected one may not be drawn there.
  void _toggleVariant(BuildContext context, EditorController editor) {
    final from = _editScheme(context, editor);
    if (from == null) return;
    final to = from.opposite;
    final chosen = editor.multiMode ? editor.multiSelection : [?editor.selection];
    final mapped = [
      for (final path in chosen) SvgThemeEdit.counterpart(editor.svg, path, from, to),
    ];
    setState(() => _variant = to);
    if (chosen.isNotEmpty) editor.replaceSelection(mapped);
  }

  /// Whether the stage was playing before the Colors tab froze it.
  var _resumeAfterColors = false;
  var _tab = EditorTab.layers;

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
    // Shapes on the canvas are outlined from the document (SelectionOutlines),
    // so the renderer only measures the other ones.
    final others = [
      if (editor.multiMode)
        for (final path in editor.multiSelection)
          if (path != selection) path,
    ];
    final drawn = movablesAmong(editor.svg, others).map((shape) => shape.path).toList();
    final also = [
      for (final path in others)
        if (!drawn.contains(path)) path,
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
              EditorStage(
                editor: editor,
                tab: _tab,
                playback: _playback,
                scheme: _editScheme(context, editor),
                background: _background,
                onBackgroundChanged: (value) => setState(() => _background = value),
                documentName: _document!.name,
                onReset: () => _confirmReset(editor),
              ),
              Expanded(child: _panel(editor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: EditorTabBar(
                  editor: editor,
                  tab: _tab,
                  onChanged: (tab) => setState(() => _switchTab(tab)),
                ),
              ),
              EditorStatusBar(editor: editor, tab: _tab, justSaved: _justSaved),
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

  /// Switches tab. Colors compares two previews, so both sit still at the
  /// start (two live animations would never show the same frame); the play
  /// button still works there.
  void _switchTab(EditorTab next) {
    final was = _tab;
    _tab = next;
    if (was == next) return;
    if (was == EditorTab.colors) _editor?.eyedropper = false;
    if (next == EditorTab.colors) {
      _resumeAfterColors = _playback.isPlaying;
      _playback
        ..pause()
        ..seekFraction(0);
    } else if (was == EditorTab.colors && _resumeAfterColors) {
      _resumeAfterColors = false;
      _playback.play();
    }
  }

  Widget _panel(EditorController editor) => switch (_tab) {
    EditorTab.transform => TransformPanel(editor: editor),
    EditorTab.window => WindowPanel(editor: editor, playback: _playback),
    EditorTab.align => AlignPanel(editor: editor, playback: _playback),
    EditorTab.colors => ColorsPanel(editor: editor, scheme: _editScheme(context, editor)),
    EditorTab.animation => AnimationPanel(editor: editor, playback: _playback),
    EditorTab.layers => LayersPanel(
      editor: editor,
      themeScheme: _editScheme(context, editor),
      onToggleTheme: () => _toggleVariant(context, editor),
    ),
    EditorTab.insert => InsertPanel(editor: editor),
    EditorTab.text => InsertPanel(key: const Key('text-panel'), editor: editor, text: true),
    EditorTab.code => CodePanel(editor: editor),
  };
}
