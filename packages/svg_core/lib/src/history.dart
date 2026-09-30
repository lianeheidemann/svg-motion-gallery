/// Linear undo/redo history with a size limit.
class EditHistory<T> {
  EditHistory(T initial, {this.limit = 100}) : _entries = [initial];

  final int limit;
  final List<T> _entries;
  var _index = 0;

  T get current => _entries[_index];
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _entries.length - 1;

  /// Records [value] as the newest state, dropping anything that was undone.
  /// Pushing a value equal to [current] is ignored.
  void push(T value) {
    if (value == current) return;
    _entries
      ..removeRange(_index + 1, _entries.length)
      ..add(value);
    if (_entries.length > limit) _entries.removeAt(0);
    _index = _entries.length - 1;
  }

  T undo() {
    if (canUndo) _index--;
    return current;
  }

  T redo() {
    if (canRedo) _index++;
    return current;
  }

  /// Forgets all history and starts again from [value].
  void reset(T value) {
    _entries
      ..clear()
      ..add(value);
    _index = 0;
  }
}
