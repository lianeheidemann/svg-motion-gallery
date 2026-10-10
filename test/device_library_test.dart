import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svg_motion_gallery/src/data/svg_document.dart';
import 'package:svg_motion_gallery/src/data/svg_repository.dart';
import 'package:svg_motion_gallery/src/data/svg_storage.dart';
import 'package:svg_motion_gallery/src/services/device_storage.dart';
import 'package:svg_motion_gallery/src/services/device_storage_memory.dart';
import 'package:svg_motion_gallery/src/state/library_controller.dart';

import 'helpers.dart';

const _plain =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="4" height="4"/></svg>';
const _adaptive =
    '<svg xmlns="http://www.w3.org/2000/svg"><style>.a{fill:#000}'
    '@media (prefers-color-scheme: light){.a{fill:#fff}}</style><rect class="a"/></svg>';

const _download = '/storage/emulated/0/Download';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySvgStorage storage;
  late MemoryDeviceStorage phone;

  Future<LibraryController> open({bool granted = true}) async {
    SharedPreferences.setMockInitialValues({});
    storage = MemorySvgStorage();
    phone = MemoryDeviceStorage(granted: granted)
      ..addFile('$_download/old.svg', _plain, modified: DateTime(2020))
      ..addFile('$_download/new.svg', _adaptive, modified: DateTime(2024))
      ..addFile('/storage/emulated/0/Pictures/mid.svg', _plain, modified: DateTime(2022));
    final library = LibraryController(SvgRepository(storage), device: phone);
    await library.load();
    return library;
  }

  SvgDocument named(LibraryController library, String name) =>
      library.documents.firstWhere((doc) => doc.name == name);

  test('without support nothing about the phone appears', () async {
    final library = LibraryController(SvgRepository(MemorySvgStorage()));
    await library.load();
    expect(library.supportsDevice, isFalse);
    expect(library.deviceAccess, DeviceAccess.unsupported);
    expect(library.documents.where((doc) => doc.isOnDevice), isEmpty);
    expect(await library.shouldPromptForDevice(), isFalse);
  });

  test('access denied: no phone files until the user allows and it is refreshed', () async {
    final library = await open(granted: false);
    expect(library.deviceAccess, DeviceAccess.denied);
    expect(library.documents.where((doc) => doc.isOnDevice), isEmpty);

    await library.requestDeviceAccess();
    expect(phone.requestCount, 1);
    await library.refreshDevice();
    expect(library.deviceAccess, DeviceAccess.granted);
    expect(library.documents.where((doc) => doc.isOnDevice), hasLength(3));
  });

  test('lists library documents first, then phone files newest first', () async {
    final library = await open();
    final names = library.documents.map((doc) => doc.name).toList();
    final demos = bundledDemos();
    expect(names.take(demos.length), demos);
    expect(names.skip(demos.length), ['new.svg', 'mid.svg', 'old.svg']);
    final device = named(library, 'new.svg');
    expect(device.isOnDevice, isTrue);
    expect(device.sourcePath, '$_download/new.svg');
    expect(device.folder, _download);
    expect(device.id, SvgDocument.deviceId('$_download/new.svg'));
  });

  test('phone files never enter the library index', () async {
    final library = await open();
    await library.toggleFavorite(named(library, 'new.svg'));
    await library.importFiles([(name: 'mine.svg', content: _plain)]);

    final indexed = storage.index!.map((entry) => (entry! as Map)['name']).toList();
    expect(indexed, isNot(contains('new.svg')));
    expect(indexed, contains('mine.svg'));
    expect(storage.contents.length, bundledDemos().length + 1);
  });

  test('markup is read on demand and the adaptive filter loads what it needs', () async {
    final library = await open();
    final document = named(library, 'new.svg');
    expect(library.hasContent(document), isFalse);
    expect(library.contentOf(document), isEmpty);

    await library.ensureContent(document);
    expect(library.hasContent(document), isTrue);
    expect(library.contentOf(document), _adaptive);
    expect(library.metadataOf(document).themeSupport.isAdaptive, isTrue);

    library.setFilter(GalleryFilter.adaptive);
    await library.loadAllDeviceContent();
    expect(library.visible.map((doc) => doc.name), containsAll(['new.svg', 'butterfly.svg']));
    expect(library.visible.map((doc) => doc.name), isNot(contains('old.svg')));
  });

  test('files that turn out not to be valid svgs disappear and stay hidden', () async {
    final library = await open();
    phone.addFile('$_download/broken.svg', '<svg><g></svg>', modified: DateTime(2025));
    await library.refreshDevice();
    final broken = named(library, 'broken.svg');

    await library.ensureContent(broken);
    expect(library.documents.map((doc) => doc.name), isNot(contains('broken.svg')));
    await library.refreshDevice();
    expect(library.documents.map((doc) => doc.name), isNot(contains('broken.svg')));
  });

  test('the device filter and search only look at phone files', () async {
    final library = await open()
      ..setFilter(GalleryFilter.device);
    expect(library.visible.map((doc) => doc.name), ['new.svg', 'mid.svg', 'old.svg']);
    library.setQuery('OL');
    expect(library.visible.map((doc) => doc.name), ['old.svg']);
  });

  test('favorites and recents of phone files survive a restart', () async {
    final library = await open();
    await library.toggleFavorite(named(library, 'mid.svg'));
    await library.markOpened(named(library, 'old.svg'));

    final reopened = LibraryController(SvgRepository(storage), device: phone);
    await reopened.load();
    expect(named(reopened, 'mid.svg').isFavorite, isTrue);
    expect(named(reopened, 'old.svg').lastOpenedAt, isNotNull);
    expect(named(reopened, 'new.svg').isFavorite, isFalse);
    reopened.setFilter(GalleryFilter.favorites);
    expect(reopened.visible.map((doc) => doc.name), ['mid.svg']);
  });

  test('a refresh keeps ids and markup of unchanged files and reloads changed ones', () async {
    final library = await open();
    final before = named(library, 'new.svg');
    await library.ensureContent(before);

    await library.refreshDevice();
    expect(named(library, 'new.svg').id, before.id);
    expect(library.hasContent(named(library, 'new.svg')), isTrue);

    phone.addFile('$_download/new.svg', _plain, modified: DateTime(2030));
    await library.refreshDevice();
    expect(named(library, 'new.svg').id, before.id);
    expect(library.hasContent(named(library, 'new.svg')), isFalse);
    await library.ensureContent(named(library, 'new.svg'));
    expect(library.contentOf(named(library, 'new.svg')), _plain);
  });

  test('revoking access removes the phone files', () async {
    final library = await open();
    phone.granted = false;
    await library.refreshDevice();
    expect(library.deviceAccess, DeviceAccess.denied);
    expect(library.documents.where((doc) => doc.isOnDevice), isEmpty);
  });

  test('deleting a phone file deletes the real file; a failure keeps it listed', () async {
    final library = await open();
    final old = named(library, 'old.svg');
    final mid = named(library, 'mid.svg');
    phone.failDeletes.add(mid.sourcePath!);

    expect(await library.delete(old), isTrue);
    expect(phone.contains(old.sourcePath!), isFalse);
    expect(library.byId(old.id), isNull);

    expect(await library.delete(mid), isFalse);
    expect(phone.contains(mid.sourcePath!), isTrue);
    expect(library.byId(mid.id), isNotNull);
  });

  test('deleteMany mixes phone files and gallery files and reports failures', () async {
    final library = await open();
    final wave = named(library, 'wave.svg');
    final old = named(library, 'old.svg');
    final mid = named(library, 'mid.svg');
    final stuck = named(library, 'new.svg');
    phone.failDeletes.add(stuck.sourcePath!);

    final report = await library.deleteMany([wave, old, mid, stuck]);
    expect(report, (deleted: 3, failed: 1));
    expect(library.byId(wave.id), isNull);
    expect(storage.contents.containsKey(wave.id), isFalse);
    expect(phone.contains(old.sourcePath!), isFalse);
    expect(phone.contains(mid.sourcePath!), isFalse);
    expect(phone.contains(stuck.sourcePath!), isTrue);
    expect(library.documents.map((doc) => doc.name), contains('new.svg'));
  });

  test('saving an edit overwrites the original and keeps a backup when asked', () async {
    final library = await open();
    final old = named(library, 'old.svg');
    await library.ensureContent(old);

    final saved = await library.save(old, _adaptive, backup: true);
    expect(phone.contentAt(old.sourcePath!), _adaptive);
    expect(storage.backups.values, [_plain]);
    expect(saved.sizeBytes, _adaptive.length);
    expect(library.contentOf(named(library, 'old.svg')), _adaptive);

    await library.save(named(library, 'old.svg'), '<svg xmlns="http://www.w3.org/2000/svg"/>');
    expect(storage.backups, hasLength(1), reason: 'no backup unless requested');

    phone.granted = false;
    expect(() => library.save(named(library, 'old.svg'), _plain), throwsStateError);
  });

  test('renaming a phone file renames the real file and keeps its favorite', () async {
    final library = await open();
    final mid = named(library, 'mid.svg');
    await library.toggleFavorite(mid);

    final renamed = await library.rename(mid, 'sunrise');
    expect(renamed!.name, 'sunrise.svg');
    expect(renamed.id, mid.id, reason: 'the id stays stable so open screens keep working');
    expect(renamed.sourcePath, '/storage/emulated/0/Pictures/sunrise.svg');
    expect(phone.contains('/storage/emulated/0/Pictures/sunrise.svg'), isTrue);
    expect(phone.contains(mid.sourcePath!), isFalse);

    final reopened = LibraryController(SvgRepository(storage), device: phone);
    await reopened.load();
    expect(named(reopened, 'sunrise.svg').isFavorite, isTrue);
  });

  test('renaming to a name that is taken fails without changing anything', () async {
    final library = await open();
    phone.addFile('$_download/taken.svg', _plain);
    await library.refreshDevice();
    final old = named(library, 'old.svg');

    expect(await library.rename(old, 'taken.svg'), isNull);
    expect(phone.contains(old.sourcePath!), isTrue);
    expect(named(library, 'old.svg').name, 'old.svg');
  });

  test('the access prompt is offered only once', () async {
    final library = await open(granted: false);
    expect(await library.shouldPromptForDevice(), isTrue);
    await library.markDevicePrompted();
    expect(await library.shouldPromptForDevice(), isFalse);
  });

  test('SvgDocument.deviceId is stable, distinct and safe for file names', () {
    final ids = {
      for (var i = 0; i < 5000; i++)
        SvgDocument.deviceId('/storage/emulated/0/Pictures/file_$i.svg'),
    };
    expect(ids, hasLength(5000));
    expect(SvgDocument.deviceId('/a.svg'), SvgDocument.deviceId('/a.svg'));
    expect(SvgDocument.deviceId('/a.svg'), matches(RegExp(r'^dev-[0-9a-f]{16}$')));
  });
}
