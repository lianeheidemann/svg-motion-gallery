import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    (jsonDecode(File('lib/src/l10n/app_$locale.arb').readAsStringSync()) as Map).cast();

Set<String> _placeholders(String message) =>
    RegExp(r'(?<![=\w])\{(\w+)[},]').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final pt = _arb('pt');
  final en = _arb('en');
  Iterable<String> messages(Map<String, Object?> arb) => arb.keys.where((k) => !k.startsWith('@'));

  test('Portuguese and English define exactly the same messages', () {
    expect(messages(en).toSet(), messages(pt).toSet());
  });

  test('every translation is filled in and uses the same placeholders', () {
    for (final key in messages(pt)) {
      final ptText = pt[key]! as String;
      final enText = en[key]! as String;
      expect(enText.trim(), isNotEmpty, reason: key);
      expect(_placeholders(enText), _placeholders(ptText), reason: key);
    }
  });

  test('placeholders are declared in the template', () {
    for (final key in messages(pt)) {
      final names = _placeholders(pt[key]! as String)..removeAll({'count'});
      if (names.isEmpty) continue;
      final declared = ((pt['@$key'] as Map?)?['placeholders'] as Map?)?.keys.toSet() ?? {};
      expect(declared, containsAll(names), reason: key);
    }
  });
}
