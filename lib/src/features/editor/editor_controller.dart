import 'package:flutter/foundation.dart';
import 'package:svg_core/svg_core.dart';

/// One undoable state of the editor.
typedef EditorSnapshot = ({String svg, ElementPath? selection});

/// State of the SVG editor: the document with undo/redo history, the
/// selected layer, a transient preview while a slider is dragged, and the
/// code editor text (which may be temporarily invalid).
class EditorController extends ChangeNotifier {
  EditorController(String initialSvg)
    : _history = EditHistory<EditorSnapshot>((svg: initialSvg, selection: null)),
      _saved = initialSvg,
      _code = initialSvg;

  final EditHistory<EditorSnapshot> _history;
  String _saved;
  String? _preview;
  String _code;
  ElementPath? _selection;
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

  void select(ElementPath? path) {
    _selection = path == _selection ? null : path;
    notifyListeners();
  }

  /// Shows [svg] on the stage without recording it (slider drags).
  void preview(String svg) {
    _preview = svg;
    notifyListeners();
  }

  /// Records [svg] as a new undoable state.
  void commit(String svg, {ElementPath? selection, bool updateSelection = false}) {
    _preview = null;
    if (updateSelection) _selection = selection;
    _history.push((svg: svg, selection: _selection));
    _replaceCode(svg);
  }

  /// Records the result of an svg_core edit, including its new selection.
  void apply(SvgEditResult result) =>
      commit(result.svg, selection: result.selection, updateSelection: true);

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
      _history.push((svg: text, selection: null));
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
    _replaceCode(snapshot.svg);
  }

  void _replaceCode(String svg) {
    _code = svg;
    _validation = const SvgValidation.valid();
    _revision++;
    notifyListeners();
  }
}
