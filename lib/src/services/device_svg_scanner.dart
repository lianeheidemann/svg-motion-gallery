import '../state/library_controller.dart';
import 'device_svg_scanner_stub.dart'
    if (dart.library.io) 'device_svg_scanner_io.dart';

Future<List<ImportedSvg>> discoverDeviceSvgs() => discoverDeviceSvgsImpl();
