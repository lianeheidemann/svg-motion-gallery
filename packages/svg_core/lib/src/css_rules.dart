import 'package:xml/xml.dart';

import 'css.dart';
import 'xml_support.dart';

/// A rule of a `<style>` block, split per selector (`a, b {...}` gives two).
class CssRule {
  const CssRule(this.selector, this.declarations);

  final String selector;

  /// Lower-cased property → raw value (trimmed, `!important` kept).
  final Map<String, String> declarations;

  /// Whether [element] is matched by [selector] (simple selectors only, see
  /// [matchesSimpleSelector]).
  bool matches(XmlElement element) => matchesSimpleSelector(selector, element);
}

final _ruleText = RegExp(r'([^{}@;]+)\{([^{}]*)\}');

/// The rules of every `<style>` under [root], in document order, keeping the
/// declarations whose property passes [keep]. Rules left with nothing are
/// dropped. Only plain `selector{...}` blocks are read (at-rules are not
/// entered), which is what the editor's lookups need.
List<CssRule> simpleRules(XmlElement root, bool Function(String property) keep) {
  final rules = <CssRule>[];
  for (final style in root.descendantElements.where((e) => e.localName == 'style')) {
    for (final match in _ruleText.allMatches(styleText(style))) {
      final declarations = <String, String>{};
      mapDeclarations(match.group(2)!, (property, value) {
        if (keep(property)) declarations[property] = value.trim();
        return value;
      });
      if (declarations.isEmpty) continue;
      for (final selector in match.group(1)!.split(',')) {
        rules.add(CssRule(selector.trim(), declarations));
      }
    }
  }
  return rules;
}

final _simple = RegExp(
  r'^([A-Za-z][\w-]*)?(?:\.([\w-]+))?(?:#([\w-]+))?(?:\[data-sm-t="(\d+)"\])?$',
);

/// Whether [element] is matched by [selector] when it is a simple one: a tag,
/// a `.class`, an `#id` and/or the editor's `[data-sm-t="n"]`, in that order
/// (`rect.bg`, `#sun`, `.a`). Anything else (combinators, pseudo-classes)
/// never matches.
bool matchesSimpleSelector(String selector, XmlElement element) {
  final match = _simple.firstMatch(selector);
  if (match == null || selector.isEmpty) return false;
  final tag = match.group(1);
  final cls = match.group(2);
  final id = match.group(3);
  final key = match.group(4);
  if (tag != null && tag != element.localName) return false;
  if (cls != null && !(element.getAttribute('class') ?? '').split(RegExp(r'\s+')).contains(cls)) {
    return false;
  }
  if (id != null && element.getAttribute('id') != id) return false;
  return key == null || element.getAttribute('data-sm-t') == key;
}

/// The value of [property] on [element]: its inline `style`, else the last
/// matching rule of [rules], else its attribute. `!important` is dropped.
/// Null when none of them sets it (ancestors are not looked at).
String? cssValueOf(XmlElement element, List<CssRule> rules, String property) {
  String? inline;
  mapDeclarations(element.getAttribute('style') ?? '', (name, value) {
    if (name == property) inline = value.trim();
    return value;
  });
  if (inline != null) return inline;
  String? fromRule;
  for (final rule in rules) {
    final value = rule.declarations[property];
    if (value != null && rule.matches(element)) fromRule = value;
  }
  return fromRule?.replaceAll('!important', '').trim() ?? element.getAttribute(property);
}
