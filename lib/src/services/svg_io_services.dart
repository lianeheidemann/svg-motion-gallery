import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../state/library_controller.dart';

/// Lets the user import and discover `.svg` files. An interface so tests can
/// fake device storage.
abstract interface class SvgImporter {
  /// Picked files (empty when cancelled).
  Future<List<ImportedSvg>> pick();

  /// Requests the Android storage permission when needed and discovers SVGs
  /// from shared storage. Other platforms return an empty list.
  Future<List<ImportedSvg>> scanDevice();
}

/// Shares an SVG file with other apps.
abstract interface class SvgSharer {
  Future<void> share(String name, String content, {Rect? origin});
}

class FilePickerSvgImporter implements SvgImporter {
  const FilePickerSvgImporter();

  @override
  Future<List<ImportedSvg>> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'],
      allowMultiple: true,
    );
    if (files == null) return const [];

    final result = <ImportedSvg>[];
    for (final file in files.files) {
      if (!file.name.toLowerCase().endsWith('.svg')) continue;
      final bytes = await file.readAsBytes();
      result.add(
        (
          name: file.name,
          content: utf8.decode(bytes, allowMalformed: true),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<ImportedSvg>> scanDevice() async {
    if (!Platform.isAndroid) return const [];

    var granted = await Permission.manageExternalStorage.isGranted;
    if (!granted) {
      granted = (await Permission.manageExternalStorage.request()).isGranted;
    }

    // Android 10 and older use the legacy storage permission instead.
    if (!granted) {
      granted = (await Permission.storage.request()).isGranted;
    }
    if (!granted) return const [];

    final root = Directory('/storage/emulated/0');
    if (!await root.exists()) return const [];

    final result = <ImportedSvg>[];
    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.svg')) {
          continue;
        }
        try {
          final content = await entity.readAsString();
          result.add((name: entity.uri.pathSegments.last, content: content));
        } on FileSystemException {
          // A few Android-managed folders can remain inaccessible even when
          // broad storage access is enabled. Skip only the unreadable file.
        }
      }
    } on FileSystemException {
      // If Android blocks a subtree, preserve any SVGs already discovered.
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
        files: [
          XFile.fromData(
            utf8.encode(content),
            mimeType: 'image/svg+xml',
            name: name,
          ),
        ],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
  }
}
