import 'dart:convert';
import 'dart:io';

import 'device_storage.dart';

/// Files above this size are ignored: they are not icons or illustrations
/// and would be slow to render.
const maxDeviceSvgBytes = 5 * 1024 * 1024;

/// Safety net against runaway scans (e.g. a folder full of symlinks).
const _maxScannedFiles = 20000;

const _headBytes = 1024;

/// Only absolute paths of `.svg` files without `..` segments are ever touched.
bool isSafeSvgPath(String path) =>
    path.startsWith('/') && path.toLowerCase().endsWith('.svg') && !path.split('/').contains('..');

/// Recursively lists valid-looking SVGs under [roots], newest first.
///
/// Skips hidden folders and files (names starting with `.`), the `Android/`
/// tree of each root (other apps' private data, unreadable anyway) and
/// symbolic links. Only the first bytes of each file are read, to confirm it
/// contains `<svg`; full validation happens when the file is opened.
List<DeviceSvgEntry> scanRoots(List<String> roots, {int maxBytes = maxDeviceSvgBytes}) {
  final found = <DeviceSvgEntry>[];
  final seen = <String>{};
  for (final root in roots) {
    final skipped = '$root/Android';
    final pending = <Directory>[Directory(root)];
    while (pending.isNotEmpty && found.length < _maxScannedFiles) {
      final dir = pending.removeLast();
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }
      for (final entity in entries) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          if (entity.path != skipped) pending.add(entity);
        } else if (entity is File && name.toLowerCase().endsWith('.svg')) {
          if (!seen.add(entity.path)) continue;
          final entry = _entryFor(entity, name, maxBytes);
          if (entry != null) found.add(entry);
        }
      }
    }
  }
  found.sort((a, b) => b.modified.compareTo(a.modified));
  return found;
}

DeviceSvgEntry? _entryFor(File file, String name, int maxBytes) {
  try {
    final stat = file.statSync();
    if (stat.size == 0 || stat.size > maxBytes) return null;
    final handle = file.openSync();
    try {
      final head = handle.readSync(_headBytes);
      if (!latin1.decode(head).toLowerCase().contains('<svg')) return null;
    } finally {
      handle.closeSync();
    }
    return DeviceSvgEntry(
      path: file.path,
      name: name,
      sizeBytes: stat.size,
      modified: stat.modified,
    );
  } on FileSystemException {
    return null;
  }
}

/// The text of an `.svg`, or null when it is missing, unsafe or too big.
String? readSvgFile(String path, {int maxBytes = maxDeviceSvgBytes}) {
  if (!isSafeSvgPath(path)) return null;
  try {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() > maxBytes) return null;
    return utf8.decode(file.readAsBytesSync(), allowMalformed: true);
  } on FileSystemException {
    return null;
  }
}

/// Overwrites an existing `.svg` without ever leaving it half-written: the
/// text goes to a temporary sibling first and then replaces the original.
bool writeSvgFile(String path, String content) {
  if (!isSafeSvgPath(path)) return false;
  final file = File(path);
  final temp = File('$path.sm-tmp');
  try {
    if (!file.existsSync()) return false;
    temp.writeAsStringSync(content, flush: true);
    temp.renameSync(path);
    return true;
  } on FileSystemException {
    try {
      if (temp.existsSync()) temp.deleteSync();
    } on FileSystemException {
      // Nothing else to clean up.
    }
    return false;
  }
}

/// Writes a new `.svg` into `[root]/[folder]`, creating the folder, and
/// returns its path. The name is [name] with `-2`, `-3`... in front of the
/// extension, the first one not taken, so nothing is ever overwritten. Null
/// when [folder] or [name] is unsafe or the file could not be saved.
String? createSvgFile(String root, String folder, String name, String content) {
  final clean = name.trim();
  bool unsafe(String part) => part.isEmpty || part.contains('/') || part.startsWith('.');
  if (unsafe(folder) || unsafe(clean) || !clean.toLowerCase().endsWith('.svg')) return null;
  final directory = Directory('$root/$folder');
  final base = clean.substring(0, clean.length - 4);
  try {
    directory.createSync(recursive: true);
    var counter = 2;
    var path = '${directory.path}/$base-$counter.svg';
    while (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
      path = '${directory.path}/$base-${++counter}.svg';
    }
    final temp = File('$path.sm-tmp');
    try {
      temp.writeAsStringSync(content, flush: true);
      temp.renameSync(path);
    } on FileSystemException {
      if (temp.existsSync()) temp.deleteSync();
      return null;
    }
    return path;
  } on FileSystemException {
    return null;
  }
}

/// Renames [path] to [newName] in the same folder; returns the new path, or
/// null if the name is invalid or already used by another file.
String? renameSvgFile(String path, String newName) {
  if (!isSafeSvgPath(path)) return null;
  final clean = newName.trim();
  if (clean.isEmpty || clean.contains('/') || clean.startsWith('.')) return null;
  if (!clean.toLowerCase().endsWith('.svg')) return null;
  final folder = path.substring(0, path.lastIndexOf('/'));
  final target = '$folder/$clean';
  try {
    final source = File(path);
    if (!source.existsSync()) return null;
    if (target == path) return path;
    if (FileSystemEntity.typeSync(target, followLinks: false) != FileSystemEntityType.notFound) {
      return null;
    }
    source.renameSync(target);
    return target;
  } on FileSystemException {
    return null;
  }
}

/// Deletes a regular `.svg` file and returns true when it is gone (also when
/// it was already gone). Directories, links and any other path are refused.
bool deleteSvgFile(String path) {
  if (!isSafeSvgPath(path)) return false;
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return true;
    if (type != FileSystemEntityType.file) return false;
    File(path).deleteSync();
    return !File(path).existsSync();
  } on FileSystemException {
    return false;
  }
}
