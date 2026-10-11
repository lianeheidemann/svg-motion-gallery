import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../colors.dart';
import '../theme/color_scheme.dart';
import '../xml_support.dart';
import 'element_path.dart';
import 'paint.dart';
import 'theme_edit.dart';

enum SvgGradientKind { linear, radial }

/// One color of a gradient.
class GradientStop {
  const GradientStop({required this.offset, required this.color, this.opacity = 1});

  /// Position along the gradient, 0 to 1.
  final double offset;

  /// `#RRGGBB`.
  final String color;
  final double opacity;

  GradientStop copyWith({double? offset, String? color, double? opacity}) => GradientStop(
    offset: offset ?? this.offset,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
  );

  @override
  bool operator ==(Object other) =>
      other is GradientStop &&
      other.offset == offset &&
      other.color == color &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(offset, color, opacity);

  @override
  String toString() => 'GradientStop($offset, $color, $opacity)';
}

/// A `<linearGradient>` or `<radialGradient>` as the editor sees it.
///
/// The value is immutable: every `with...` method returns a changed copy that
/// is written back with [SvgGradientEdit.apply]. Whatever the editor does not
/// edit (`gradientUnits`, `gradientTransform`, `spreadMethod`...) is kept as
/// it was in [attributes].
class SvgGradient {
  const SvgGradient({required this.kind, required this.stops, this.attributes = const {}, this.id});

  /// A two-color gradient that starts at [hex] and fades to a lighter or
  /// darker neighbour of it, a sensible first gradient for a solid shape.
  factory SvgGradient.fromColor(String hex, {SvgGradientKind kind = SvgGradientKind.linear}) {
    final base = SvgColorValue.normalize(hex) ?? '#000000';
    return SvgGradient(
      kind: kind,
      stops: [
        GradientStop(offset: 0, color: base),
        GradientStop(offset: 1, color: _neighbour(base)),
      ],
      attributes: kind == SvgGradientKind.radial
          ? const {'cx': '0.5', 'cy': '0.5', 'r': '0.5'}
          : const {'x1': '0', 'y1': '0', 'x2': '1', 'y2': '0'},
    );
  }

  /// The `id` of the element in the document; null for a gradient that was not
  /// written yet.
  final String? id;
  final SvgGradientKind kind;
  final List<GradientStop> stops;

  /// Raw geometry attributes (`x1`, `cx`, `gradientUnits`...), resolved through
  /// `href` chains.
  final Map<String, String> attributes;

  bool get isLinear => kind == SvgGradientKind.linear;

  /// Direction of a linear gradient in degrees: 0 runs left to right, 90 top
  /// to bottom.
  double get angle {
    final dx = _number(attributes['x2'], 1) - _number(attributes['x1'], 0);
    final dy = _number(attributes['y2'], 0) - _number(attributes['y1'], 0);
    if (dx == 0 && dy == 0) return 0;
    final degrees = math.atan2(dy, dx) * 180 / math.pi;
    return degrees < 0 ? degrees + 360 : degrees;
  }

  double get centerX => _number(attributes['cx'], 0.5);
  double get centerY => _number(attributes['cy'], 0.5);
  double get radius => _number(attributes['r'], 0.5);

  SvgGradient copyWith({
    List<GradientStop>? stops,
    Map<String, String>? attributes,
    SvgGradientKind? kind,
    String? id,
  }) => SvgGradient(
    kind: kind ?? this.kind,
    stops: stops ?? this.stops,
    attributes: attributes ?? this.attributes,
    id: id ?? this.id,
  );

  /// This gradient pointing at [degrees]; the line spans the whole shape.
  SvgGradient withAngle(double degrees) {
    final radians = degrees * math.pi / 180;
    final c = math.cos(radians);
    final s = math.sin(radians);
    final half = 0.5 / math.max(c.abs(), s.abs());
    return copyWith(
      attributes: {
        ..._withoutGeometry(attributes),
        'x1': formatNumber(0.5 - c * half),
        'y1': formatNumber(0.5 - s * half),
        'x2': formatNumber(0.5 + c * half),
        'y2': formatNumber(0.5 + s * half),
      },
    );
  }

