/// Small, dependency-free CSS helpers. They understand comments, strings,
/// nested blocks and nested parentheses, which is all the SVG tooling needs;
/// they are not a general CSS parser.
library;

/// An at-rule such as `@media (...) { ... }` found in a stylesheet.
class CssAtRule {
  const CssAtRule({
    required this.start,
    required this.prelude,
    required this.blockStart,
    required this.blockEnd,
  });

  /// Index of the `@`.
  final int start;

  /// Text between the at-keyword and the `{`.
  final String prelude;

  /// Index of the opening `{`.
  final int blockStart;

  /// Index of the matching `}`.
  final int blockEnd;
}

/// Returns the index right after a comment or string starting at [i], or -1
/// when [i] does not start one.
int _skipOpaque(String css, int i) {
  final char = css[i];
  if (char == '/' && i + 1 < css.length && css[i + 1] == '*') {
    final end = css.indexOf('*/', i + 2);
    return end == -1 ? css.length : end + 2;
  }
  if (char == '"' || char == "'") {
    var j = i + 1;
    while (j < css.length && css[j] != char) {
      if (css[j] == r'\') j++;
      j++;
    }
    return j < css.length ? j + 1 : css.length;
  }
  return -1;
}

/// Index of the `}` matching the `{` at [open], or the end of [css].
int matchingBrace(String css, int open) {
  var depth = 0;
  var i = open;
  while (i < css.length) {
    final skipped = _skipOpaque(css, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    final char = css[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return css.length - 1;
}

/// Finds top-level (not nested inside other blocks) at-rules whose keyword
/// matches [name], e.g. `media` or `keyframes`. Vendor prefixes such as
/// `@-webkit-keyframes` also match.
List<CssAtRule> findAtRules(String css, String name) {
  final keyword = RegExp('@(?:-[a-z]+-)?$name(?![\\w-])', caseSensitive: false);
  final rules = <CssAtRule>[];
  var depth = 0;
  var i = 0;
  while (i < css.length) {
    final skipped = _skipOpaque(css, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    final char = css[i];
    if (char == '{') depth++;
    if (char == '}') depth--;
    if (char == '@' && depth == 0) {
      final match = keyword.matchAsPrefix(css, i);
      if (match != null) {
        final open = _indexOfTopLevel(css, '{', match.end, stopAt: ';');
        if (open != -1) {
          final close = matchingBrace(css, open);
          rules.add(
            CssAtRule(
              start: i,
              prelude: css.substring(match.end, open),
              blockStart: open,
              blockEnd: close,
            ),
          );
          i = close + 1;
          continue;
        }
      }
    }
    i++;
  }
  return rules;
}

int _indexOfTopLevel(String css, String target, int from, {String? stopAt}) {
  var i = from;
  while (i < css.length) {
    final skipped = _skipOpaque(css, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    if (css[i] == target) return i;
    if (stopAt != null && css[i] == stopAt) return -1;
    i++;
  }
  return -1;
}

/// Removes every at-rule named [name] (including its block).
String removeAtRules(String css, String name) {
  final rules = findAtRules(css, name);
  if (rules.isEmpty) return css;
  final buffer = StringBuffer();
  var last = 0;
  for (final rule in rules) {
    buffer.write(css.substring(last, rule.start));
    last = rule.blockEnd + 1;
  }
  buffer.write(css.substring(last));
  return buffer.toString();
}

/// Calls [transform] with the contents of every innermost `{ ... }` block,
/// i.e. every declaration list of a stylesheet, and splices the result back.
String mapDeclarationBlocks(String css, String Function(String block) transform) {
  final ranges = <(int, int)>[];
  final stack = <(int, bool)>[];
  var i = 0;
  while (i < css.length) {
    final skipped = _skipOpaque(css, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    final char = css[i];
    if (char == '{') {
      if (stack.isNotEmpty) stack[stack.length - 1] = (stack.last.$1, true);
      stack.add((i, false));
    } else if (char == '}' && stack.isNotEmpty) {
      final (open, hasChildBlock) = stack.removeLast();
      if (!hasChildBlock) ranges.add((open + 1, i));
    }
    i++;
  }
  if (ranges.isEmpty) return css;
  final buffer = StringBuffer();
  var last = 0;
  for (final (start, end) in ranges) {
    buffer
      ..write(css.substring(last, start))
      ..write(transform(css.substring(start, end)));
    last = end;
  }
  buffer.write(css.substring(last));
  return buffer.toString();
}

/// Splits [text] on [separator] characters that are not inside parentheses,
/// strings or comments.
List<String> splitTopLevel(String text, String separator) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  var i = 0;
  while (i < text.length) {
    final skipped = _skipOpaque(text, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    final char = text[i];
    if (char == '(') depth++;
    if (char == ')') depth--;
    if (char == separator && depth == 0) {
      parts.add(text.substring(start, i));
      start = i + 1;
    }
    i++;
  }
  parts.add(text.substring(start));
  return parts;
}

/// Rewrites the declarations of a declaration list (a `style` attribute or
/// the inside of a rule). [transform] receives the lower-cased property name
/// and the raw value; it returns the new value, or null to drop the
/// declaration. Formatting of untouched declarations is preserved.
String mapDeclarations(String block, String? Function(String property, String value) transform) {
  final pieces = splitTopLevel(block, ';');
  final output = <String>[];
  var changed = false;
  for (final piece in pieces) {
    final colon = piece.indexOf(':');
    if (colon == -1 || piece.trim().isEmpty) {
      output.add(piece);
      continue;
    }
    final property = piece.substring(0, colon).trim().toLowerCase();
    final value = piece.substring(colon + 1);
    final next = transform(property, value);
    if (next == null) {
      changed = true;
      continue;
    }
    if (next != value) changed = true;
    output.add('${piece.substring(0, colon + 1)}$next');
  }
  if (!changed) return block;
  final joined = output.join(';');
  return joined.trim().isEmpty ? '' : joined;
}

/// Applies [mapDeclarations] to every declaration list of a full stylesheet.
String mapStylesheetDeclarations(
  String css,
  String? Function(String property, String value) transform,
) => mapDeclarationBlocks(css, (block) => mapDeclarations(block, transform));

/// Replaces calls to the CSS function [name] (e.g. `light-dark`) with the
/// value returned by [replace], which receives the trimmed arguments. Nested
/// calls inside the arguments are replaced first.
String replaceCssFunction(String text, String name, String Function(List<String> args) replace) {
  final pattern = RegExp('(?<![\\w-])$name\\s*\\(', caseSensitive: false);
  final buffer = StringBuffer();
  var last = 0;
  var searchFrom = 0;
  while (true) {
    final match = pattern.allMatches(text, searchFrom).firstOrNull;
    if (match == null) break;
    final start = match.start;
    final open = match.end - 1;
    final close = _matchingParen(text, open);
    if (close == -1) break;
    final args = splitTopLevel(
      text.substring(open + 1, close),
      ',',
    ).map((arg) => replaceCssFunction(arg, name, replace).trim()).toList();
    buffer
      ..write(text.substring(last, start))
      ..write(replace(args));
    last = close + 1;
    searchFrom = close + 1;
  }
  if (last == 0) return text;
  buffer.write(text.substring(last));
  return buffer.toString();
}

int _matchingParen(String text, int open) {
  var depth = 0;
  var i = open;
  while (i < text.length) {
    final skipped = _skipOpaque(text, i);
    if (skipped != -1) {
      i = skipped;
      continue;
    }
    if (text[i] == '(') depth++;
    if (text[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

final _timeToken = RegExp(r'(?<![\w.#-])(\d*\.?\d+)(ms|s)(?![\w-])', caseSensitive: false);

/// All CSS time values (`2s`, `150ms`) in [value], converted to seconds.
Iterable<double> cssTimes(String value) sync* {
  for (final match in _timeToken.allMatches(value)) {
    final number = double.parse(match.group(1)!);
    yield match.group(2)!.toLowerCase() == 'ms' ? number / 1000 : number;
  }
}

/// Multiplies every CSS time value in [value] by [factor].
String scaleCssTimes(String value, double factor) => value.replaceAllMapped(_timeToken, (match) {
  final number = double.parse(match.group(1)!) * factor;
  final unit = match.group(2)!;
  var text = number.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '$text$unit';
});
