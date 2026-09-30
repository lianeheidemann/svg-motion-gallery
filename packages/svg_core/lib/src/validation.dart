import 'package:xml/xml.dart';

/// Why an SVG document is not valid. The app maps each code to a
/// translated message, so this package never returns user-facing text.
enum SvgIssueCode {
  /// The document is empty or only whitespace.
  empty,

  /// The text is not well-formed XML (see [SvgIssue.detail]).
  malformedXml,

  /// The XML is fine but its root element is not `<svg>`.
  rootNotSvg,
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
  const SvgValidation.valid() : issue = null;
  const SvgValidation.invalid(SvgIssue this.issue);

  final SvgIssue? issue;

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
    return const SvgValidation.valid();
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
