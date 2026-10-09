import 'highlighter.dart';
import 'validation.dart';

/// Attributes that hold a color.
const _colorAttributes = {'fill', 'stroke', 'stop-color', 'flood-color', 'lighting-color', 'color'};

/// Attributes that hold a length or a number (or a list of them).
const _numberAttributes = {
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'x',
  'y',
  'x1',
  'y1',
  'x2',
  'y2',
  'dx',
  'dy',
  'width',
  'height',
  'stroke-width',
  'opacity',
  'fill-opacity',
  'stroke-opacity',
  'stop-opacity',
};

/// CSS color names.
const _namedColors = {
  'aliceblue', 'antiquewhite', 'aqua', 'aquamarine', 'azure', 'beige', 'bisque', 'black',
  'blanchedalmond', 'blue', 'blueviolet', 'brown', 'burlywood', 'cadetblue', 'chartreuse',
  'chocolate', 'coral', 'cornflowerblue', 'cornsilk', 'crimson', 'cyan', 'darkblue', 'darkcyan',
  'darkgoldenrod', 'darkgray', 'darkgreen', 'darkgrey', 'darkkhaki', 'darkmagenta',
  'darkolivegreen', 'darkorange', 'darkorchid', 'darkred', 'darksalmon', 'darkseagreen',
  'darkslateblue', 'darkslategray', 'darkslategrey', 'darkturquoise', 'darkviolet', 'deeppink',
  'deepskyblue', 'dimgray', 'dimgrey', 'dodgerblue', 'firebrick', 'floralwhite', 'forestgreen',
  'fuchsia', 'gainsboro', 'ghostwhite', 'gold', 'goldenrod', 'gray', 'green', 'greenyellow',
  'grey', 'honeydew', 'hotpink', 'indianred', 'indigo', 'ivory', 'khaki', 'lavender',
  'lavenderblush', 'lawngreen', 'lemonchiffon', 'lightblue', 'lightcoral', 'lightcyan',
  'lightgoldenrodyellow', 'lightgray', 'lightgreen', 'lightgrey', 'lightpink', 'lightsalmon',
  'lightseagreen', 'lightskyblue', 'lightslategray', 'lightslategrey', 'lightsteelblue',
  'lightyellow', 'lime', 'limegreen', 'linen', 'magenta', 'maroon', 'mediumaquamarine',
  'mediumblue', 'mediumorchid', 'mediumpurple', 'mediumseagreen', 'mediumslateblue',
  'mediumspringgreen', 'mediumturquoise', 'mediumvioletred', 'midnightblue', 'mintcream',
  'mistyrose', 'moccasin', 'navajowhite', 'navy', 'oldlace', 'olive', 'olivedrab', 'orange',
  'orangered', 'orchid', 'palegoldenrod', 'palegreen', 'paleturquoise', 'palevioletred',
  'papayawhip', 'peachpuff', 'peru', 'pink', 'plum', 'powderblue', 'purple', 'rebeccapurple',
  'red', 'rosybrown', 'royalblue', 'saddlebrown', 'salmon', 'sandybrown', 'seagreen', 'seashell',
  'sienna', 'silver', 'skyblue', 'slateblue', 'slategray', 'slategrey', 'snow', 'springgreen',
  'steelblue', 'tan', 'teal', 'thistle', 'tomato', 'turquoise', 'violet', 'wheat', 'white',
  'whitesmoke', 'yellow', 'yellowgreen',
  // Keywords.
  'none', 'transparent', 'currentcolor', 'inherit', 'initial', 'unset', 'revert',
  'context-fill', 'context-stroke',
};

final _hex = RegExp(r'^#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$', caseSensitive: false);
final _number = RegExp(
  r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?(?:px|em|rem|ex|ch|%|pt|pc|mm|cm|in|q|vw|vh|vmin|vmax)?$',
  caseSensitive: false,
);

final _argbLike = RegExp(r'^#[fF]{2}[0-9a-fA-F]{4}(?!(?:[fF]{2})$)[0-9a-fA-F]{2}$');

/// Turns an Android-style `#AARRGGBB` color into the SVG `#RRGGBBAA`, or null
/// when [value] is not an 8-digit hex color.
String? svgArgbToRgba(String value) {
  final v = value.trim();
  if (!RegExp(r'^#[0-9a-fA-F]{8}$').hasMatch(v)) return null;
  return '#${v.substring(3)}${v.substring(1, 3)}';
}

