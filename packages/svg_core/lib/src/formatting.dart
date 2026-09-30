import 'package:xml/xml.dart';

import 'xml_support.dart';

const _whitespaceSensitive = {'text', 'tspan', 'textPath', 'style', 'title', 'desc'};

/// Pretty-prints [content] with two-space indentation, or returns null when
/// it is not well-formed XML. Text content (e.g. `<text>`, `<style>`) is kept
/// verbatim so formatting never changes how the drawing looks.
String? formatSvg(String content) {
  final document = tryParseXml(content);
  if (document == null) return null;
  return document.toXmlString(
    pretty: true,
    indent: '  ',
    preserveWhitespace: (node) =>
        node is XmlElement && _whitespaceSensitive.contains(node.localName),
  );
}
