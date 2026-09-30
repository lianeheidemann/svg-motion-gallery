import 'dart:convert';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../state/library_controller.dart';

Future<List<ImportedSvg>> discoverDeviceSvgsImpl() async {
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
  await _walk(root, result);
  return result;
}

Future<void> _walk(
  Directory directory,
  List<ImportedSvg> result,
) async {
  final normalized = directory.path.replaceAll('\\', '/');

  // Android can still block these managed folders even with broad storage
  // access. Skipping them also avoids unnecessary traversal.
  if (normalized.contains('/Android/data') ||
      normalized.contains('/Android/obb')) {
    return;
  }

  try {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory) {
        await _walk(entity, result);
        continue;
      }

      if (entity is! File ||
          !entity.path.toLowerCase().endsWith('.svg')) {
        continue;
      }

      try {
        final bytes = await entity.readAsBytes();
        result.add(
          (
            name: entity.uri.pathSegments.last,
            content: utf8.decode(bytes, allowMalformed: true),
          ),
        );
      } catch (_) {
        // Ignore a file that becomes unreadable while scanning.
      }
    }
  } catch (_) {
    // Ignore only this directory and continue with the rest of the tree.
  }
}
