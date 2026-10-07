import 'dart:math' as math;

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

/// Breaks lines longer than [maxColumns] at places where whitespace does not
/// matter: between the attributes of a tag and, in style sheets, after a
/// `,` `;` or `}`. Each continuation line is indented two spaces more than the
/// line it came from, so the structure stays readable. The drawing is the
/// same; only whitespace between tokens changes.
String wrapSvgLines(String content, int maxColumns) {
  if (maxColumns < 20) return content;
  final out = <String>[];
  var inTag = false;
  String? quote;
  for (final line in content.split('\n')) {
    // Where a break is allowed, found with the state at each position.
    final breakable = List<bool>.filled(line.length, false);
    final css = line.contains('{');
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quote != null) {
        if (c == quote) quote = null;
        continue;
      }
      if (inTag) {
        if (c == '"' || c == "'") {
          quote = c;
        } else if (c == '>') {
          inTag = false;
        } else if (c == ' ') {
          breakable[i] = true;
        }
      } else if (c == '<') {
        inTag = true;
      } else if (css && c == ' ' && i > 0 && ',;}'.contains(line[i - 1])) {
        breakable[i] = true;
      }
    }
    if (line.length <= maxColumns) {
      out.add(line);
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    final prefix = ' ' * (indent + 2);
    var start = 0;
    while (true) {
      final room = start == 0 ? maxColumns : maxColumns - prefix.length;
      if (line.length - start <= room) {
        out.add((start == 0 ? '' : prefix) + line.substring(start));
        break;
      }
      var cut = -1;
      for (var i = math.min(start + room, line.length - 1); i > start; i--) {
        if (breakable[i]) {
          cut = i;
          break;
        }
      }
      if (cut < 0) {
        for (var i = start + room + 1; i < line.length; i++) {
          if (breakable[i]) {
            cut = i;
            break;
          }
        }
      }
      if (cut < 0) {
        out.add((start == 0 ? '' : prefix) + line.substring(start));
        break;
      }
      out.add((start == 0 ? '' : prefix) + line.substring(start, cut).trimRight());
      start = cut + 1;
    }
  }
  return out.join('\n');
}
