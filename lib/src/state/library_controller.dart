import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:svg_core/svg_core.dart';

import '../data/device_meta_store.dart';
import '../data/svg_document.dart';
import '../data/svg_repository.dart';
import '../data/svg_storage.dart';
import '../services/device_storage.dart';
import 'gallery_filter.dart';

export 'gallery_filter.dart';

/// A file picked for import.
typedef ImportedSvg = ({String name, String content});

/// Outcome of an import: how many files were added and which were refused.
typedef ImportReport = ({List<SvgDocument> imported, List<String> rejected});

/// Outcome of deleting several documents at once.
typedef DeleteReport = ({int deleted, int failed});

/// Holds the gallery in memory and persists every change.
///
/// Two kinds of documents live side by side:
/// * **library** documents (imported files and the demos) whose markup and
///   index are saved through [SvgRepository];
/// * **device** documents: `.svg` files found on the phone's storage through
///   [DeviceStorage]. They are never written to the library index (the file
///   itself is the source of truth), their markup is read on demand, and
///   editing or deleting them changes the real file.
class LibraryController extends ChangeNotifier {
  LibraryController(
    this._repository, {
    DeviceStorage? device,
    DeviceMetaStore deviceMeta = const DeviceMetaStore(),
  }) : _device = device ?? const UnsupportedDeviceStorage(),
       _metaStore = deviceMeta {
    _access = _device.isSupported ? DeviceAccess.unknown : DeviceAccess.unsupported;
  }

  final SvgRepository _repository;
  final DeviceStorage _device;
  final DeviceMetaStore _metaStore;

  var _documents = <SvgDocument>[];
  var _deviceDocs = <SvgDocument>[];
  final _contents = <String, String>{};
  final _metadata = <String, SvgMetadata>{};
  final _loadingContent = <String>{};

  /// Phone files that could not be read; retried after the next rescan.
  final _unreadable = <String>{};

  /// Files that turned out not to be valid SVGs, by path and modification
  /// time, so rescans do not list them again.
  final _invalid = <String, DateTime>{};
  Map<String, DeviceFileMeta>? _deviceMeta;
  Map<String, SvgDocument>? _byIdCache;

  var _loading = true;
  var _filter = GalleryFilter.all;
  var _query = '';
  late DeviceAccess _access;
  var _refreshing = false;
  var _scanning = false;
  Future<void>? _bulkLoad;

  bool get isLoading => _loading;
  GalleryFilter get filter => _filter;
  String get query => _query;

  /// Whether this platform can list files on the phone at all.
  bool get supportsDevice => _device.isSupported;
  DeviceAccess get deviceAccess => _access;

  /// True while the phone's storage is being scanned.
  bool get isScanningDevice => _scanning;

  /// Every document: the library first, then the phone's files (newest first).
  List<SvgDocument> get documents => List.unmodifiable([..._documents, ..._deviceDocs]);

  /// Documents matching the current filter and search query.
  List<SvgDocument> get visible {
    final needle = _query.trim().toLowerCase();
    // "All" puts a phone file that is newer than a library document before it,
    // so a file just downloaded shows at the top instead of after every demo.
    var list = (_filter == GalleryFilter.all ? _newestFirst() : documents).where(
      (doc) => needle.isEmpty || doc.name.toLowerCase().contains(needle),
    );
    switch (_filter) {
      case GalleryFilter.all:
        break;
      case GalleryFilter.favorites:
        list = list.where((doc) => doc.isFavorite);
      case GalleryFilter.adaptive:
        list = list.where((doc) => metadataOf(doc).themeSupport.isAdaptive);
      case GalleryFilter.device:
        list = list.where((doc) => doc.isOnDevice);
      case GalleryFilter.recent:
        final recent = list.where((doc) => doc.lastOpenedAt != null).toList()
          ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
        return recent;
    }
    return list.toList();
  }

  /// The library in its own order with the phone's files (newest first) woven
  /// in: each one goes ahead of the first library document it is newer than.
  /// The library's order is kept, so the demos do not shuffle.
  List<SvgDocument> _newestFirst() {
    final phone = [..._deviceDocs]..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final out = <SvgDocument>[];
    var next = 0;
    for (final doc in _documents) {
      while (next < phone.length && phone[next].modifiedAt.isAfter(doc.modifiedAt)) {
        out.add(phone[next++]);
      }
      out.add(doc);
    }
    return [...out, ...phone.skip(next)];
  }

