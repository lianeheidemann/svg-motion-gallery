/// Renders SVG documents with CSS/SMIL animation, light/dark variants and
/// playback control: system WebView on Android/iOS, an iframe on the web and
/// flutter_svg as a still fallback (tests, low-power previews).
library;

export 'src/host_html.dart' show buildHostHtml;
export 'src/playback_controller.dart' show SvgPlaybackController;
export 'src/render_pipeline.dart' show prepareSvgForDisplay;
export 'src/svg_view_widget.dart' show SvgRenderMode, SvgView, SvgViewScope;
