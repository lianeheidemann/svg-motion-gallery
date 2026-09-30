import 'package:flutter/foundation.dart';

/// Persistence of the library index and SVG markup. Implementations:
/// files on Android/iOS, shared_preferences on the web, memory in tests.
abstract interface class SvgStorage {
  /// The saved index, or null on first launch.
  Future<List<Object?>?> readIndex();
  Future<void> writeIndex(List<Object?> index);

  Future<String?> readContent(String id);
  Future<void> writeContent(String id, String content);
  Future<void> deleteContent(String id);

  /// Keeps a copy of [content] before it is overwritten.
  Future<void> writeBackup(String id, String content);

  /// Total bytes used by library files and by backups.
  Future<({int library, int backups})> usage();
  Future<void> clearBackups();
}

/// Volatile storage for tests and previews.
class MemorySvgStorage implements SvgStorage {
  List<Object?>? index;
  final contents = <String, String>{};
  final backups = <String, String>{};

  @override
  Future<List<Object?>?> readIndex() async => index;

  @override
  Future<void> writeIndex(List<Object?> index) async => this.index = List.of(index);

  @override
  Future<String?> readContent(String id) async => contents[id];

  @override
  Future<void> writeContent(String id, String content) async => contents[id] = content;

  @override
  Future<void> deleteContent(String id) async => contents.remove(id);

  @override
  Future<void> writeBackup(String id, String content) async =>
      backups['$id-${backups.length}'] = content;

  @override
  Future<({int library, int backups})> usage() async =>
      (library: _bytes(contents.values), backups: _bytes(backups.values));

  @override
  Future<void> clearBackups() async => backups.clear();

  static int _bytes(Iterable<String> values) =>
      values.fold(0, (sum, value) => sum + utf8Length(value));
}

/// UTF-8 byte length of [text] without allocating the encoded bytes.
int utf8Length(String text) {
  var length = 0;
  for (final rune in text.runes) {
    length += rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
  }
  return length;
}

/// Logs storage failures without crashing the UI.
void reportStorageError(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'svg storage'),
  );
}
