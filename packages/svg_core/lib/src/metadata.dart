import 'package:xml/xml.dart';

import 'css.dart';
import 'theme/theme_support.dart';
import 'time.dart';
import 'xml_support.dart';

/// How an SVG is animated.
enum SvgAnimationKind { smil, css }

/// The `viewBox` of an SVG root.
class SvgViewBox {
  const SvgViewBox(this.minX, this.minY, this.width, this.height);

  final double minX;
  final double minY;
  final double width;
  final double height;

  double get centerX => minX + width / 2;
  double get centerY => minY + height / 2;

  static SvgViewBox? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.trim().split(RegExp(r'[\s,]+'));
    if (parts.length != 4) return null;
    final numbers = parts.map(double.tryParse).toList();
    if (numbers.any((number) => number == null)) return null;
    if (numbers[2]! <= 0 || numbers[3]! <= 0) return null;
    return SvgViewBox(numbers[0]!, numbers[1]!, numbers[2]!, numbers[3]!);
  }

  @override
  String toString() => [minX, minY, width, height].map(formatNumber).join(' ');
}

/// Facts about an SVG document used by the gallery, viewer and editor.
class SvgMetadata {
  const SvgMetadata({
    this.width,
    this.height,
    this.viewBox,
    this.elementCount = 0,
    this.animationKinds = const {},
    this.cycleDuration,
    this.themeSupport = SvgThemeSupport.none,
  });

  static const empty = SvgMetadata();

  /// Declared width/height (px or unitless). Null when relative or absent.
  final double? width;
  final double? height;
  final SvgViewBox? viewBox;

  /// Number of drawable elements (groups and shapes).
  final int elementCount;
  final Set<SvgAnimationKind> animationKinds;

  /// Length of the longest animation cycle, used by the playback slider.
  final Duration? cycleDuration;
  final SvgThemeSupport themeSupport;

  bool get isAnimated => animationKinds.isNotEmpty;

  /// Width and height to show to the user: declared size, else the viewBox.
  double? get displayWidth => width ?? viewBox?.width;
  double? get displayHeight => height ?? viewBox?.height;

  /// Coordinate box used to place new content: viewBox, else declared size.
  SvgViewBox get canvas => viewBox ?? SvgViewBox(0, 0, width ?? 300, height ?? 150);

  /// Tolerant: invalid XML yields [empty].
  static SvgMetadata parse(String content) {
    final document = tryParseXml(content);
    if (document == null) return empty;
    final root = document.rootElement;
    final elements = root.descendantElements.toList();

    final kinds = <SvgAnimationKind>{};
    var longest = 0.0;
    for (final element in elements) {
      if (smilTags.contains(element.localName)) {
        kinds.add(SvgAnimationKind.smil);
        final duration = parseClockValue(element.getAttribute('dur'));
        if (duration != null && duration > longest) longest = duration;
      }
    }
    for (final css in _allCss(root, elements)) {
      if (!RegExp('animation', caseSensitive: false).hasMatch(css)) continue;
      mapStylesheetDeclarations(css.contains('{') ? css : '{$css}', (property, value) {
        if (property == 'animation' || property == 'animation-name') {
          if (!RegExp(r'^\s*none\s*$').hasMatch(value)) kinds.add(SvgAnimationKind.css);
        }
        if (property == 'animation' || property == 'animation-duration') {
          for (final item in splitTopLevel(value, ',')) {
            final times = cssTimes(item);
            if (times.isNotEmpty && times.first > longest) longest = times.first;
          }
        }
        return value;
      });
    }

    return SvgMetadata(
      width: parseLength(root.getAttribute('width')),
      height: parseLength(root.getAttribute('height')),
      viewBox: SvgViewBox.tryParse(root.getAttribute('viewBox')),
      elementCount: elements.where(isVisual).length,
      animationKinds: kinds,
      cycleDuration: longest > 0
          ? Duration(microseconds: (longest * Duration.microsecondsPerSecond).round())
          : null,
      themeSupport: SvgThemeSupport.detectIn(document),
    );
  }

  static Iterable<String> _allCss(XmlElement root, List<XmlElement> elements) sync* {
    for (final element in [root, ...elements]) {
      if (element.localName == 'style') yield styleText(element);
      final inline = element.getAttribute('style');
      if (inline != null) yield inline;
    }
  }
}