  SvgDocument? byId(String id) {
    final cache = _byIdCache ??= {
      for (final doc in _documents) doc.id: doc,
      for (final doc in _deviceDocs) doc.id: doc,
    };
    return cache[id];
  }

  @override
  void notifyListeners() {
    _byIdCache = null;
    super.notifyListeners();
  }

  String contentOf(SvgDocument document) => _contents[document.id] ?? '';

  /// False only for a phone file whose markup has not been read yet.
  bool hasContent(SvgDocument document) =>
      !document.isOnDevice || _contents.containsKey(document.id);

  /// True for a phone file that could not be read (deleted meanwhile, no
  /// permission...). Screens show a broken-image placeholder for it.
  bool isUnreadable(SvgDocument document) => _unreadable.contains(document.id);

  SvgMetadata metadataOf(SvgDocument document) =>
      _metadata[document.id] ??= SvgMetadata.parse(contentOf(document));

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final loaded = await _repository.loadAll();
      _documents = [for (final entry in loaded) entry.document];
      _contents
        ..clear()
        ..addEntries(loaded.map((entry) => MapEntry(entry.document.id, entry.content)));
      _metadata.clear();
      _deviceDocs = [];
    } catch (error, stack) {
      reportStorageError(error, stack);
    } finally {
      _loading = false;
      notifyListeners();
    }
    await refreshDevice();
  }

  void setFilter(GalleryFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
    // "Light/Dark" needs the markup of every phone file to decide.
    if (filter == GalleryFilter.adaptive) unawaited(loadAllDeviceContent());
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  // ---------------------------------------------------------------- phone

  /// Whether the "Show your SVGs" dialog should be shown (once, ever).
  Future<bool> shouldPromptForDevice() async =>
      _device.isSupported && !await _metaStore.wasPrompted();

  Future<void> markDevicePrompted() => _metaStore.markPrompted();

  /// Sends the user to the system screen that allows file access.
  Future<void> requestDeviceAccess() => _device.requestAccess();

  /// Checks the permission and, when granted, rescans the phone's storage.
  Future<void> refreshDevice() async {
    if (!_device.isSupported) {
      _access = DeviceAccess.unsupported;
      return;
    }
    if (_refreshing) return;
    _refreshing = true;
    try {
      final granted = await _device.hasAccess();
      _access = granted ? DeviceAccess.granted : DeviceAccess.denied;
      if (!granted) {
        _clearDeviceDocuments();
        notifyListeners();
        return;
      }
      _scanning = true;
      notifyListeners();
      _deviceMeta ??= await _metaStore.load();
      _applyScan(await _device.scan());
    } catch (error, stack) {
      reportStorageError(error, stack);
    } finally {
      _refreshing = false;
      _scanning = false;
      notifyListeners();
    }
  }

  void _clearDeviceDocuments() {
    for (final doc in _deviceDocs) {
      _contents.remove(doc.id);
      _metadata.remove(doc.id);
    }
    _deviceDocs = [];
  }

  void _applyScan(List<DeviceSvgEntry> entries) {
    final meta = _deviceMeta ?? const <String, DeviceFileMeta>{};
    final previous = {for (final doc in _deviceDocs) doc.sourcePath!: doc};
    _unreadable.clear();
    final next = <SvgDocument>[];
    final keep = <String>{};
    for (final entry in entries) {
      if (_invalid[entry.path] == entry.modified) continue;
      final old = previous[entry.path];
      final id = old?.id ?? SvgDocument.deviceId(entry.path);
      final unchanged =
          old != null && old.sizeBytes == entry.sizeBytes && old.modifiedAt == entry.modified;
      if (!unchanged) {
        _contents.remove(id);
        _metadata.remove(id);
      }
      final saved = meta[entry.path];
      next.add(
        SvgDocument(
          id: id,
          name: entry.name,
          sizeBytes: entry.sizeBytes,
          createdAt: old?.createdAt ?? entry.modified,
          modifiedAt: entry.modified,
          lastOpenedAt: saved?.lastOpenedAt,
          isFavorite: saved?.isFavorite ?? false,
          sourcePath: entry.path,
        ),
      );
      keep.add(id);
    }
    for (final doc in _deviceDocs) {
      if (keep.contains(doc.id)) continue;
      _contents.remove(doc.id);
      _metadata.remove(doc.id);
    }
    _deviceDocs = next;
    _byIdCache = null;
  }

  /// Reads the markup of a phone file (a no-op for library documents and
  /// files already read). Files that are not valid SVGs disappear from the
  /// list, as the scan only peeks at the first bytes.
  Future<void> ensureContent(SvgDocument document, {bool notify = true}) async {
    if (!document.isOnDevice || _contents.containsKey(document.id)) return;
    if (_unreadable.contains(document.id) || !_loadingContent.add(document.id)) return;
    try {
      final text = await _device.read(document.sourcePath!);
      if (text == null) {
        _unreadable.add(document.id);
      } else if (validateSvg(text).isValid) {
        _contents[document.id] = text;
        _metadata.remove(document.id);
      } else {
        _invalid[document.sourcePath!] = document.modifiedAt;
        _deviceDocs = [
          for (final doc in _deviceDocs)
            if (doc.id != document.id) doc,
        ];
      }
    } finally {
      _loadingContent.remove(document.id);
      if (notify) notifyListeners();
    }
  }

  /// Reads every phone file that is still unread, notifying in batches so
  /// the grid fills in without a rebuild per file.
  /// Calls made while a load is running share it.
  Future<void> loadAllDeviceContent() => _bulkLoad ??= _loadAllContent().whenComplete(() {
    _bulkLoad = null;
  });

  Future<void> _loadAllContent() async {
    try {
      var count = 0;
      for (final doc in List.of(_deviceDocs)) {
        if (_contents.containsKey(doc.id)) continue;
        await ensureContent(doc, notify: false);
        if (++count % 25 == 0) notifyListeners();
      }
    } finally {
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- library

  /// Adds valid SVG files; invalid ones are reported back by name.
  Future<ImportReport> importFiles(List<ImportedSvg> files) async {
    final imported = <SvgDocument>[];
    final rejected = <String>[];
    for (final file in files) {
      if (!validateSvg(file.content).isValid) {
        rejected.add(file.name);
        continue;
      }
      final document = await _repository.create(_uniqueName(file.name), file.content);
      _contents[document.id] = file.content;
      _documents.insert(0, document);
      imported.add(document);
    }
    if (imported.isNotEmpty) await _persist();
    return (imported: imported, rejected: rejected);
  }

  Future<void> toggleFavorite(SvgDocument document) =>
      _replace(document, (doc) => doc.copyWith(isFavorite: !doc.isFavorite));

  Future<void> markOpened(SvgDocument document) =>
      _replace(document, (doc) => doc.copyWith(lastOpenedAt: _repository.now()));

  /// Renames the document; for a phone file this renames the real file.
  /// Returns null when a phone file could not be renamed (name taken).
  Future<SvgDocument?> rename(SvgDocument document, String name) async {
    final normalized = SvgDocument.normalizeName(name);
    if (normalized == document.name) return document;
    if (document.isOnDevice) {
      final oldPath = document.sourcePath!;
      final newPath = await _device.rename(oldPath, normalized);
      if (newPath == null) return null;
      final moved = _deviceMeta?.remove(oldPath);
      if (moved != null) _deviceMeta![newPath] = moved;
      return _replace(document, (doc) => doc.copyWith(name: normalized, sourcePath: newPath));
    }
    return _replace(document, (doc) => doc.copyWith(name: _uniqueName(normalized)));
  }

  /// Copies the markup into a new library document, next to the original. A
  /// phone file is copied into the library too (the file on the phone is left
  /// alone) and the copy goes to the top of it. Null when the phone file could
  /// not be read.
  Future<SvgDocument?> duplicate(SvgDocument document) async {
    // A phone file's markup is read on demand.
    await ensureContent(document);
    if (!hasContent(document) || isUnreadable(document)) return null;
    final content = contentOf(document);
    final copy = await _repository.create(_uniqueName(document.name), content);
    _contents[copy.id] = content;
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    _documents.insert(index == -1 ? 0 : index + 1, copy);
    await _persist();
    return copy;
  }

  /// Deletes the document: a library document leaves the gallery, a phone
  /// file is **permanently deleted from the phone**. Returns false when a
  /// phone file could not be deleted.
  Future<bool> delete(SvgDocument document) async {
    final done = await _deleteOne(document);
    if (done) {
      await _saveDeviceMeta();
      await _persist();
    }
    return done;
  }

  /// Deletes several documents; failures do not stop the others.
  Future<DeleteReport> deleteMany(Iterable<SvgDocument> documents) async {
    var deleted = 0;
    var failed = 0;
    for (final document in documents.toList()) {
      if (await _deleteOne(document)) {
        deleted++;
      } else {
        failed++;
      }
    }
    if (deleted > 0) {
      await _saveDeviceMeta();
      await _persist();
    }
    return (deleted: deleted, failed: failed);
  }

  Future<bool> _deleteOne(SvgDocument document) async {
    if (document.isOnDevice) {
      final path = document.sourcePath!;
      if (!await _device.delete(path)) return false;
      _deviceDocs = [
        for (final doc in _deviceDocs)
          if (doc.id != document.id) doc,
      ];
      _deviceMeta?.remove(path);
    } else {
      _documents.removeWhere((doc) => doc.id == document.id);
      await _repository.delete(document);
    }
    _byIdCache = null;
    _contents.remove(document.id);
    _metadata.remove(document.id);
    return true;
  }

  /// Saves edited markup (keeping a backup of the previous version when
  /// [backup] is true) and returns the updated document. For a phone file
  /// this overwrites the original; it throws if the file cannot be written.
  Future<SvgDocument> save(SvgDocument document, String content, {bool backup = false}) async {
    final current = byId(document.id) ?? document;
    if (current.isOnDevice) {
      final previous = _contents[current.id];
      if (backup && previous != null && previous != content) {
        await _repository.writeBackup(current.id, previous);
      }
      if (!await _device.write(current.sourcePath!, content)) {
        throw StateError('Could not write ${current.name}');
      }
      final updated = current.copyWith(
        sizeBytes: utf8Length(content),
        modifiedAt: _repository.now(),
      );
      _contents[current.id] = content;
      _metadata.remove(current.id);
      await _replace(current, (_) => updated);
      return updated;
    }
    final updated = await _repository.save(
      current,
      content,
      previous: _contents[document.id],
      backup: backup,
    );
    _contents[document.id] = content;
    _metadata.remove(document.id);
    await _replace(current, (_) => updated);
    return updated;
  }

  Future<void> restoreDemos() async {
    final added = await _repository.restoreDemos(_documents);
    for (final entry in added) {
      _contents[entry.document.id] = entry.content;
    }
    _documents = [for (final entry in added) entry.document, ..._documents];
    notifyListeners();
  }

  Future<({int library, int backups})> usage() => _repository.usage();

  Future<void> clearBackups() => _repository.clearBackups();

  Future<SvgDocument?> _replace(
    SvgDocument document,
    SvgDocument Function(SvgDocument current) update,
  ) async {
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    if (index != -1) {
      final updated = update(_documents[index]);
      _documents[index] = updated;
      await _persist();
      return updated;
    }
    final deviceIndex = _deviceDocs.indexWhere((doc) => doc.id == document.id);
    if (deviceIndex == -1) return null;
    final updated = update(_deviceDocs[deviceIndex]);
    _deviceDocs = [..._deviceDocs]..[deviceIndex] = updated;
    final meta = _deviceMeta ??= {};
    if (updated.isFavorite || updated.lastOpenedAt != null) {
      meta[updated.sourcePath!] = DeviceFileMeta(
        isFavorite: updated.isFavorite,
        lastOpenedAt: updated.lastOpenedAt,
      );
    } else {
      meta.remove(updated.sourcePath);
    }
    notifyListeners();
    await _saveDeviceMeta();
    return updated;
  }

  Future<void> _saveDeviceMeta() async {
    final meta = _deviceMeta;
    if (meta == null) return;
    try {
      await _metaStore.save(meta);
    } catch (error, stack) {
      reportStorageError(error, stack);
    }
  }

  /// Writes the library index. Phone files are not part of it.
  Future<void> _persist() async {
    notifyListeners();
    try {
      await _repository.writeIndex(_documents);
    } catch (error, stack) {
      reportStorageError(error, stack);
    }
  }

  /// [name] or `name-2.svg`, `name-3.svg`... when already taken.
  String _uniqueName(String name) {
    final normalized = SvgDocument.normalizeName(name);
    final taken = _documents.map((doc) => doc.name.toLowerCase()).toSet();
    if (!taken.contains(normalized.toLowerCase())) return normalized;
    final base = normalized.substring(0, normalized.length - 4);
    var counter = 2;
    while (taken.contains('$base-$counter.svg'.toLowerCase())) {
      counter++;
    }
    return '$base-$counter.svg';
  }
}
