/// An `.svg` found on the phone's storage. The markup is read on demand.
class DeviceSvgEntry {
  const DeviceSvgEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;
}

/// Whether the gallery may list files stored on the phone.
enum DeviceAccess {
  /// The platform has no way to read shared storage (iOS, web).
  unsupported,

  /// Supported, but not checked yet.
  unknown,

  /// Supported, but the user has not allowed file access.
  denied,

  /// Allowed: files can be listed, read, changed and deleted.
  granted,
}

/// Reads and changes `.svg` files on the phone's shared storage.
///
/// Implementations: Android (`device_storage_io.dart`), unsupported platforms
/// ([UnsupportedDeviceStorage]) and memory (`device_storage_memory.dart`,
/// for tests and previews).
abstract interface class DeviceStorage {
  /// False where the platform cannot expose shared storage at all.
  bool get isSupported;

  Future<bool> hasAccess();

  /// Sends the user to the system screen where file access is allowed.
  Future<void> requestAccess();

  /// Every readable `.svg`, newest first (metadata only).
  Future<List<DeviceSvgEntry>> scan();

  /// The markup of [path], or null when it cannot be read.
  Future<String?> read(String path);

  /// Overwrites an existing `.svg`. Returns false when it could not be saved.
  Future<bool> write(String path, String content);

  /// Renames [path] inside its folder and returns the new path, or null when
  /// it failed (for example because the name is already taken).
  Future<String?> rename(String path, String newName);

  /// Permanently deletes an `.svg`. Returns true when the file is gone.
  Future<bool> delete(String path);
}

/// Storage for platforms that cannot list the phone's files.
class UnsupportedDeviceStorage implements DeviceStorage {
  const UnsupportedDeviceStorage();

  @override
  bool get isSupported => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<void> requestAccess() async {}

  @override
  Future<List<DeviceSvgEntry>> scan() async => const [];

  @override
  Future<String?> read(String path) async => null;

  @override
  Future<bool> write(String path, String content) async => false;

  @override
  Future<String?> rename(String path, String newName) async => null;

  @override
  Future<bool> delete(String path) async => false;
}
