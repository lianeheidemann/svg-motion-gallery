import 'dart:math';

import 'package:flutter/services.dart';

import 'svg_document.dart';
import 'svg_storage.dart';

/// Demo files bundled in `assets/svgs/` that lead the gallery, in this order
/// (the first two adapt to the light/dark theme). Any other `.svg` placed in
/// that folder is bundled too and follows them alphabetically.
const demoAssets = ['butterfly.svg', 'sun-moon.svg', 'wave.svg'];

/// A document together with its markup.
typedef LoadedSvg = ({SvgDocument document, String content});

/// Persistence rules of the library: ids, index, demos and backups.
class SvgRepository {
  SvgRepository(this._storage, {AssetBundle? bundle, DateTime Function()? clock})
    : _bundle = bundle ?? rootBundle,
      _clock = clock ?? DateTime.now;

  final SvgStorage _storage;
  final AssetBundle _bundle;
  final DateTime Function() _clock;
  final _random = Random();

  /// Loads every document; seeds the demos on first launch.
  Future<List<LoadedSvg>> loadAll() async {
    final index = await _storage.readIndex();
    if (index == null) return restoreDemos(const []);
    final result = <LoadedSvg>[];
    for (final document in index.map(SvgDocument.fromJson).whereType<SvgDocument>()) {
      final content = await _storage.readContent(document.id);
      if (content != null) result.add((document: document, content: content));
    }
    return result;
  }

  /// Adds the bundled demos (again) in front of the [existing] documents and
  /// returns only the added ones.
  Future<List<LoadedSvg>> restoreDemos(List<SvgDocument> existing) async {
    final now = _clock();
    final added = <LoadedSvg>[];
    final names = await _demoNames();
    for (var i = 0; i < names.length; i++) {
      final content = await _bundle.loadString('assets/svgs/${names[i]}');
      // Earlier demos get newer timestamps so they lead the gallery.
      final created = now.subtract(Duration(seconds: i));
      final document = SvgDocument(
        id: _newId(),
        name: names[i],
        sizeBytes: utf8Length(content),
        createdAt: created,
        modifiedAt: created,
      );
      await _storage.writeContent(document.id, content);
      added.add((document: document, content: content));
    }
    await writeIndex([...added.map((entry) => entry.document), ...existing]);
    return added;
  }

  /// The `.svg` files bundled in `assets/svgs/`: the known demos first, then
  /// whatever else the folder holds. Falls back to [demoAssets] if the asset
  /// manifest cannot be read.
  Future<List<String>> _demoNames() async {
    try {
      const folder = 'assets/svgs/';
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final found = [
        for (final asset in manifest.listAssets())
          if (asset.startsWith(folder) && asset.endsWith('.svg')) asset.substring(folder.length),
      ]..sort();
      if (found.isNotEmpty) {
        return [
          ...demoAssets.where(found.contains),
          ...found.where((name) => !demoAssets.contains(name)),
        ];
      }
    } on Object {
      // Fall through to the built-in list.
    }
    return demoAssets;
  }

  Future<void> writeIndex(List<SvgDocument> documents) =>
      _storage.writeIndex([for (final document in documents) document.toJson()]);

  /// Creates a new document from imported or duplicated markup.
  Future<SvgDocument> create(String name, String content) async {
    final now = _clock();
    final document = SvgDocument(
      id: _newId(),
      name: SvgDocument.normalizeName(name),
      sizeBytes: utf8Length(content),
      createdAt: now,
      modifiedAt: now,
    );
    await _storage.writeContent(document.id, content);
    return document;
  }

  /// Overwrites the markup, optionally keeping a backup of [previous].
  Future<SvgDocument> save(
    SvgDocument document,
    String content, {
    String? previous,
    bool backup = false,
  }) async {
    if (backup && previous != null && previous != content) {
      await _storage.writeBackup(document.id, previous);
    }
    await _storage.writeContent(document.id, content);
    return document.copyWith(sizeBytes: utf8Length(content), modifiedAt: _clock());
  }

  Future<void> delete(SvgDocument document) => _storage.deleteContent(document.id);

  /// Keeps a copy of [content] (a version about to be overwritten).
  Future<void> writeBackup(String id, String content) => _storage.writeBackup(id, content);

  Future<({int library, int backups})> usage() => _storage.usage();

  Future<void> clearBackups() => _storage.clearBackups();

  DateTime now() => _clock();

  String _newId() =>
      '${_clock().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 20).toRadixString(36)}';
}
