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
  void applyToTargets(String Function(String svg, ElementPath path) edit) {
    var next = svg;
    for (final path in targets.reversed) {
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