/// Whether [value] is a color the browser understands. Anything written as a
/// function (`rgb(...)`, `url(...)`, `var(...)`) is trusted.
bool _isColor(String value) {
  final v = value.trim();
  if (v.isEmpty || v.contains('(') || v.contains('&')) return true;
  if (v.startsWith('#')) return _hex.hasMatch(v);
  return _namedColors.contains(v.toLowerCase());
}

/// Whether [value] is a number, a length, or a list of them.
bool _isNumeric(String value) {
  final v = value.trim();
  if (v.isEmpty || v.contains('(') || v.contains('&')) return true;
  const words = {'auto', 'inherit', 'initial', 'unset', 'revert', 'none', 'normal'};
  if (words.contains(v.toLowerCase())) return true;
  return v.split(RegExp(r'[\s,]+')).where((part) => part.isNotEmpty).every(_number.hasMatch);
}

/// Finds attribute values that are almost certainly mistakes: a color that is
/// not one (`#FFC----@83D`, `reed`) or a number that is not one (`r="abc"`).
/// The SVG is still valid XML, so these are hints, never errors.
///
/// It reads the tokens that [tokenizeSvg] already makes, so it costs one pass
/// over the text. Deliberately conservative: functions (`rgb()`, `url()`,
/// `var()`) and keywords are trusted. At most [limit] hints are returned.
List<SvgIssue> lintSvgValues(String source, {int limit = 50}) {
  final issues = <SvgIssue>[];
  final tokens = tokenizeSvg(source);
  var line = 1;
  var lineStart = 0;
  var scanned = 0;

  /// Moves the line counter up to [offset] (tokens come in order).
  void advance(int offset) {
    for (var i = scanned; i < offset; i++) {
      if (source.codeUnitAt(i) == 0x0A) {
        line++;
        lineStart = i + 1;
      }
    }
    scanned = offset;
  }

  String? attribute;
  for (var i = 0; i < tokens.length && issues.length < limit; i++) {
    final token = tokens[i];
    if (token.type == SvgTokenType.attribute) {
      attribute = source.substring(token.start, token.end).toLowerCase();
      continue;
    }
    if (token.type != SvgTokenType.value) continue;
    final name = attribute;
    attribute = null;
    if (name == null) continue;
    final isColor = _colorAttributes.contains(name);
    if (!isColor && !_numberAttributes.contains(name)) continue;

    final raw = source.substring(token.start, token.end);
    final quote = raw[0];
    // An unterminated value is the XML error's business.
    if (raw.length < 2 || raw[raw.length - 1] != quote) continue;
    final value = raw.substring(1, raw.length - 1);
    final argb = isColor && _argbLike.hasMatch(value.trim());
    if (!argb && (isColor ? _isColor(value) : _isNumeric(value))) continue;

    advance(token.start);
    issues.add(
      SvgIssue(
        argb ? SvgIssueCode.argbColor : SvgIssueCode.invalidValue,
        detail: value.trim(),
        attribute: name,
        line: line,
        column: token.start - lineStart + 1,
        start: token.start + 1,
        end: token.end - 1,
      ),
    );
  }
  return issues;
}

/// Where [issue] is in [source] (`start` inclusive, `end` exclusive), to
/// underline it; null when it has no location. For parser errors, which only
/// know a line and a column, the range is the word at that spot.
(int, int)? svgIssueRange(String source, SvgIssue issue) {
  final start = issue.start;
  final end = issue.end;
  if (start != null && end != null) return (start, end);
  final line = issue.line;
  if (line == null || line < 1) return null;

  var lineStart = 0;
  for (var n = 1; n < line; n++) {
    final next = source.indexOf('\n', lineStart);
    if (next < 0) return null;
    lineStart = next + 1;
  }
  var lineEnd = source.indexOf('\n', lineStart);
  if (lineEnd < 0) lineEnd = source.length;
  if (lineEnd == lineStart) return null;

  var at = lineStart + ((issue.column ?? 1) - 1).clamp(0, lineEnd - lineStart - 1);
  // CSS problems only know the line: underline all of it, without its indent.
  if (issue.column == null) {
    while (at < lineEnd - 1 && source[at].trim().isEmpty) {
      at++;
    }
    return (at, lineEnd);
  }
  var stop = at + 1;
  while (stop < lineEnd && !'<>"\' \t='.contains(source[stop])) {
    stop++;
  }
  return (at, stop);
}
