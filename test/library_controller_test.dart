import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/data/svg_repository.dart';
import 'package:svg_motion_gallery/src/data/svg_storage.dart';
import 'package:svg_motion_gallery/src/state/library_controller.dart';

import 'helpers.dart';

const _valid =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySvgStorage storage;
  late LibraryController library;

  setUp(() async {
    storage = MemorySvgStorage();
    library = LibraryController(SvgRepository(storage));
    await library.load();
  });

  test('seeds the bundled demos on first launch, in order', () {
    expect(library.documents.map((d) => d.name), bundledDemos());
    expect(storage.contents, hasLength(bundledDemos().length));
  });

  test('filters adaptive, favorite and recent documents and searches by name', () async {
    library.setFilter(GalleryFilter.adaptive);
    expect(library.visible.map((d) => d.name), ['butterfly.svg', 'sun-moon.svg']);

    library.setFilter(GalleryFilter.favorites);
    expect(library.visible, isEmpty);
    await library.toggleFavorite(library.documents[2]);
    expect(library.visible.single.name, 'wave.svg');

    library.setFilter(GalleryFilter.recent);
    await library.markOpened(library.documents[1]);
    await library.markOpened(library.documents[2]);
    expect(library.visible.map((d) => d.name), ['wave.svg', 'sun-moon.svg']);

    library
      ..setFilter(GalleryFilter.all)
      ..setQuery('WAVE.S');
    expect(library.visible.single.name, 'wave.svg');
  });

  test('imports valid files with unique names and reports invalid ones', () async {
    final report = await library.importFiles([
      (name: 'wave.svg', content: _valid),
      (name: 'broken.svg', content: '<svg><g></svg>'),
      (name: 'logo', content: _valid),
    ]);
    expect(report.rejected, ['broken.svg']);
    expect(report.imported.map((d) => d.name), ['wave-2.svg', 'logo.svg']);
    expect(library.documents.first.name, 'logo.svg');
  });

  test('renames, duplicates and deletes', () async {
    final wave = library.documents.firstWhere((d) => d.name == 'wave.svg');
    final renamed = await library.rename(wave, 'ocean');
    expect(renamed!.name, 'ocean.svg');

    final copy = await library.duplicate(renamed);
    expect(copy.name, 'ocean-2.svg');
    expect(library.contentOf(copy), library.contentOf(renamed));

    await library.delete(copy);
    expect(library.byId(copy.id), isNull);
    expect(storage.contents.containsKey(copy.id), isFalse);
  });

  test('saves edits, keeps a backup and persists across restarts', () async {
    final leaf = library.documents.firstWhere((d) => d.name == 'sun-moon.svg');
    final saved = await library.save(leaf, _valid, backup: true);
    expect(saved.sizeBytes, _valid.length);
    expect(storage.backups, hasLength(1));
    expect(library.metadataOf(saved).themeSupport.isAdaptive, isFalse);

    final reopened = LibraryController(SvgRepository(storage));
    await reopened.load();
    expect(reopened.documents.map((d) => d.name), library.documents.map((d) => d.name));
    expect(reopened.contentOf(reopened.byId(leaf.id)!), _valid);

    final usage = await reopened.usage();
    expect(usage.backups, greaterThan(0));
    await reopened.clearBackups();
    expect((await reopened.usage()).backups, 0);
  });

  test('restores the demos next to existing files', () async {
    await library.importFiles([(name: 'mine.svg', content: _valid)]);
    await library.restoreDemos();
    expect(library.documents, hasLength(bundledDemos().length * 2 + 1));
    expect(library.documents.where((d) => d.name == 'mine.svg'), hasLength(1));
  });
}
