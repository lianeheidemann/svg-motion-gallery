import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'svg_storage.dart';

SvgStorage createPlatformStorage() => PrefsSvgStorage();

/// Web preview storage on top of shared_preferences (localStorage).
class PrefsSvgStorage implements SvgStorage {
  static const _index = 'sm.index';
  static const _content = 'sm.svg.';
  static const _backup = 'sm.backup.';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<Object?>?> readIndex() async {
    final raw = (await _prefs).getString(_index);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : null;
  }

  @override
  Future<void> writeIndex(List<Object?> index) async =>
      (await _prefs).setString(_index, jsonEncode(index));

  @override
  Future<String?> readContent(String id) async => (await _prefs).getString('$_content$id');

  @override
  Future<void> writeContent(String id, String content) async =>
      (await _prefs).setString('$_content$id', content);

  @override
  Future<void> deleteContent(String id) async => (await _prefs).remove('$_content$id');

  @override
  Future<void> writeBackup(String id, String content) async =>
      (await _prefs).setString('$_backup$id.${DateTime.now().millisecondsSinceEpoch}', content);

  @override
  Future<({int library, int backups})> usage() async {
    final prefs = await _prefs;
    int sum(String prefix) => prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .fold(0, (total, key) => total + utf8Length(prefs.getString(key) ?? ''));
    return (library: sum(_content), backups: sum(_backup));
  }

  @override
  Future<void> clearBackups() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().where((key) => key.startsWith(_backup)).toList()) {
      await prefs.remove(key);
    }
  }
}
