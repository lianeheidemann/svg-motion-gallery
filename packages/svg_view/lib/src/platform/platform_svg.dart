// Picks the live renderer for the current platform at compile time:
// WebView on Android/iOS, an iframe on the web, nothing elsewhere.
export 'platform_svg_stub.dart'
    if (dart.library.js_interop) 'platform_svg_web.dart'
    if (dart.library.io) 'platform_svg_io.dart';
