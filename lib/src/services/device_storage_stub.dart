import 'device_storage.dart';

/// Web: browsers cannot list files on the user's device.
DeviceStorage createPlatformDeviceStorage() => const UnsupportedDeviceStorage();
