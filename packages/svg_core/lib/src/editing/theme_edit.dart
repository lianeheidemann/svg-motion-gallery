import 'package:xml/xml.dart';

import '../colors.dart';
import '../css.dart';
import '../theme/color_scheme.dart';
import '../theme/theme_resolver.dart';
import '../theme/theme_support.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Editing one variant (light or dark) of an SVG that changes with
/// `@media (prefers-color-scheme)`, leaving the other one as it was.
///
/// A shape's color for one variant is kept in a managed `<style
/// data-sm-theme>` block, keyed by a `data-sm-t` number on the shape:
/// `@media (prefers-color-scheme: light){[data-sm-t="3"]{fill:#abc !important}}`.
/// Both variants are always written, so the other one keeps what it showed.
class SvgThemeEdit {
  const SvgThemeEdit._();

  static const _attribute = 'data-sm-t';
  static const _marker = 'data-sm-theme';

  /// Whether [svg] has light and dark versions in its code that can be edited
  /// one at a time.
  static bool canEdit(String svg) => SvgThemeSupport.detect(svg).uses(SvgThemeMechanism.mediaQuery);

  /// The paint of the element at [path] in the [scheme] variant: `#RRGGBB`
  /// for a plain color, otherwise the raw value (`url(#a)`, `none`); null
  /// when nothing sets one. Looks at the element's inline style, the
  /// stylesheet rules that apply in that variant, its attribute, then its
  /// ancestors.
  static String? fillFor(String svg, ElementPath path, SvgColorScheme scheme) {
    final document = tryParseSvg(SvgThemeResolver.resolve(svg, scheme));
    var element = _target(document, path);
    if (document == null || element == null) return null;
    final rules = _rules(document.rootElement);
    while (element != null) {
      final value = _fillOf(element, rules);
      if (value != null) return SvgColorValue.normalize(value) ?? value.trim();
      element = element.parentElement;
    }
    return null;
  }

  /// Sets the fill of the element at [path] to [color] in the [scheme] variant
  /// only; the other variant keeps the paint it has now.
  static String setFill(String svg, ElementPath path, String color, SvgColorScheme scheme) {
    final keep = fillFor(svg, path, scheme.opposite) ?? '#000000';
    final document = tryParseSvg(svg);
    final element = _target(document, path);
    if (document == null || element == null) return svg;
    final root = document.rootElement;

    final id = element.getAttribute(_attribute) ?? _nextId(root);
    element.setAttribute(_attribute, id);
    final style = element.getAttribute('style');
    if (style != null) {
      final cleaned = mapDeclarations(style, (name, old) => name == 'fill' ? null : old);
      element.setAttribute('style', cleaned.trim().isEmpty ? null : cleaned);
    }

    final block = root.childElements.where((e) => e.getAttribute(_marker) != null).firstOrNull;
    final values = {for (final s in SvgColorScheme.values) s: <String, String>{}};
    if (block != null) {
      for (final rule in findAtRules(styleText(block), 'media')) {
        final text = styleText(block);
        final which = rule.prelude.contains('dark') ? SvgColorScheme.dark : SvgColorScheme.light;
        final inner = text.substring(rule.blockStart + 1, rule.blockEnd);
        for (final match in RegExp(
          r'\[data-sm-t="(\d+)"\]\s*\{\s*fill\s*:\s*([^;}!]+)',
        ).allMatches(inner)) {
          values[which]![match.group(1)!] = match.group(2)!.trim();
        }
      }
    }
    values[scheme]![id] = color;
    values[scheme.opposite]![id] = keep;

    final css = StringBuffer();
    for (final s in SvgColorScheme.values) {
      css.write('@media (prefers-color-scheme: ${s.name}){');
      for (final entry in values[s]!.entries) {
        css.write('[$_attribute="${entry.key}"]{fill:${entry.value} !important}');
      }
      css.write('}');
    }
    if (block != null) {
      setStyleText(block, css.toString());
    } else {
      root.children.add(
        buildElement('style', attributes: {_marker: ''}, children: [XmlText(css.toString())]),
      );
    }
    return document.toXmlString();
  }

  static XmlElement? _target(XmlDocument? document, ElementPath path) {
    if (document == null || path.isRoot) return null;
    final element = path.resolve(document.rootElement);
    return element == null ? null : unwrapEditorGroups(element);
  }

  static String _nextId(XmlElement root) {
    var highest = 0;
    for (final element in [root, ...root.descendantElements]) {
      final n = int.tryParse(element.getAttribute(_attribute) ?? '');
      if (n != null && n > highest) highest = n;
    }
    return '${highest + 1}';
  }

  static final _ruleText = RegExp(r'([^{}@;]+)\{([^{}]*)\}');
  static final _simple = RegExp(
    r'^([A-Za-z][\w-]*)?(?:\.([\w-]+))?(?:#([\w-]+))?(?:\[data-sm-t="(\d+)"\])?$',
  );

  /// The `fill` declarations of the simple rules of every `<style>`, in order.
  static List<(String, String)> _rules(XmlElement root) {
    final out = <(String, String)>[];
    for (final style in root.descendantElements.where((e) => e.localName == 'style')) {
      for (final match in _ruleText.allMatches(styleText(style))) {
        String? fill;
        mapDeclarations(match.group(2)!, (property, value) {
          if (property == 'fill') fill = value.replaceAll('!important', '').trim();
          return value;
        });
        if (fill == null) continue;
        for (final selector in match.group(1)!.split(',')) {
          out.add((selector.trim(), fill!));
        }
      }
    }
    return out;
  }

  static bool _matches(String selector, XmlElement element) {
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
    return key == null || element.getAttribute(_attribute) == key;
  }

  static String? _fillOf(XmlElement element, List<(String, String)> rules) {
    String? inline;
    mapDeclarations(element.getAttribute('style') ?? '', (name, value) {
      if (name == 'fill') inline = value.trim();
      return value;
    });
    if (inline != null) return inline;
    String? fromRule;
    for (final (selector, value) in rules) {
      if (_matches(selector, element)) fromRule = value;
    }
    return fromRule ?? element.getAttribute('fill');
  }
}
