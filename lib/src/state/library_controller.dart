import 'package:flutter/foundation.dart';
import 'package:svg_core/svg_core.dart';

import '../data/svg_document.dart';
import '../data/svg_repository.dart';
import '../data/svg_storage.dart';

/// Gallery filters (chips on the home screen).
enum GalleryFilter { all, favorites, recent, adaptive }

/// A file picked for import.
typedef ImportedSvg = ({String name, String content});

/// Outcome of an import: how many files were added and which were refused.
typedef ImportReport = ({List<SvgDocument> imported, List<String> rejected});

/// Holds the library in memory (SVGs are small) and persists every change
/// through [SvgRepository]. Screens listen to it for updates.
class LibraryController extends ChangeNotifier {
  LibraryController(this._repository);

  final SvgRepository _repository;
  var _documents = <SvgDocument>[];
  final _contents = <String, String>{};
  final _metadata = <String, SvgMetadata>{};

  var _loading = true;
  var _filter = GalleryFilter.all;
  var _query = '';

  bool get isLoading => _loading;
  GalleryFilter get filter => _filter;
  String get query => _query;

  /// Every document, newest first.
  List<SvgDocument> get documents => List.unmodifiable(_documents);

  /// Documents matching the current filter and search query.
  List<SvgDocument> get visible {
    final needle = _query.trim().toLowerCase();
    var list = _documents.where(
      (doc) => needle.isEmpty || doc.name.toLowerCase().contains(needle),
    );
    switch (_filter) {
      case GalleryFilter.all:
        break;
      case GalleryFilter.favorites:
        list = list.where((doc) => doc.isFavorite);
      case GalleryFilter.adaptive:
        list = list.where(
          (doc) => metadataOf(doc).themeSupport.isAdaptive,
        );
      case GalleryFilter.recent:
        final recent = list.where((doc) => doc.lastOpenedAt != null).toList()
          ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
        return recent;
    }
    return list.toList();
  }

  SvgDocument? byId(String id) =>
      _documents.where((doc) => doc.id == id).firstOrNull;

  String contentOf(SvgDocument document) => _contents[document.id] ?? '';

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
        ..addEntries(
          loaded.map(
            (entry) => MapEntry(entry.document.id, entry.content),
          ),
        );
      _metadata.clear();
    } catch (error, stack) {
      reportStorageError(error, stack);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setFilter(GalleryFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  /// Adds valid SVG files; invalid ones are reported back by name.
  ///
  /// A device rescan can rediscover the same physical file on every launch,
  /// so an exact same-name + same-content match is skipped instead of creating
  /// duplicates.
  Future<ImportReport> importFiles(List<ImportedSvg> files) async {
    final imported = <SvgDocument>[];
    final rejected = <String>[];
    for (final file in files) {
      if (!validateSvg(file.content).isValid) {
        rejected.add(file.name);
        continue;
      }

      final normalized = SvgDocument.normalizeName(file.name);
      final alreadyPresent = _documents.any(
        (document) =>
            document.name.toLowerCase() == normalized.toLowerCase() &&
            contentOf(document) == file.content,
      );
      if (alreadyPresent) continue;

      final document = await _repository.create(
        _uniqueName(normalized),
        file.content,
      );
      _contents[document.id] = file.content;
      _documents.insert(0, document);
      imported.add(document);
    }
    if (imported.isNotEmpty) await _persist();
    return (imported: imported, rejected: rejected);
  }

  Future<void> toggleFavorite(SvgDocument document) =>
      _replace(
        document,
        (doc) => doc.copyWith(isFavorite: !doc.isFavorite),
      );

  Future<void> markOpened(SvgDocument document) =>
      _replace(
        document,
        (doc) => doc.copyWith(lastOpenedAt: _repository.now()),
      );

  Future<SvgDocument?> rename(SvgDocument document, String name) async {
    final normalized = SvgDocument.normalizeName(name);
    if (normalized == document.name) return document;
    return _replace(
      document,
      (doc) => doc.copyWith(name: _uniqueName(normalized)),
    );
  }

  Future<SvgDocument> duplicate(SvgDocument document) async {
    final content = contentOf(document);
    final copy = await _repository.create(
      _uniqueName(document.name),
      content,
    );
    _contents[copy.id] = content;
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    _documents.insert(index + 1, copy);
    await _persist();
    return copy;
  }

  Future<void> delete(SvgDocument document) async {
    _documents.removeWhere((doc) => doc.id == document.id);
    _contents.remove(document.id);
    _metadata.remove(document.id);
    await _repository.delete(document);
    await _persist();
  }

  Future<SvgDocument> save(
    SvgDocument document,
    String content, {
    bool backup = false,
  }) async {
    final current = byId(document.id) ?? document;
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
    _documents = [
      for (final entry in added) entry.document,
      ..._documents,
    ];
    notifyListeners();
  }

  Future<({int library, int backups})> usage() => _repository.usage();

  Future<void> clearBackups() => _repository.clearBackups();

  Future<SvgDocument?> _replace(
    SvgDocument document,
    SvgDocument Function(SvgDocument current) update,
  ) async {
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    if (index == -1) return null;
    final updated = update(_documents[index]);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

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
    final taken = _documents
        .map((doc) => doc.name.toLowerCase())
        .toSet();
    if (!taken.contains(normalized.toLowerCase())) return normalized;
    final base = normalized.substring(0, normalized.length - 4);
    var counter = 2;
    while (taken.contains('$base-$counter.svg'.toLowerCase())) {
      counter++;
    }
    return '$base-$counter.svg';
  }
}