  /// This gradient as a [kind] one, with the default geometry (a left to
  /// right line, or a circle centered in the shape).
  SvgGradient withKind(SvgGradientKind kind) {
    if (kind == this.kind) return this;
    return copyWith(
      kind: kind,
      attributes: {
        ..._withoutGeometry(attributes),
        if (kind == SvgGradientKind.radial) ...{'cx': '0.5', 'cy': '0.5', 'r': '0.5'},
      },
    );
  }

  /// The colors in the opposite order.
  SvgGradient get reversed =>
      copyWith(stops: [for (final stop in stops.reversed) stop.copyWith(offset: 1 - stop.offset)]);

  /// Replaces stop [index]; its position is kept between its neighbours so the
  /// stops never swap places and indices stay valid.
  SvgGradient withStop(int index, GradientStop stop) {
    if (index < 0 || index >= stops.length) return this;
    final low = index == 0 ? 0.0 : stops[index - 1].offset;
    final high = index == stops.length - 1 ? 1.0 : stops[index + 1].offset;
    final next = [...stops];
    next[index] = stop.copyWith(offset: stop.offset.clamp(low, high));
    return copyWith(stops: next);
  }

  /// Adds a stop at [offset] with the color the gradient has there. Returns
  /// the new gradient; the new stop's index is [indexForOffset].
  SvgGradient withStopAt(double offset) {
    final at = offset.clamp(0.0, 1.0);
    final index = indexForOffset(at);
    final color = colorAt(at);
    return copyWith(
      stops: [
        ...stops.sublist(0, index),
        GradientStop(offset: at, color: color.$1, opacity: color.$2),
        ...stops.sublist(index),
      ],
    );
  }

  /// Where a stop at [offset] would be inserted.
  int indexForOffset(double offset) {
    var index = 0;
    while (index < stops.length && stops[index].offset <= offset) {
      index++;
    }
    return index;
  }

  /// Without stop [index]; a gradient keeps at least two.
  SvgGradient withoutStop(int index) {
    if (stops.length <= 2 || index < 0 || index >= stops.length) return this;
    return copyWith(stops: [...stops]..removeAt(index));
  }

  /// `#RRGGBB` and opacity the gradient has at [offset].
  (String, double) colorAt(double offset) {
    if (stops.isEmpty) return ('#000000', 1);
    if (offset <= stops.first.offset) return (stops.first.color, stops.first.opacity);
    for (var i = 1; i < stops.length; i++) {
      final b = stops[i];
      if (offset > b.offset) continue;
      final a = stops[i - 1];
      final span = b.offset - a.offset;
      final t = span <= 0 ? 1.0 : (offset - a.offset) / span;
      return (_mix(a.color, b.color, t), a.opacity + (b.opacity - a.opacity) * t);
    }
    return (stops.last.color, stops.last.opacity);
  }

  static const _geometryKeys = {
    'x1', 'y1', 'x2', 'y2', 'cx', 'cy', 'r', 'fx', 'fy', 'fr', //
    'gradientUnits', 'gradientTransform',
  };

  static Map<String, String> _withoutGeometry(Map<String, String> attributes) => {
    for (final entry in attributes.entries)
      if (!_geometryKeys.contains(entry.key)) entry.key: entry.value,
  };

  static double _number(String? value, double fallback) => _fraction(value) ?? fallback;

  static String _neighbour(String hex) {
    final value = int.parse(hex.substring(1), radix: 16);
    final luma = (0.299 * (value >> 16 & 255) + 0.587 * (value >> 8 & 255) + 0.114 * (value & 255));
    return luma < 150 ? _mix(hex, '#FFFFFF', 0.45) : _mix(hex, '#000000', 0.35);
  }
}

/// Reads and writes the gradients of an SVG document.
///
/// Every function takes SVG text and returns new SVG text. A gradient lives in
/// `<defs>` and is shared by whatever points at it with `url(#id)`, so an edit
/// that reaches only some of those shapes writes a copy for them instead of
/// changing the original.
class SvgGradientEdit {
  const SvgGradientEdit._();

  /// Ids of the gradients the editor creates start with this.
  static const idPrefix = 'sm-grad-';

