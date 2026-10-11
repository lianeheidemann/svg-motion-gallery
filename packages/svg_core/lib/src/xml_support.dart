import 'package:xml/xml.dart';

/// Elements that never paint anything by themselves. They are skipped when
/// listing layers and never wrapped or moved by editing operations.
const nonVisualTags = <String>{
  'defs',
  'style',
  'title',
  'desc',
  'metadata',
  'script',
  'linearGradient',
  'radialGradient',
  'stop',
  'filter',
  'clipPath',
  'mask',
  'pattern',
  'symbol',
  'marker',
  ...smilTags,
};

/// SMIL animation elements.
const smilTags = <String>{'animate', 'animateTransform', 'animateMotion', 'animateColor', 'set'};

/// Marker attribute on groups the editor creates to hold a transform
/// (`root` for the whole drawing, `element` around one element).
const editorAttribute = 'data-sm-edit';

/// Marker attribute on groups the editor creates to hold a preset animation.
const animationAttribute = 'data-sm-anim';

/// Attribute holding a layer's user-given name.
const nameAttribute = 'data-name';

/// Whether [element] is a group created by the editor.
bool isEditorGroup(XmlElement element) =>
    element.getAttribute(editorAttribute) != null ||
    element.getAttribute(animationAttribute) != null;

/// Whether [element] is the group the editor puts around the whole drawing
/// (a transform with nothing selected).
bool isRootWrapper(XmlElement element) => element.getAttribute(editorAttribute) == 'root';

/// Whether [element] is an editor group around a single layer: its
/// transform or its animation. A layer has a chain of them (at most one of
/// each: the transform outside, the animation inside); together with the
/// layer they are one layer for the user.
bool isChainWrapper(XmlElement element) =>
    isEditorGroup(element) &&
    !isRootWrapper(element) &&
    element.childElements.where(isVisual).length == 1;

/// The outermost editor group of the layer [element] belongs to, or
/// [element] when it has none. Moving, ordering or deleting the layer acts
/// on this one, so its groups always go along.
XmlElement chainTop(XmlElement element) {
  var current = element;
  while (true) {
    final parent = current.parentElement;
    if (parent == null || !isChainWrapper(parent)) return current;
    current = parent;
  }
}

/// What the user drew inside the editor groups at [element] ([element]
/// itself when it is not one).
XmlElement chainBottom(XmlElement element) {
  var current = element;
  while (isChainWrapper(current)) {
    current = current.childElements.where(isVisual).single;
  }
  return current;
}

/// The editor groups of the layer [element] belongs to, outermost first.
List<XmlElement> chainWrappers(XmlElement element) {
  final wrappers = <XmlElement>[];
  for (var current = chainTop(element); isChainWrapper(current);) {
    wrappers.add(current);
    current = current.childElements.where(isVisual).single;
  }
  return wrappers;
}

/// Replaces the group [group] by what is inside it.
void unwrapGroup(XmlElement group) {
  final nodes = group.parent!.children;
  final index = nodes.indexOf(group);
  final children = group.children.toList();
  group.remove();
  nodes.insertAll(index, children);
}

/// Follows editor-created wrappers down to the element the user drew.
XmlElement unwrapEditorGroups(XmlElement element) {
  var current = element;
  while (isEditorGroup(current)) {
    final visual = current.childElements.where(isVisual).toList();
    if (visual.length != 1) break;
    current = visual.single;
  }
  return current;
}

/// Creates an element with plain (unprefixed) attribute names.
XmlElement buildElement(
  String tag, {
  Map<String, String> attributes = const {},
  Iterable<XmlNode> children = const [],
}) => XmlElement.tag(
  tag,
  attributes: [
    for (final entry in attributes.entries) XmlAttribute(XmlName.qualified(entry.key), entry.value),
  ],
  children: children,
);

/// Parses [content] or returns null when it is not well-formed XML.
XmlDocument? tryParseXml(String content) {
  try {
    return XmlDocument.parse(content);
  } on XmlException {
    return null;
  } on FormatException {
    return null;
  }
}

/// Parses [content] into a document whose root is `<svg>`, or returns null.
XmlDocument? tryParseSvg(String content) {
  final document = tryParseXml(content);
  if (document == null) return null;
  return document.rootElement.localName == 'svg' ? document : null;
}

/// Whether [element] draws something (or groups things that do).
bool isVisual(XmlElement element) =>
    !nonVisualTags.contains(element.localName) && !element.localName.startsWith('fe');

/// All text of the `<style>` element, including CDATA sections.
String styleText(XmlElement style) => style.children.map((node) => node.value ?? '').join();

/// Replaces the text of a `<style>` element, keeping CDATA when it was used.
void setStyleText(XmlElement style, String css) {
  final usedCdata = style.children.any((node) => node is XmlCDATA);
  style.children
    ..clear()
    ..add(usedCdata ? XmlCDATA(css) : XmlText(css));
}

/// Formats a number for SVG output: at most three decimals, no trailing zeros.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  var text = value.toStringAsFixed(3);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text;
}

/// Parses a length such as `800`, `800px` or `12.5`. Percentages and other
/// relative units return null because they cannot be resolved statically.
double? parseLength(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^\s*(-?\d*\.?\d+(?:e[-+]?\d+)?)\s*(px)?\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  return match == null ? null : double.tryParse(match.group(1)!);
}
