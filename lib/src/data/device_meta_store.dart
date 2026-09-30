import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app remembers about a file that lives on the phone. The file
/// itself is not stored anywhere, so favorites and "recent" are keyed by path.
@immutable
class DeviceFileMeta {
  const DeviceFileMeta({this.isFavorite = false, this.lastOpenedAt});

  final bool isFavorite;
  final DateTime? lastOpenedAt;

  Map<String, Object?> toJson() => {
    'favorite': isFavorite,
    'opened': lastOpenedAt?.toIso8601String(),
  };

  static DeviceFileMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    return DeviceFileMeta(
      isFavorite: json['favorite'] == true,
      lastOpenedAt: DateTime.tryParse('${json['opened']}'),
    );
  }
}

/// shared_preferences persistence for [DeviceFileMeta] and for the "already
/// asked for file access" flag. Failures (plugin missing in tests) degrade to
/// an in-memory session.
class DeviceMetaStore {
  const DeviceMetaStore();

  static const _metaKey = 'device.meta';
  static const _promptedKey = 'device.prompted';

  Future<Map<String, DeviceFileMeta>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_metaKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries) '${entry.key}': ?DeviceFileMeta.fromJson(entry.value),
      };
    } on MissingPluginException {
      return {};
    } on FormatException {
      return {};
    }
  }

  Future<void> save(Map<String, DeviceFileMeta> meta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _metaKey,
        jsonEncode({for (final entry in meta.entries) entry.key: entry.value.toJson()}),
      );
    } on MissingPluginException {
      // Kept in memory for this session only.
    }
  }

  Future<bool> wasPrompted() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_promptedKey) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> markPrompted() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_promptedKey, true);
    } on MissingPluginException {
      // Asked again next launch.
    }
  }
}
