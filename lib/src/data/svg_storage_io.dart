import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'svg_storage.dart';

SvgStorage createPlatformStorage() => FileSvgStorage();

/// Stores each SVG as `<id>.svg` plus `index.json` in the app support
/// directory; backups go to `backups/<id>-<timestamp>.svg`.
class FileSvgStorage implements SvgStorage {
  FileSvgStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  Directory? _root;

  Future<Directory> _library() async {
    final root = _root ??= Directory('${(await _directory()).path}/library');
    if (!root.existsSync()) await root.create(recursive: true);
    return root;
  }

  Future<Directory> _backups() async {
    final dir = Directory('${(await _library()).path}/backups');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String id) async => File('${(await _library()).path}/$id.svg');

  @override
  Future<List<Object?>?> readIndex() async {
    final file = File('${(await _library()).path}/index.json');
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : null;
  }

  @override
  Future<void> writeIndex(List<Object?> index) async {
    final file = File('${(await _library()).path}/index.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(index), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<String?> readContent(String id) async {
    final file = await _file(id);
    return file.existsSync() ? file.readAsString() : null;
  }

  @override
  Future<void> writeContent(String id, String content) async =>
      (await _file(id)).writeAsString(content, flush: true);

  @override
  Future<void> deleteContent(String id) async {
    final file = await _file(id);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> writeBackup(String id, String content) async {
    final dir = await _backups();
    await File('${dir.path}/$id-${DateTime.now().millisecondsSinceEpoch}.svg')
        .writeAsString(content);
  }

  @override
  Future<({int library, int backups})> usage() async {
    int sizeOf(Directory dir, {bool recursive = false}) => dir
        .listSync(recursive: recursive)
        .whereType<File>()
        .fold(0, (sum, file) => sum + file.lengthSync());
    final library = await _library();
    final backups = await _backups();
    return (library: sizeOf(library), backups: sizeOf(backups, recursive: true));
  }

  @override
  Future<void> clearBackups() async {
    final dir = await _backups();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
