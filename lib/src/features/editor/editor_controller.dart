import 'package:flutter/foundation.dart';
import 'package:svg_core/svg_core.dart';

/// One undoable state of the editor.
typedef EditorSnapshot = ({String svg, ElementPath? selection, List<ElementPath> multi});

/// State of the SVG editor: the document with undo/redo history, the
/// selected layer, a transient preview while a slider is dragged, and the
/// code editor text (which may be temporarily invalid).
class EditorController extends ChangeNotifier {
  EditorController(String initialSvg)
    : _history = EditHistory<EditorSnapshot>((svg: initialSvg, selection: null, multi: const [])),
      _initial = initialSvg,
      _saved = initialSvg,
      _code = initialSvg;

  /// The document as it was when the editor opened.
  final String _initial;
  String get initialSvg => _initial;

  final EditHistory<EditorSnapshot> _history;
  String _saved;
  String? _preview;
  String _code;
  ElementPath? _selection;
  bool _multiMode = false;

  /// Layers ticked while [multiMode] is on, in the order they were ticked.
  List<ElementPath> _multi = [];
  SvgValidation _validation = const SvgValidation.valid();
  int _revision = 0;

  /// Last committed (valid) document.
  String get svg => _history.current.svg;

  /// What the stage shows: the live preview while dragging, else [svg].
  String get displaySvg => _preview ?? svg;

  /// Text of the code editor; may differ from [svg] while it is invalid.
  String get code => _code;

  /// Bumps whenever [code] is replaced by a visual edit, undo or redo, so the
  /// code panel knows to reload its text.
  int get revision => _revision;

  ElementPath? get selection => _selection;

  bool _codePending = false;
  SvgIssue? _codeError;

  /// Whether the Code tab holds typed text that is not in [svg] yet.
  bool get codePending => _codePending;

  /// The error the Code tab found in what is typed (null when there is none),
  /// even before the text is applied.
  SvgIssue? get codeError => _codeError;

  /// Set by the Code tab while it is open: applies the typed text, if it is
  /// valid. Called before saving or leaving, so typing is never left behind.
  VoidCallback? flushCode;

  /// Reported by the Code tab, so Save can say why it cannot save yet.
  void setCodeState({required bool pending, SvgIssue? error}) {
    if (_disposed || (pending == _codePending && identical(error, _codeError))) return;
    _codePending = pending;
    _codeError = error;
    notifyListeners();
  }

  bool _eyedropper = false;

  /// Whether the next tap on the stage picks a color from the drawing.
  bool get eyedropper => _eyedropper;

  set eyedropper(bool value) {
    if (_disposed || value == _eyedropper) return;
    _eyedropper = value;
    notifyListeners();
  }

  /// Set by the Colors tab: receives the `#RRGGBB` picked from the stage.
  void Function(String hex)? onColorPicked;

  SvgValidation get validation => _validation;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  bool get hasUnsavedChanges => svg != _saved || code != svg;
  bool get canSave => _validation.isValid && svg != _saved;

  String? _metadataFor;
  SvgMetadata _metadata = SvgMetadata.empty;
  String? _layersFor;
  List<SvgLayer> _layers = const [];
  String? _paletteFor;
  List<String> _palette = const [];

  SvgMetadata get metadata {
    if (_metadataFor != svg) {
      _metadata = SvgMetadata.parse(svg);
      _metadataFor = svg;
    }
    return _metadata;
  }

  List<SvgLayer> get layers {
    if (_layersFor != svg) {
      _layers = SvgLayers.list(svg);
      _layersFor = svg;
    }
    return _layers;
  }

  List<String> get palette {
    if (_paletteFor != svg) {
      _palette = SvgColors.palette(svg);
      _paletteFor = svg;
    }
    return _palette;
  }

  /// The selected layer, or null when nothing (the whole drawing) is selected.
  SvgLayer? get selectedLayer {
    final path = _selection;
    return path == null ? null : layers.where((layer) => layer.path == path).firstOrNull;
  }

  /// Whether tapping layers ticks several of them instead of just one.
  bool get multiMode => _multiMode;

  /// The ticked layers (empty unless [multiMode]).
  List<ElementPath> get multiSelection => List.unmodifiable(_multi);

  /// The layers an edit applies to: every ticked layer in [multiMode], else
  /// the selected one. Always in document order.
  List<ElementPath> get targets {
    final paths = _multiMode ? [..._multi] : [?_selection];
    return paths..sort(_compare);
  }

  /// What an edit covers: the [targets], or every drawn layer (not the
  /// groups around them) when nothing is selected ("Todas").
  List<ElementPath> get editTargets {
    final chosen = targets;
    if (chosen.isNotEmpty) return chosen;
    return [
      for (final layer in layers)
        if (layer.tag != 'g') layer.path,
    ];
  }

  /// The shapes a paint edit covers: [editTargets] with every group replaced
  /// by the shapes inside it (a group's own fill would be hidden by the fills
  /// its children set). In document order, each shape once.
  List<ElementPath> get paintTargets {
    final out = <ElementPath>[];
    void add(ElementPath path) {
      if (!out.contains(path)) out.add(path);
    }

    for (final target in editTargets) {
      final layer = layers.where((l) => l.path == target).firstOrNull;
      if (layer == null || layer.tag != 'g') {
        add(target);
        continue;
      }
      for (final inner in layers) {
        if (inner.tag != 'g' && _isInside(inner.path, target)) add(inner.path);
      }
    }
    return out..sort(_compare);
  }

