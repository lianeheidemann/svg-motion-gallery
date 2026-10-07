import 'package:xml/xml.dart';

import 'xml_support.dart';

/// Why an SVG document is not valid. The app maps each code to a
/// translated message, so this package never returns user-facing text.
enum SvgIssueCode {
  /// The document is empty or only whitespace.
  empty,

  /// The text is not well-formed XML (see [SvgIssue.detail]).
  malformedXml,

  /// The XML is fine but its root element is not `<svg>`.
  rootNotSvg,

  /// A `<style>` block has CSS that browsers will ignore or misread. Only
  /// ever reported as a [SvgValidation.warning]: the SVG is still valid.
  malformedCss,
}

/// A validation problem with its location (1-based) when known.
class SvgIssue {
  const SvgIssue(this.code, {this.detail, this.line, this.column});

  final SvgIssueCode code;

  /// Parser message (English, technical). Shown as secondary information.
  final String? detail;
  final int? line;
  final int? column;

  @override
  String toString() => 'SvgIssue($code, $detail, $line:$column)';
}

/// Result of [validateSvg].
class SvgValidation {
  const SvgValidation.valid({this.warning}) : issue = null;
  const SvgValidation.invalid(SvgIssue this.issue) : warning = null;

  final SvgIssue? issue;

  /// Something worth telling the user although the document is [isValid].
  final SvgIssue? warning;

  bool get isValid => issue == null;
}

/// Checks that [content] is a well-formed XML document with an `<svg>` root.
SvgValidation validateSvg(String content) {
  if (content.trim().isEmpty) {
    return const SvgValidation.invalid(SvgIssue(SvgIssueCode.empty));
  }
  try {
    final document = XmlDocument.parse(content);
    if (document.rootElement.localName != 'svg') {
      return const SvgValidation.invalid(SvgIssue(SvgIssueCode.rootNotSvg));
    }
    return SvgValidation.valid(warning: _cssWarning(document, content));
  } on XmlException catch (error) {
    final located = error is XmlFormatException ? error as XmlFormatException : null;
    final line = located?.line;
    return SvgValidation.invalid(
      SvgIssue(
        SvgIssueCode.malformedXml,
        detail: error.message,
        line: line == null || line == 0 ? null : line,
        column: line == null || line == 0 ? null : located?.column,
      ),
    );
  }
}

/// The first `<style>` problem, or null. Browsers drop bad CSS silently, so
/// this is what tells the user that something they typed is being ignored.
SvgIssue? _cssWarning(XmlDocument document, String content) {
  for (final style in document.rootElement.descendantElements.where(
    (e) => e.localName == 'style',
  )) {
    final snippet = _cssProblem(styleText(style));
    if (snippet == null) continue;
    final at = snippet.length > 1 ? content.indexOf(snippet) : -1;
    final line = at < 0 ? null : '\n'.allMatches(content.substring(0, at)).length + 1;
    final shown = snippet.length > 40 ? '${snippet.substring(0, 40)}…' : snippet;
    return SvgIssue(SvgIssueCode.malformedCss, detail: shown, line: line);
  }
  return null;
}

/// Text of the first CSS construct that is clearly broken, else null.
/// Deliberately conservative: only unterminated comments/strings, unbalanced
/// braces or parentheses, and declarations without `property: value`.
String? _cssProblem(String css) {
  // Remove comments and blank out string contents.
  final clean = StringBuffer();
  var i = 0;
  while (i < css.length) {
    final c = css[i];
    if (css.startsWith('/*', i)) {
      final end = css.indexOf('*/', i + 2);
      if (end < 0) return css.substring(i).trim();
      i = end + 2;
    } else if (c == '"' || c == "'") {
      var j = i + 1;
      while (j < css.length && css[j] != c && css[j] != '\n') {
        j += css[j] == '\\' ? 2 : 1;
      }
      if (j >= css.length || css[j] != c) {
        return css.substring(i, css.length < i + 30 ? css.length : i + 30).trim();
      }
      clean.write('""');
      i = j + 1;
    } else {
      clean.write(c);
      i++;
    }
  }
  final text = clean.toString();

  var depth = 0;
  for (var k = 0; k < text.length; k++) {
    if (text[k] == '{') depth++;
    if (text[k] == '}') {
      depth--;
      if (depth < 0) return '}';
    }
  }
  if (depth != 0) return '{';

  for (final block in RegExp(r'\{([^{}]*)\}').allMatches(text)) {
    for (final declaration in _splitDeclarations(block.group(1)!)) {
      final trimmed = declaration.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      final property = colon < 0 ? '' : trimmed.substring(0, colon).trim();
      final value = colon < 0 ? '' : trimmed.substring(colon + 1).trim();
      final opens = '('.allMatches(value).length;
      final closes = ')'.allMatches(value).length;
      if (!RegExp(r'^-{0,2}[A-Za-z_][\w-]*$').hasMatch(property) ||
          value.isEmpty ||
          opens != closes) {
        return trimmed;
      }
    }
  }
  return null;
}

/// Splits on `;` outside parentheses (so `url(data:...;base64,...)` is whole).
List<String> _splitDeclarations(String block) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < block.length; i++) {
    final c = block[i];
    if (c == '(') depth++;
    if (c == ')' && depth > 0) depth--;
    if (c == ';' && depth == 0) {
      parts.add(block.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(block.substring(start));
  return parts;
}
