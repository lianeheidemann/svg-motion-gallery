import 'package:xml/xml.dart';

import '../css.dart';
import '../xml_support.dart';
import 'color_scheme.dart';
import 'theme_support.dart';

/// Rewrites an adaptive SVG so it renders as one fixed [SvgColorScheme].
///
/// Resolving in Dart (instead of relying on the renderer honouring
/// `prefers-color-scheme`) makes the result identical in the Android/iOS
/// WebView, in the browser and in `flutter_svg`, and lets the app show both
/// variants side by side.
class SvgThemeResolver {
  const SvgThemeResolver._();

  /// Default text colors used for `currentColor` when none is given.
  static const defaultCurrentColor = {
    SvgColorScheme.light: '#0E1628',
    SvgColorScheme.dark: '#E9EEF8',
  };

  /// Returns [content] resolved for [scheme]. Non-adaptive or invalid
  /// documents are returned unchanged.
  static String resolve(String content, SvgColorScheme scheme, {String? currentColor}) {
    final document = tryParseXml(content);
    if (document == null) return content;
    final support = SvgThemeSupport.detectIn(document);
    if (!support.isAdaptive) return content;
    final root = document.rootElement;

    for (final element in [root, ...root.descendantElements]) {
      if (element.localName == 'style') {
        setStyleText(element, resolveCss(styleText(element), scheme));
      }
      for (final attribute in element.attributes) {
        if (attribute.value.toLowerCase().contains('light-dark')) {
          attribute.value = _replaceLightDark(attribute.value, scheme);
        }
      }
    }

    if (support.uses(SvgThemeMechanism.themeSelector)) {
      root.setAttribute('data-theme', scheme.name);
      final classes =
          (root.getAttribute('class') ?? '')
              .split(RegExp(r'\s+'))
              .where((name) => name.isNotEmpty && name != scheme.opposite.name)
              .toSet()
            ..add(scheme.name);
      root.setAttribute('class', classes.join(' '));
    }

    if (support.uses(SvgThemeMechanism.currentColor) && !_definesColor(root)) {
      root.setAttribute('color', currentColor ?? defaultCurrentColor[scheme]);
    }
    return document.toXmlString();
  }

  /// Resolves `prefers-color-scheme` media blocks and `light-dark()` calls
  /// inside a stylesheet.
  static String resolveCss(String css, SvgColorScheme scheme) => _resolveCss(css, scheme);

  /// With a null [scheme], every `prefers-color-scheme` block is dropped and
  /// `light-dark()` is left as it is (see [withoutThemeVariants]).
  static String _resolveCss(String css, SvgColorScheme? scheme) {
    String plain(String text) => scheme == null ? text : _replaceLightDark(text, scheme);
    final rules = findAtRules(css, 'media');
    if (rules.isEmpty) return plain(css);
    final buffer = StringBuffer();
    var last = 0;
    for (final rule in rules) {
      buffer.write(plain(css.substring(last, rule.start)));
      final inner = css.substring(rule.blockStart + 1, rule.blockEnd);
      final prelude = rule.prelude.toLowerCase();
      if (prelude.contains('prefers-color-scheme')) {
        if (scheme != null && _mediaMatches(prelude, scheme)) {
          buffer.write(_resolveCss(inner, scheme));
        }
      } else {
        buffer
          ..write(css.substring(rule.start, rule.blockStart + 1))
          ..write(_resolveCss(inner, scheme))
          ..write('}');
      }
      last = rule.blockEnd + 1;
    }
    buffer.write(plain(css.substring(last)));
    return buffer.toString();
  }

  static bool _mediaMatches(String prelude, SvgColorScheme scheme) {
    for (final query in prelude.split(',')) {
      final match = RegExp(r'prefers-color-scheme\s*:\s*(light|dark)').firstMatch(query);
      if (match == null) continue;
      final negated = query.trimLeft().startsWith('not ');
      final matches = match.group(1) == scheme.name;
      if (matches != negated) return true;
    }
    return false;
  }

  static String _replaceLightDark(String text, SvgColorScheme scheme) =>
      replaceCssFunction(text, 'light-dark', (args) {
        if (args.length < 2) return args.isEmpty ? '' : args.first;
        return scheme == SvgColorScheme.light ? args[0] : args[1];
      });

  static bool _definesColor(XmlElement root) =>
      root.getAttribute('color') != null ||
      RegExp(r'(^|;)\s*color\s*:').hasMatch(root.getAttribute('style') ?? '');
}

/// [content] as it draws with neither theme: every `prefers-color-scheme`
/// block is dropped (the editor's own included) and `light-dark()` is left
/// as written, so it never equals either version. What a layer shows here is
/// the value both themes share unless one of them sets its own.
String withoutThemeVariants(String content) {
  final document = tryParseXml(content);
  if (document == null) return content;
  final root = document.rootElement;
  for (final element in [root, ...root.descendantElements]) {
    if (element.localName == 'style') {
      setStyleText(element, SvgThemeResolver._resolveCss(styleText(element), null));
    }
  }
  return document.toXmlString();
}