  static bool _isInside(ElementPath path, ElementPath ancestor) {
    if (path.indices.length <= ancestor.indices.length) return false;
    for (var i = 0; i < ancestor.indices.length; i++) {
      if (path.indices[i] != ancestor.indices[i]) return false;
    }
    return true;
  }

  static int _compare(ElementPath a, ElementPath b) {
    for (var i = 0; i < a.indices.length && i < b.indices.length; i++) {
      if (a.indices[i] != b.indices[i]) return a.indices[i].compareTo(b.indices[i]);
    }
    return a.indices.length.compareTo(b.indices.length);
  }

  /// Turns multi-selection on or off. Turning it on keeps the selected layer
  /// ticked; turning it off keeps the last ticked one selected.
  void setMultiMode(bool value) {
    if (value == _multiMode) return;
    _multiMode = value;
    if (value) {
      _multi = [?_selection];
    } else {
      _selection = _multi.lastOrNull;
      _multi = [];
    }
    notifyListeners();
  }

  /// Ticks every drawn layer (not the folders around them), turning
  /// multi-selection on when it is off.
  void selectAllLayers() {
    if (!_multiMode) setMultiMode(true);
    _multi = [
      for (final layer in layers)
        if (layer.tag != 'g') layer.path,
    ];
    _selection = _multi.lastOrNull;
    notifyListeners();
  }

  /// Replaces the selection with [paths] (several only in [multiMode]).
  void replaceSelection(List<ElementPath> paths) {
    if (_multiMode) {
      _multi = [...paths];
      _selection = _multi.lastOrNull;
    } else {
      _selection = paths.firstOrNull;
    }
    notifyListeners();
  }

  void select(ElementPath? path) {
    if (_multiMode) {
      if (path == null) {
        _multi = [];
      } else if (!_multi.remove(path)) {
        _multi.add(path);
      }
      _selection = _multi.lastOrNull;
    } else {
      _selection = path == _selection ? null : path;
    }
    notifyListeners();
  }

  /// Applies [edit] to every target in one undoable step, last layer first so
  /// an edit that wraps a layer never moves the path of one still to come.
  /// Only for edits that leave other layers at the same path (colors,
  /// transform, animation, visibility...).
  void applyToTargets(
    String Function(String svg, ElementPath path) edit, {
    List<ElementPath>? paths,
  }) {
    var next = svg;
    for (final path in (paths ?? targets).reversed) {
      next = edit(next, path);
    }
    if (next != svg) commit(next);
  }

  /// Deletes every target. Last first, so earlier paths stay valid.
  void removeTargets() {
    var next = svg;
    for (final path in targets.reversed) {
      next = SvgLayers.remove(next, path).svg;
    }
    commit(next, selection: null, updateSelection: true);
  }

  /// Duplicates every target. Last first, so earlier paths stay valid.
  void duplicateTargets() {
    var next = svg;
    for (final path in targets.reversed) {
      next = SvgLayers.duplicate(next, path).svg;
    }
    commit(next, selection: null, updateSelection: true);
  }

  /// Shows [svg] on the stage without recording it (slider drags).
  void preview(String svg) {
    _preview = svg;
    notifyListeners();
  }

  /// Records [svg] as a new undoable state.
  void commit(String svg, {ElementPath? selection, bool updateSelection = false}) {
    _preview = null;
    if (updateSelection) {
      _selection = selection;
      _multi = _multiMode ? [?selection] : [];
    }
    _history.push((svg: svg, selection: _selection, multi: List.of(_multi)));
    _replaceCode(svg);
  }

  /// Records the result of an svg_core edit, including its new selection.
  void apply(SvgEditResult result) =>
      commit(result.svg, selection: result.selection, updateSelection: true);

  /// Whether the document differs from how it was when the editor opened.
  bool get canReset => svg != _initial;

  /// Throws away every change made since the editor opened. It is itself an
  /// undoable step, so Undo brings the changes back.
  void resetAll() {
    if (canReset) commit(_initial, selection: null, updateSelection: true);
  }

  void undo() => _restore(_history.undo());

  void redo() => _restore(_history.redo());

  /// Called (debounced) by the code panel. Valid text becomes a new
  /// undoable state; invalid text only updates the validation status.
  void updateCode(String text) {
    if (_disposed) return;
    _code = text;
    _validation = validateSvg(text);
    if (_validation.isValid && text != svg) {
      _preview = null;
      _selection = null;
      _multi = [];
      _history.push((svg: text, selection: null, multi: const []));
    }
    notifyListeners();
  }

  /// Pretty-prints the current code (only when it is valid).
  void formatCode() {
    final formatted = formatSvg(_code);
    if (formatted != null) commit(formatted);
  }

  /// Marks the current document as saved.
  void markSaved() {
    _saved = svg;
    notifyListeners();
  }

  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _restore(EditorSnapshot snapshot) {
    _preview = null;
    _selection = snapshot.selection;
    _multi = _multiMode ? [...snapshot.multi] : [];
    if (_multiMode && _multi.isEmpty) _multi = [?_selection];
    _replaceCode(snapshot.svg);
  }

  void _replaceCode(String svg) {
    _code = svg;
    _validation = const SvgValidation.valid();
    _revision++;
    notifyListeners();
  }
}
