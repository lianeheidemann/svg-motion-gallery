import 'package:svg_core/svg_core.dart';

/// Turns stored SVG text into what is actually rendered:
/// sanitized → resolved for [scheme] → looped or played once → viewBox ensured
/// → (for renderers without CSS support, [inlineCss]) styles inlined.
///
/// Results are memoized (LRU) because gallery cards rebuild often.
String prepareSvgForDisplay(
  String svg, {
  required SvgColorScheme scheme,
  bool loop = false,
  bool inlineCss = false,
  String? currentColor,
}) {
  final key = Object.hash(svg, scheme, loop, inlineCss, currentColor);
  final cached = _cache.remove(key);
  if (cached != null) {
    _cache[key] = cached;
    return cached;
  }
  var output = sanitizeSvg(svg);
  output = SvgThemeResolver.resolve(output, scheme, currentColor: currentColor);
  output = loop ? forceLoop(output) : forcePlayOnce(output);
  output = SvgDocumentEdit.ensureViewBox(output);
  if (inlineCss) output = SvgCssInliner.inline(output);
  _cache[key] = output;
  if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
  return output;
}

const _cacheSize = 64;
final _cache = <int, String>{};
