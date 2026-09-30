import 'package:xml/xml.dart';

import 'css.dart';
import 'xml_support.dart';

/// CSS properties that SVG also accepts as presentation attributes.
const _presentationProperties = {
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-width',
  'stroke-opacity',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-miterlimit',
  'opacity',
  'display',
  'visibility',
  'color',
  'stop-color',
  'stop-opacity',
  'flood-color',
  'flood-opacity',
  'clip-path',
  'clip-rule',
  'mask',
  'filter',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'text-anchor',
  'dominant-baseline',
  'letter-spacing',
};

/// Converts stylesheet rules and `style` attributes into presentation
/// attributes, for renderers without CSS support (flutter_svg).
///
/// Supports type, class, id, attribute, `*` and `:root` selectors combined
/// with descendant/child combinators, ordered by specificity. Rules with
/// other pseudo-classes, at-rules and custom properties are ignored. The
/// result is meant for display only.
class SvgCssInliner {
  const SvgCssInliner._();

  static String inline(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    final styles = [
      root,
      ...root.descendantElements,
    ].where((element) => element.localName == 'style').toList();
    final hasStyleAttributes = [
      root,
      ...root.descendantElements,
    ].any((element) => element.getAttribute('style') != null);
    if (styles.isEmpty && !hasStyleAttributes) return svg;

    final rules = <_Rule>[];
    var order = 0;
    for (final style in styles) {
      var css = styleText(style);
      for (final atRule in const ['media', 'keyframes', 'font-face', 'supports', 'import']) {
        css = removeAtRules(css, atRule);
      }
      css = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      for (final match in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css)) {
        final declarations = _declarations(match.group(2)!);
        if (declarations.isEmpty) continue;
        for (final raw in match.group(1)!.split(',')) {
          final selector = _Selector.tryParse(raw.trim());
          if (selector != null) rules.add(_Rule(selector, declarations, order++));
        }
      }
      style.remove();
    }
    rules.sort((a, b) {
      final bySpecificity = a.selector.specificity.compareTo(b.selector.specificity);
      return bySpecificity != 0 ? bySpecificity : a.order.compareTo(b.order);
    });

    for (final element in [root, ...root.descendantElements]) {
      final computed = <String, String>{};
      for (final rule in rules) {
        if (rule.selector.matches(element)) computed.addAll(rule.declarations);
      }
      computed.addAll(_declarations(element.getAttribute('style') ?? ''));
      computed.forEach(element.setAttribute);
    }
    return document.toXmlString();
  }

  static Map<String, String> _declarations(String block) {
    final result = <String, String>{};
    mapDeclarations(block, (property, value) {
      final trimmed = value.replaceAll(RegExp(r'\s*!important\s*$'), '').trim();
      if (_presentationProperties.contains(property) &&
          trimmed.isNotEmpty &&
          !trimmed.contains('var(')) {
        result[property] = trimmed;
      }
      return value;
    });
    return result;
  }
}

class _Rule {
  _Rule(this.selector, this.declarations, this.order);

  final _Selector selector;
  final Map<String, String> declarations;
  final int order;
}

/// One compound selector such as `rect.bg#a[fill]`.
class _Compound {
  _Compound({
    this.tag,
    this.id,
    this.classes = const [],
    this.attributes = const [],
    this.isRoot = false,
  });

  final String? tag;
  final String? id;
  final List<String> classes;
  final List<(String, String?)> attributes;
  final bool isRoot;

  static final _part = RegExp(
    r'''([.#])([\w-]+)|\[\s*([\w:-]+)\s*(?:=\s*["']?([^"'\]]*)["']?)?\s*\]|(:root)|(\*)|([a-zA-Z][\w-]*)''',
  );

  static _Compound? tryParse(String text) {
    String? tag;
    String? id;
    final classes = <String>[];
    final attributes = <(String, String?)>[];
    var isRoot = false;
    var consumed = 0;
    for (final match in _part.allMatches(text)) {
      if (match.start != consumed) return null;
      consumed = match.end;
      if (match.group(1) == '.') {
        classes.add(match.group(2)!);
      } else if (match.group(1) == '#') {
        id = match.group(2);
      } else if (match.group(3) != null) {
        attributes.add((match.group(3)!, match.group(4)));
      } else if (match.group(5) != null) {
        isRoot = true;
      } else if (match.group(7) != null) {
        tag = match.group(7);
      }
    }
    if (consumed != text.length || text.isEmpty) return null;
    return _Compound(tag: tag, id: id, classes: classes, attributes: attributes, isRoot: isRoot);
  }

  int get specificity =>
      (id == null ? 0 : 10000) +
      (classes.length + attributes.length + (isRoot ? 1 : 0)) * 100 +
      (tag == null ? 0 : 1);

  bool matches(XmlElement element) {
    if (tag != null && element.localName != tag) return false;
    if (id != null && element.getAttribute('id') != id) return false;
    if (isRoot && element.parentElement != null) return false;
    if (classes.isNotEmpty) {
      final own = (element.getAttribute('class') ?? '').split(RegExp(r'\s+')).toSet();
      if (!classes.every(own.contains)) return false;
    }
    for (final (name, value) in attributes) {
      final actual = element.getAttribute(name);
      if (actual == null || (value != null && actual != value)) return false;
    }
    return true;
  }
}

/// Compounds joined by descendant (` `) or child (`>`) combinators.
class _Selector {
  _Selector(this.parts, this.childCombinators);

  final List<_Compound> parts;

  /// `childCombinators[i]` is true when parts[i] and parts[i+1] are joined
  /// by `>`.
  final List<bool> childCombinators;

  int get specificity => parts.fold(0, (sum, part) => sum + part.specificity);

  static _Selector? tryParse(String text) {
    if (text.isEmpty) return null;
    final tokens = text.replaceAll('>', ' > ').trim().split(RegExp(r'\s+'));
    final parts = <_Compound>[];
    final child = <bool>[];
    var pendingChild = false;
    for (final token in tokens) {
      if (token == '>') {
        if (parts.isEmpty) return null;
        pendingChild = true;
        continue;
      }
      final compound = _Compound.tryParse(token);
      if (compound == null) return null;
      if (parts.isNotEmpty) child.add(pendingChild);
      pendingChild = false;
      parts.add(compound);
    }
    return parts.isEmpty ? null : _Selector(parts, child);
  }

  bool matches(XmlElement element) => _matchFrom(element, parts.length - 1);

  bool _matchFrom(XmlElement element, int index) {
    if (!parts[index].matches(element)) return false;
    if (index == 0) return true;
    var ancestor = element.parentElement;
    if (childCombinators[index - 1]) {
      return ancestor != null && _matchFrom(ancestor, index - 1);
    }
    while (ancestor != null) {
      if (_matchFrom(ancestor, index - 1)) return true;
      ancestor = ancestor.parentElement;
    }
    return false;
  }
}
