import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/services/device_file_ops.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="4" height="4"/></svg>';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('svg_device'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String path, String content, {DateTime? modified}) {
    final file = File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  group('createSvgFile', () {
    test('makes the folder and a new file, never overwriting', () {
      final first = createSvgFile(root.path, 'SVG Gallery', 'a.svg', _svg)!;
      expect(first, '${root.path}/SVG Gallery/a-2.svg');
      expect(File(first).readAsStringSync(), _svg);

      write('SVG Gallery/a-3.svg', 'other');
      final second = createSvgFile(root.path, 'SVG Gallery', 'a.svg', _svg)!;
      expect(second, '${root.path}/SVG Gallery/a-4.svg');
      expect(File('${root.path}/SVG Gallery/a-3.svg').readAsStringSync(), 'other');
      expect(
        Directory('${root.path}/SVG Gallery').listSync().map((e) => e.path),
        isNot(contains(endsWith('.sm-tmp'))),
      );
    });

    test('refuses unsafe folders and names', () {
      expect(createSvgFile(root.path, '..', 'a.svg', _svg), isNull);
      expect(createSvgFile(root.path, 'a/b', 'a.svg', _svg), isNull);
      expect(createSvgFile(root.path, '.hidden', 'a.svg', _svg), isNull);
      expect(createSvgFile(root.path, 'ok', '../a.svg', _svg), isNull);
      expect(createSvgFile(root.path, 'ok', '.a.svg', _svg), isNull);
      expect(createSvgFile(root.path, 'ok', 'a.txt', _svg), isNull);
      expect(createSvgFile(root.path, 'ok', '', _svg), isNull);
    });

    test('the new file is found by a scan', () {
      createSvgFile(root.path, 'SVG Gallery', 'a.svg', _svg);
      expect(scanRoots([root.path]).map((e) => e.name), ['a-2.svg']);
    });
  });

  group('scanRoots', () {
    test('finds svgs recursively, newest first, with size and date', () {
      write('Download/old.svg', _svg, modified: DateTime(2020));
      write('Pictures/deep/new.SVG', _svg, modified: DateTime(2024));

      final entries = scanRoots([root.path]);
      expect(entries.map((e) => e.name), ['new.SVG', 'old.svg']);
      expect(entries.first.sizeBytes, _svg.length);
      expect(entries.first.modified.year, 2024);
      expect(entries.first.path, '${root.path}/Pictures/deep/new.SVG');
    });

    test('skips hidden, Android/, non-svg, empty and not-svg-looking files', () {
      write('.hidden/a.svg', _svg);
      write('.trash.svg', _svg);
      write('Android/data/b.svg', _svg);
      write('notes.txt', _svg);
      write('empty.svg', '');
      write('page.svg', '<html><body/></html>');
      write('ok.svg', _svg);

      expect(scanRoots([root.path]).map((e) => e.name), ['ok.svg']);
    });

    test('accepts an xml prolog before <svg> and ignores files above the size limit', () {
      write('prolog.svg', '<?xml version="1.0"?>\n<!-- c -->\n$_svg');
      write('big.svg', _svg + ' ' * 2000);

      final names = scanRoots([root.path], maxBytes: 1000).map((e) => e.name);
      expect(names, ['prolog.svg']);
      expect(scanRoots([root.path]).map((e) => e.name), containsAll(['prolog.svg', 'big.svg']));
    });

    test('scans several roots without listing a file twice', () {
      write('one/a.svg', _svg);
      write('two/b.svg', _svg);

      final entries = scanRoots(['${root.path}/one', '${root.path}/two', '${root.path}/one']);
      expect(entries.map((e) => e.name).toSet(), {'a.svg', 'b.svg'});
      expect(entries, hasLength(2));
    });

    test('ignores roots that do not exist', () {
      expect(scanRoots(['${root.path}/missing']), isEmpty);
    });
  });

  group('read and write', () {
    test('reads an svg and refuses unsafe paths', () {
      final file = write('a.svg', _svg);
      expect(readSvgFile(file.path), _svg);
      expect(readSvgFile('${root.path}/missing.svg'), isNull);
      expect(readSvgFile(write('a.txt', _svg).path), isNull);
      expect(readSvgFile('relative.svg'), isNull);
      expect(readSvgFile('${root.path}/sub/../a.svg'), isNull);
      expect(readSvgFile(file.path, maxBytes: 5), isNull);
    });

    test('overwrites atomically and never creates files', () {
      final file = write('a.svg', _svg);
      expect(writeSvgFile(file.path, '<svg/>'), isTrue);
      expect(file.readAsStringSync(), '<svg/>');
      expect(File('${file.path}.sm-tmp').existsSync(), isFalse);

      expect(writeSvgFile('${root.path}/new.svg', '<svg/>'), isFalse);
      expect(File('${root.path}/new.svg').existsSync(), isFalse);
      expect(writeSvgFile('${root.path}/a.txt', '<svg/>'), isFalse);
    });
  });

  group('renameSvgFile', () {
    test('renames inside the same folder', () {
      final file = write('Download/a.svg', _svg);
      final renamed = renameSvgFile(file.path, 'b.svg');
      expect(renamed, '${root.path}/Download/b.svg');
      expect(File(renamed!).existsSync(), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('never overwrites another file or accepts odd names', () {
      final a = write('a.svg', _svg);
      write('b.svg', '<svg id="other"/>');
      expect(renameSvgFile(a.path, 'b.svg'), isNull);
      expect(File('${root.path}/b.svg').readAsStringSync(), '<svg id="other"/>');
      expect(renameSvgFile(a.path, '../c.svg'), isNull);
      expect(renameSvgFile(a.path, 'c.png'), isNull);
      expect(renameSvgFile(a.path, '.c.svg'), isNull);
      expect(renameSvgFile(a.path, ''), isNull);
      expect(renameSvgFile(a.path, 'a.svg'), a.path, reason: 'same name is a no-op');
      expect(renameSvgFile('${root.path}/missing.svg', 'z.svg'), isNull);
    });
  });

  group('deleteSvgFile', () {
    test('deletes an existing svg', () {
      final file = write('Download/delete-me.svg', _svg);
      expect(deleteSvgFile(file.path), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('refuses other extensions, folders and unsafe paths', () {
      final text = write('Download/keep.txt', _svg);
      final folder = Directory('${root.path}/folder.svg')..createSync();
      final keep = write('keep.svg', _svg);

      expect(deleteSvgFile(text.path), isFalse);
      expect(text.existsSync(), isTrue);
      expect(deleteSvgFile(folder.path), isFalse);
      expect(folder.existsSync(), isTrue);
      expect(deleteSvgFile('keep.svg'), isFalse);
      expect(deleteSvgFile('${root.path}/x/../keep.svg'), isFalse);
      expect(keep.existsSync(), isTrue);
    });

    test('a file that is already gone counts as deleted', () {
      expect(deleteSvgFile('${root.path}/missing.svg'), isTrue);
    });
  });

  test('isSafeSvgPath only allows absolute .svg paths without ..', () {
    expect(isSafeSvgPath('/storage/emulated/0/a.svg'), isTrue);
    expect(isSafeSvgPath('/storage/A.SVG'), isTrue);
    expect(isSafeSvgPath('a.svg'), isFalse);
    expect(isSafeSvgPath('/a/../b.svg'), isFalse);
    expect(isSafeSvgPath('/a/b.png'), isFalse);
  });
}
