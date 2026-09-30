import 'package:flutter/foundation.dart';

/// Metadata of an SVG file in the library. The markup itself is stored
/// separately (see `SvgStorage`) and cached by `LibraryController`.
@immutable
class SvgDocument {
  const SvgDocument({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.modifiedAt,
    this.lastOpenedAt,
    this.isFavorite = false,
    this.sourcePath,
  });

  final String id;

  /// File name shown to the user, always ending in `.svg`.
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime? lastOpenedAt;
  final bool isFavorite;

  /// Absolute path when this is a file on the phone's storage, null when the
  /// SVG lives inside the app's own library. Files on the phone are never
  /// written to the library index: they are re-discovered by scanning.
  final String? sourcePath;

  bool get isOnDevice => sourcePath != null;

  /// Folder of [sourcePath] (e.g. `/storage/emulated/0/Download`).
  String? get folder {
    final path = sourcePath;
    if (path == null) return null;
    final slash = path.lastIndexOf('/');
    return slash <= 0 ? '/' : path.substring(0, slash);
  }

  SvgDocument copyWith({
    String? name,
    int? sizeBytes,
    DateTime? modifiedAt,
    DateTime? lastOpenedAt,
    bool? isFavorite,
    String? sourcePath,
  }) => SvgDocument(
    id: id,
    name: name ?? this.name,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    sourcePath: sourcePath ?? this.sourcePath,
  );

  /// Stable, file-name-safe id for the file at [path]: two independent 32-bit
  /// FNV-1a hashes, so thousands of files do not collide in practice.
  static String deviceId(String path) {
    var a = 0x811c9dc5;
    var b = 0x01000193 ^ 0xa5a5a5a5;
    for (final unit in path.codeUnits) {
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ unit) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return 'dev-${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    'isFavorite': isFavorite,
  };

  static SvgDocument? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final modifiedAt = DateTime.tryParse('${json['modifiedAt']}');
    if (id is! String || name is! String || createdAt == null || modifiedAt == null) {
      return null;
    }
    final size = json['sizeBytes'];
    return SvgDocument(
      id: id,
      name: name,
      sizeBytes: size is int ? size : 0,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      lastOpenedAt: DateTime.tryParse('${json['lastOpenedAt']}'),
      isFavorite: json['isFavorite'] == true,
    );
  }

  /// Ensures [name] has a `.svg` extension and no path separators.
  static String normalizeName(String name) {
    var clean = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (clean.isEmpty) clean = 'untitled';
    return clean.toLowerCase().endsWith('.svg') ? clean : '$clean.svg';
  }

  @override
  bool operator ==(Object other) =>
      other is SvgDocument &&
      other.id == id &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.createdAt == createdAt &&
      other.modifiedAt == modifiedAt &&
      other.lastOpenedAt == lastOpenedAt &&
      other.isFavorite == isFavorite &&
      other.sourcePath == sourcePath;

  @override
  int get hashCode =>
      Object.hash(id, name, sizeBytes, createdAt, modifiedAt, lastOpenedAt, isFavorite, sourcePath);
}
