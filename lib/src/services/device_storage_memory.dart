import 'device_storage.dart';

/// In-memory [DeviceStorage] used by tests and by the web preview that
/// stands in for a phone.
class MemoryDeviceStorage implements DeviceStorage {
  MemoryDeviceStorage({this.supported = true, this.granted = false, this.grantOnRequest = true});

  final bool supported;

  /// Whether file access is currently allowed.
  bool granted;

  /// Simulates the user flipping the switch on the system screen.
  bool grantOnRequest;

  /// How many times [requestAccess] was called.
  int requestCount = 0;

  /// Paths whose deletion fails (read-only files, revoked permission...).
  final failDeletes = <String>{};

  final _files = <String, ({String content, DateTime modified})>{};

  Iterable<String> get paths => _files.keys;

  bool contains(String path) => _files.containsKey(path);

  String? contentAt(String path) => _files[path]?.content;

  void addFile(String path, String content, {DateTime? modified}) {
    _files[path] = (content: content, modified: modified ?? DateTime.now());
  }

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasAccess() async => supported && granted;

  @override
  Future<void> requestAccess() async {
    requestCount++;
    if (grantOnRequest) granted = true;
  }

  @override
  Future<List<DeviceSvgEntry>> scan() async {
    if (!granted) return const [];
    final entries = [
      for (final entry in _files.entries)
        DeviceSvgEntry(
          path: entry.key,
          name: entry.key.substring(entry.key.lastIndexOf('/') + 1),
          sizeBytes: entry.value.content.length,
          modified: entry.value.modified,
        ),
    ]..sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  }

  @override
  Future<String?> read(String path) async => granted ? _files[path]?.content : null;

  @override
  Future<bool> write(String path, String content) async {
    if (!granted || !_files.containsKey(path)) return false;
    _files[path] = (content: content, modified: DateTime.now());
    return true;
  }

  /// Where [create] puts files: the phone's main storage.
  static const mainRoot = '/storage/emulated/0';

  @override
  Future<String?> create(String folder, String name, String content) async {
    if (!granted || !name.toLowerCase().endsWith('.svg')) return null;
    final base = name.substring(0, name.length - 4);
    var counter = 2;
    while (_files.containsKey('$mainRoot/$folder/$base-$counter.svg')) {
      counter++;
    }
    final path = '$mainRoot/$folder/$base-$counter.svg';
    addFile(path, content);
    return path;
  }

  @override
  Future<String?> rename(String path, String newName) async {
    if (!granted || !_files.containsKey(path)) return null;
    final target = '${path.substring(0, path.lastIndexOf('/'))}/$newName';
    if (target != path && _files.containsKey(target)) return null;
    final file = _files.remove(path)!;
    _files[target] = file;
    return target;
  }

  @override
  Future<bool> delete(String path) async {
    if (!granted || failDeletes.contains(path)) return false;
    _files.remove(path);
    return true;
  }
}
