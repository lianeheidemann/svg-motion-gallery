// Android/iOS/desktop use dart:io; the web has no shared storage to read.
export 'device_storage_io.dart' if (dart.library.js_interop) 'device_storage_stub.dart';
