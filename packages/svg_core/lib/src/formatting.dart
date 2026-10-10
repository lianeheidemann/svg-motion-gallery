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
/// `,` `;` or `}` and in the text of `<title>` and `<desc>`. Each continuation
/// line keeps the indent of the line it came from, so it stays aligned. The drawing is the
/// same; only whitespace between tokens changes.
String wrapSvgLines(String content, int maxColumns) {
  if (maxColumns < 20) return content;
  final out = <String>[];
  var inTag = false;
  String? quote;
  // Whether the quoted value being read may be broken at its spaces.
  var quotedBreaks = false;
  // Name of the tag being read, and whether the text now being read belongs to
  // a `<title>` or `<desc>`, where a space may become a line break.
  var tagName = StringBuffer();
  var readingName = false;
  var proseText = false;
  for (final line in content.split('\n')) {
    final lead = line.length - line.trimLeft().length;
    // Where a break is allowed, found with the state at each position.
    final breakable = List<bool>.filled(line.length, false);
    final css = line.contains('{');
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else if (c == ' ' && quotedBreaks) {
          breakable[i] = true;
        }
        continue;
      }
      if (inTag) {
        if (readingName) {
          if (c == ' ' || c == '>' || c == '/') {
            readingName = false;
          } else {
            tagName.write(c);
          }
        }
        if (c == '"' || c == "'") {
          quote = c;
          quotedBreaks = _spaceFreeAttributes.contains(_attributeBefore(line, i));
        } else if (c == '>') {
          inTag = false;
          final name = tagName.toString();
          proseText = (name == 'title' || name == 'desc') && line[i - 1] != '/';
        } else if (c == ' ') {
          breakable[i] = true;
        }
      } else if (c == '<') {
        inTag = true;
        proseText = false;
        readingName = true;
        tagName = StringBuffer();
      } else if (proseText && c == ' ' && i > lead) {
        breakable[i] = true;
      } else if (css && c == ' ' && i > 0 && ',;}'.contains(line[i - 1])) {
        breakable[i] = true;
      }
    }
    if (line.length <= maxColumns) {
      out.add(line);
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    // Broken lines keep the indent of the line they come from.
    final prefix = ' ' * indent;
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

/// Attributes whose value reads the same with any run of spaces, so a long one
/// can be broken (the next line starts with the line's indent).
const _spaceFreeAttributes = {
  'style',
  'd',
  'points',
  'transform',
  'viewbox',
  'values',
  'keytimes',
  'keysplines',
  'begin',
  'end',
};

/// The lower-cased name of the attribute whose value opens at [quote] in
/// [line] (the word before the `=`), or '' when there is none.
String _attributeBefore(String line, int quote) {
  var i = quote - 1;
  while (i >= 0 && line[i] == ' ') {
    i--;
  }
  if (i < 0 || line[i] != '=') return '';
  i--;
  while (i >= 0 && line[i] == ' ') {
    i--;
  }
  final end = i + 1;
  while (i >= 0 && RegExp(r'[A-Za-z0-9:_-]').hasMatch(line[i])) {
    i--;
  }
  return line.substring(i + 1, end).toLowerCase();
}
