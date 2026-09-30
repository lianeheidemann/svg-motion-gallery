import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../state/library_controller.dart';

/// Lets the user pick `.svg` files. An interface so tests can fake it.
abstract interface class SvgImporter {
  /// Picked files (empty when cancelled).
  Future<List<ImportedSvg>> pick();
}

/// Shares an SVG file with other apps.
abstract interface class SvgSharer {
  Future<void> share(String name, String content, {Rect? origin});
}

class FilePickerSvgImporter implements SvgImporter {
  const FilePickerSvgImporter();

  @override
  Future<List<ImportedSvg>> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['svg']);
    final result = <ImportedSvg>[];
    for (final file in files) {
      if (!file.name.toLowerCase().endsWith('.svg')) continue;
      final bytes = await file.readAsBytes();
      result.add((name: file.name, content: utf8.decode(bytes, allowMalformed: true)));
    }
    return result;
  }
}

class SharePlusSvgSharer implements SvgSharer {
  const SharePlusSvgSharer();

  @override
  Future<void> share(String name, String content, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(content), mimeType: 'image/svg+xml', name: name)],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
  }
}
