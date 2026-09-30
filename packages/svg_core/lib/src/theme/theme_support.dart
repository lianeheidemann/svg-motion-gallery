import 'package:xml/xml.dart';

import '../xml_support.dart';

/// Ways an SVG can change its appearance with the light/dark theme.
enum SvgThemeMechanism {
  /// `@media (prefers-color-scheme: dark) { ... }` in a stylesheet.
  mediaQuery,

  /// The CSS `light-dark(lightColor, darkColor)` function.
  lightDarkFunction,

  /// Paint using `currentColor`, which follows the surrounding text color.
  currentColor,

  /// Selectors such as `[data-theme="dark"]` or `.dark` on the root.
  themeSelector,
}

/// Which theme mechanisms an SVG document uses.
class SvgThemeSupport {
  const SvgThemeSupport(this.mechanisms);

  static const none = SvgThemeSupport(<SvgThemeMechanism>{});

  final Set<SvgThemeMechanism> mechanisms;

  /// True when the SVG can be shown in distinct light and dark variants.
  bool get isAdaptive => mechanisms.isNotEmpty;

  bool uses(SvgThemeMechanism mechanism) => mechanisms.contains(mechanism);

  static final _mediaQuery = RegExp(r'@media[^{]*prefers-color-scheme', caseSensitive: false);
  static final _lightDark = RegExp(r'(?<![\w-])light-dark\s*\(', caseSensitive: false);
  static final _currentColor = RegExp(r'currentcolor', caseSensitive: false);
  static final _themeSelector = RegExp(
    r'''\[data-theme\s*[~|^$*]?=\s*["']?(?:dark|light)|(?<!\d)\.(?:dark|light)(?![\w-])''',
    caseSensitive: false,
  );

  /// Detects theme support in [content]. Invalid XML returns [none].
  static SvgThemeSupport detect(String content) {
    final document = tryParseXml(content);
    if (document == null) return none;
    return detectIn(document);
  }

  /// Same as [detect] for an already parsed document.
  static SvgThemeSupport detectIn(XmlDocument document) {
    final css = StringBuffer();
    final attributeValues = StringBuffer();
    for (final element in document.rootElement.descendantElements) {
      if (element.localName == 'style') css.writeln(styleText(element));
    }
    for (final element in [document.rootElement, ...document.rootElement.descendantElements]) {
      for (final attribute in element.attributes) {
        attributeValues.writeln(attribute.value);
      }
    }
    final stylesheet = css.toString();
    final everything = '$stylesheet\n$attributeValues';
    return SvgThemeSupport({
      if (_mediaQuery.hasMatch(stylesheet)) SvgThemeMechanism.mediaQuery,
      if (_lightDark.hasMatch(everything)) SvgThemeMechanism.lightDarkFunction,
      if (_currentColor.hasMatch(everything)) SvgThemeMechanism.currentColor,
      if (_themeSelector.hasMatch(stylesheet)) SvgThemeMechanism.themeSelector,
    });
  }
}
