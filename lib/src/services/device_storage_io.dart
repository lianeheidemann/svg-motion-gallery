import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'device_file_ops.dart';
import 'device_storage.dart';

DeviceStorage createPlatformDeviceStorage() =>
    Platform.isAndroid ? AndroidDeviceStorage() : const UnsupportedDeviceStorage();

/// Android shared storage. The permission and the storage roots come from
/// `MainActivity.kt` over a method channel; the file work runs in Dart, in a
/// background isolate for anything that touches many or big files.
class AndroidDeviceStorage implements DeviceStorage {
  AndroidDeviceStorage({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('svg_motion_gallery/device_storage');

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestAccess() async {
    try {
      await _channel.invokeMethod<void>('requestAccess');
    } on MissingPluginException {
      // Not running inside the Android activity (tests).
    }
  }

  @override
  Future<List<DeviceSvgEntry>> scan() async {
    final List<String> roots;
    try {
      roots = await _channel.invokeListMethod<String>('roots') ?? const [];
    } on MissingPluginException {
      return const [];
    }
    if (roots.isEmpty) return const [];
    return Isolate.run(() => scanRoots(roots));
  }

  @override
  Future<String?> read(String path) => Isolate.run(() => readSvgFile(path));

  @override
  Future<bool> write(String path, String content) async {
    final saved = await Isolate.run(() => writeSvgFile(path, content));
    if (saved) unawaited(_notifyChanged(path));
    return saved;
  }

  @override
  Future<String?> rename(String path, String newName) async {
    final renamed = renameSvgFile(path, newName);
    if (renamed != null) {
      unawaited(_notifyChanged(path));
      unawaited(_notifyChanged(renamed));
    }
    return renamed;
  }

  @override
  Future<bool> delete(String path) async {
    final deleted = deleteSvgFile(path);
    if (deleted) unawaited(_notifyChanged(path));
    return deleted;
  }

  /// Asks Android's media scanner to refresh its index for [path]. Best
  /// effort: other apps (Files, Gallery) may otherwise show a stale entry.
  Future<void> _notifyChanged(String path) async {
    try {
      await _channel.invokeMethod<void>('scanFile', path);
    } on PlatformException {
      // The change itself already happened; only the index refresh failed.
    } on MissingPluginException {
      // Not running inside the Android activity (tests).
    }
  }
}
