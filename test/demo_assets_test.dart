import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('the gallery demos are whatever .svg files assets/svgs/ holds', (tester) async {
    final files =
        Directory('assets/svgs')
            .listSync()
            .map((entity) => entity.uri.pathSegments.last)
            .where((name) => name.endsWith('.svg'))
            .toList()
          ..sort();
    final services = (await tester.runAsync(createTestServices))!;
    final names = services.library.documents.map((d) => d.name).toList();

    expect(names.toSet(), files.toSet());
    expect(names.take(2), ['butterfly.svg', 'sun-moon.svg']);
  });
}
