/// Syntax categories produced by [tokenizeSvg].
enum SvgTokenType { text, comment, tag, punctuation, attribute, value, entity }

/// A highlighted range of the source (`start` inclusive, `end` exclusive).
class SvgToken {
  const SvgToken(this.type, this.start, this.end);

  final SvgTokenType type;
  final int start;
  final int end;

  @override
  String toString() => '$type[$start,$end)';
}

final _pattern = RegExp(
  r'(<!--[\s\S]*?(?:-->|$))' // 1 comment
  r'|(<!\[CDATA\[[\s\S]*?(?:\]\]>|$))' // 2 cdata
  r'|(<[?!][^>]*>?)' // 3 <?xml ?> / <!DOCTYPE>
  r'|(</?)([A-Za-z_][\w:.-]*)' // 4-5 tag open + name
  r'|(/?>)' // 6 tag end
  r'|([A-Za-z_][\w:.-]*)(?=\s*=)' // 7 attribute name
  r'|(=)' // 8
  r'''|("[^"]*"?|'[^']*'?)''' // 9 attribute value
  r'|(&#?\w+;)', // 10 entity
);

/// Above this length highlighting is skipped to keep the editor responsive.
const maxHighlightLength = 200000;

/// Splits SVG/XML [source] into typed tokens that cover it completely and in
/// order, so concatenating the ranges gives back [source].
List<SvgToken> tokenizeSvg(String source) {
  if (source.length > maxHighlightLength) {
    return [SvgToken(SvgTokenType.text, 0, source.length)];
  }
  final tokens = <SvgToken>[];
  var inTag = false;
  var last = 0;

  void add(SvgTokenType type, int start, int end) {
    if (end > start) tokens.add(SvgToken(type, start, end));
  }

  for (final match in _pattern.allMatches(source)) {
    add(SvgTokenType.text, last, match.start);
    last = match.end;
    if (match[1] != null || match[2] != null || match[3] != null) {
      add(SvgTokenType.comment, match.start, match.end);
    } else if (match[4] != null) {
      final nameStart = match.start + match[4]!.length;
      add(SvgTokenType.punctuation, match.start, nameStart);
      add(SvgTokenType.tag, nameStart, match.end);
      inTag = true;
    } else if (match[6] != null) {
      add(inTag ? SvgTokenType.punctuation : SvgTokenType.text, match.start, match.end);
      inTag = false;
    } else if (match[7] != null) {
      add(inTag ? SvgTokenType.attribute : SvgTokenType.text, match.start, match.end);
    } else if (match[8] != null) {
      add(inTag ? SvgTokenType.punctuation : SvgTokenType.text, match.start, match.end);
    } else if (match[9] != null) {
      add(inTag ? SvgTokenType.value : SvgTokenType.text, match.start, match.end);
    } else {
      add(SvgTokenType.entity, match.start, match.end);
    }
  }
  add(SvgTokenType.text, last, source.length);
  return tokens;
}