  static final _geometry = SvgGradient._geometryKeys;
  static final _reference = RegExp(r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''');

  /// The id inside a paint value such as `url(#wing)`, or null.
  static String? idOf(String? paint) =>
      paint == null ? null : _reference.firstMatch(paint)?.group(1);

  /// The gradient with [id], or null when the document has none.
  static SvgGradient? read(String svg, String id) {
    final document = tryParseSvg(svg);
    final element = document == null ? null : _find(document, id);
    return element == null ? null : _model(document!, element);
  }

  /// The gradient the element at [path] paints its [property] (`fill` or
  /// `stroke`) with: its own, else its nearest ancestor's. Null when that is
  /// not a gradient.
  static SvgGradient? of(String svg, ElementPath path, String property) {
    final document = tryParseSvg(svg);
    var element = paintTarget(document, path);
    while (element != null) {
      final value = ownPaintValue(element, property);
      if (value != null) {
        final id = idOf(value);
        return id == null ? null : read(svg, id);
      }
      element = element.parentElement;
    }
    return null;
  }

  /// Same as [of] for what the [scheme] variant of the file shows.
  static SvgGradient? ofScheme(
    String svg,
    ElementPath path,
    String property,
    SvgColorScheme scheme,
  ) {
    final id = idOf(SvgThemeEdit.paintFor(svg, path, scheme, property));
    return id == null ? null : read(svg, id);
  }

  /// Paints [property] of every element in [paths] with [gradient].
  ///
  /// When [gradient] has the [SvgGradient.id] of one that exists and nothing
  /// outside [paths] uses it, that gradient is updated where it is; otherwise
  /// a copy with a new id is written, so shapes that were not picked keep
  /// their colors.
  static String apply(String svg, List<ElementPath> paths, String property, SvgGradient gradient) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final targets = <XmlElement>[];
    for (final path in paths) {
      final element = paintTarget(document, path);
      if (element != null && !targets.contains(element)) targets.add(element);
    }
    if (targets.isEmpty) return svg;
    final id = gradient.id;
    final existing = id == null ? null : _find(document, id);
    final inPlace =
        existing != null &&
        _references(document, id!).every(
          (reference) => targets.contains(reference.element) && reference.property == property,
        );
    final written = _define(document, gradient, inPlace: inPlace);
    for (final target in targets) {
      writePaintProperty(target, property, 'url(#$written)');
    }
    _collect(document);
    return document.toXmlString();
  }

  /// Same as [apply] for one variant of a file with light and dark versions:
  /// the other variant keeps the paint it has.
  static String applyScheme(
    String svg,
    List<ElementPath> paths,
    String property,
    SvgColorScheme scheme,
    SvgGradient gradient,
  ) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final id = gradient.id;
    final existing = id == null ? null : _find(document, id);
    // The only user of a gradient the editor made: change it where it is.
    if (existing != null &&
        id!.startsWith(idPrefix) &&
        RegExp('#${RegExp.escape(id)}(?![\\w-])').allMatches(svg).length == 1 &&
        paths.every((p) => idOf(SvgThemeEdit.paintFor(svg, p, scheme, property)) == id)) {
      _write(existing, gradient);
      return document.toXmlString();
    }
    final written = _define(document, gradient, inPlace: false);
    var out = document.toXmlString();
    for (final path in paths) {
      out = SvgThemeEdit.setPaint(out, path, 'url(#$written)', scheme, property);
    }
    return collectGarbage(out);
  }

  /// Paints [property] of every element in [paths] with the plain [color]
  /// (null for `none`), dropping gradients nothing uses any more.
  static String toSolid(String svg, List<ElementPath> paths, String property, String? color) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    for (final path in paths) {
      final element = paintTarget(document, path);
      if (element != null) writePaintProperty(element, property, color ?? 'none');
    }
    _collect(document);
    return document.toXmlString();
  }

  /// Removes the gradients this editor created that nothing points at.
  static String collectGarbage(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    return _collect(document) ? document.toXmlString() : svg;
  }

  // ---------------------------------------------------------------- reading

  static XmlElement? _find(XmlDocument document, String id) {
    for (final element in document.rootElement.descendantElements) {
      if (_isGradient(element) && element.getAttribute('id') == id) return element;
    }
    return null;
  }

  static bool _isGradient(XmlElement element) =>
      element.localName == 'linearGradient' || element.localName == 'radialGradient';

  /// [element] followed by the gradients its `href` chain leads to.
  static List<XmlElement> _chain(XmlDocument document, XmlElement element) {
    final chain = [element];
    var current = element;
    while (true) {
      final href = current.getAttribute('href') ?? current.getAttribute('xlink:href');
      if (href == null || !href.trim().startsWith('#')) break;
      final next = _find(document, href.trim().substring(1));
      if (next == null || chain.contains(next)) break;
      chain.add(next);
      current = next;
    }
    return chain;
  }

  static SvgGradient _model(XmlDocument document, XmlElement element) {
    final chain = _chain(document, element);
    final attributes = <String, String>{};
    for (final link in chain.reversed) {
      for (final attribute in link.attributes) {
        final name = attribute.localName;
        final sameKind = link.localName == element.localName;
        final common = name == 'gradientUnits' || name == 'gradientTransform';
        if (name == 'spreadMethod' || common || (sameKind && _geometry.contains(name))) {
          attributes[name] = attribute.value;
        }
      }
    }
    var stops = <GradientStop>[];
    for (final link in chain) {
      stops = _stopsOf(link);
      if (stops.isNotEmpty) break;
    }
    return SvgGradient(
      id: element.getAttribute('id'),
      kind: element.localName == 'radialGradient' ? SvgGradientKind.radial : SvgGradientKind.linear,
      stops: stops,
      attributes: attributes,
    );
  }

  static List<GradientStop> _stopsOf(XmlElement gradient) {
    final stops = <GradientStop>[];
    var last = 0.0;
    for (final stop in gradient.childElements.where((e) => e.localName == 'stop')) {
      final offset = (_fraction(stop.getAttribute('offset')) ?? last).clamp(last, 1.0);
      last = offset;
      final raw = ownPaintValue(stop, 'stop-color');
      stops.add(
        GradientStop(
          offset: offset,
          color: (raw == null ? null : SvgColorValue.normalize(raw)) ?? '#000000',
          opacity: (_fraction(ownPaintValue(stop, 'stop-opacity')) ?? 1).clamp(0.0, 1.0),
        ),
      );
    }
    return stops;
  }

  // ---------------------------------------------------------------- writing

  /// Writes [gradient] into the document and returns the id it has there.
  static String _define(XmlDocument document, SvgGradient gradient, {required bool inPlace}) {
    final id = gradient.id;
    final existing = id == null ? null : _find(document, id);
    if (inPlace && existing != null) {
      _write(existing, gradient);
      return id!;
    }
    final fresh = _newId(document);
    // A copy keeps what the editor does not touch (animations on the stops).
    final element = _write(existing?.copy() ?? buildElement(_tag(gradient.kind)), gradient);
    element.setAttribute('id', fresh);
    final parent = existing?.parent;
    if (existing != null && parent != null) {
      parent.children.insert(parent.children.indexOf(existing) + 1, element);
    } else {
      _defs(document).children.add(element);
    }
    return fresh;
  }

  static String _tag(SvgGradientKind kind) =>
      kind == SvgGradientKind.radial ? 'radialGradient' : 'linearGradient';

  /// Makes [element] describe [gradient]; returns it, or the element that
  /// took its place when the kind changed.
  static XmlElement _write(XmlElement element, SvgGradient gradient) {
    final tag = _tag(gradient.kind);
    var target = element;
    if (element.localName != tag) {
      target = buildElement(
        tag,
        attributes: {for (final a in element.attributes) a.qualifiedName: a.value},
        children: element.children.map((node) => node.copy()).toList(),
      );
      if (element.parent != null) element.replace(target);
    }
    for (final name in [..._geometry, 'spreadMethod', 'href', 'xlink:href']) {
      target.removeAttribute(name);
    }
    for (final entry in gradient.attributes.entries) {
      target.setAttribute(entry.key, entry.value);
    }
    _writeStops(target, gradient.stops);
    return target;
  }

  static void _writeStops(XmlElement gradient, List<GradientStop> stops) {
    final own = gradient.childElements.where((e) => e.localName == 'stop').toList();
    for (var i = 0; i < stops.length; i++) {
      final element = i < own.length ? own[i] : buildElement('stop');
      final stop = stops[i];
      element.setAttribute('offset', formatNumber(stop.offset));
      writePaintProperty(element, 'stop-color', stop.color);
      if (stop.opacity >= 0.999) {
        element.removeAttribute('stop-opacity');
      } else {
        writePaintProperty(element, 'stop-opacity', formatNumber(stop.opacity));
      }
      if (i >= own.length) gradient.children.add(element);
    }
    for (final extra in own.skip(stops.length)) {
      extra.remove();
    }
  }

  static XmlElement _defs(XmlDocument document) {
    final root = document.rootElement;
    for (final child in root.childElements) {
      if (child.localName == 'defs') return child;
    }
    // At the end, so the paths of the layers do not move.
    final defs = buildElement('defs');
    root.children.add(defs);
    return defs;
  }

  static String _newId(XmlDocument document) {
    final taken = {
      for (final element in document.rootElement.descendantElements) element.getAttribute('id'),
    };
    var n = 1;
    while (taken.contains('$idPrefix$n')) {
      n++;
    }
    return '$idPrefix$n';
  }

  // ------------------------------------------------------------- references

  /// Every place that points at gradient [id]: a paint property that holds
  /// `url(#id)`, an `href` to it, or a stylesheet (property `*`).
  static List<({XmlElement element, String property})> _references(
    XmlDocument document,
    String id,
  ) {
    final found = <({XmlElement element, String property})>[];
    final url = RegExp('url\\(\\s*[\'"]?#${RegExp.escape(id)}[\'"]?\\s*\\)');
    for (final element in document.rootElement.descendantElements) {
      if (element.localName == 'style') {
        if (url.hasMatch(styleText(element))) found.add((element: element, property: '*'));
        continue;
      }
      for (final attribute in element.attributes) {
        final name = attribute.localName;
        if (name == 'href') {
          if (attribute.value.trim() == '#$id') found.add((element: element, property: 'href'));
        } else if (name == 'style') {
          for (final declaration in attribute.value.split(';')) {
            final colon = declaration.indexOf(':');
            if (colon > 0 && url.hasMatch(declaration)) {
              found.add((element: element, property: declaration.substring(0, colon).trim()));
            }
          }
        } else if (url.hasMatch(attribute.value)) {
          found.add((element: element, property: name));
        }
      }
    }
    return found;
  }

  /// Removes editor-made gradients nothing uses; true when it removed any.
  static bool _collect(XmlDocument document) {
    var removed = false;
    var again = true;
    while (again) {
      again = false;
      final candidates = document.rootElement.descendantElements
          .where((e) => _isGradient(e) && (e.getAttribute('id') ?? '').startsWith(idPrefix))
          .toList();
      for (final gradient in candidates) {
        if (_references(document, gradient.getAttribute('id')!).isEmpty) {
          final holder = gradient.parent;
          gradient.remove();
          // The `<defs>` this editor opened for it goes too once it is empty.
          if (holder is XmlElement && holder.localName == 'defs' && holder.children.isEmpty) {
            holder.remove();
          }
          removed = again = true;
        }
      }
    }
    return removed;
  }
}

/// `0.5` or `50%` as a number; null when it is neither.
double? _fraction(String? value) {
  if (value == null) return null;
  final text = value.trim();
  if (text.endsWith('%')) {
    final percent = double.tryParse(text.substring(0, text.length - 1));
    return percent == null ? null : percent / 100;
  }
  return double.tryParse(text);
}

/// Linear mix of two `#RRGGBB` colors; [t] 0 is [a], 1 is [b].
String _mix(String a, String b, double t) {
  final x = int.parse(a.substring(1), radix: 16);
  final y = int.parse(b.substring(1), radix: 16);
  int channel(int shift) {
    final from = x >> shift & 255;
    final to = y >> shift & 255;
    return (from + (to - from) * t).round().clamp(0, 255);
  }

  final value = channel(16) << 16 | channel(8) << 8 | channel(0);
  return '#${value.toRadixString(16).padLeft(6, '0')}'.toUpperCase();
}
