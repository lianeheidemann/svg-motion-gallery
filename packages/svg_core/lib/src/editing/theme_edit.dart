import 'package:xml/xml.dart';

import '../colors.dart';
import '../css.dart';
import '../css_rules.dart';
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
  static String? fillFor(String svg, ElementPath path, SvgColorScheme scheme) =>
      paintFor(svg, path, scheme, 'fill');

  /// Same as [fillFor] for [property] (`fill` or `stroke`).
  static String? paintFor(String svg, ElementPath path, SvgColorScheme scheme, String property) {
    final document = tryParseSvg(SvgThemeResolver.resolve(svg, scheme));
    var element = _target(document, path);
    if (document == null || element == null) return null;
    final rules = simpleRules(document.rootElement, (p) => p == property);
    while (element != null) {
      final value = cssValueOf(element, rules, property);
      if (value != null) return SvgColorValue.normalize(value) ?? value.trim();
      element = element.parentElement;
    }
    return null;
  }

  /// Whether the element at [path] is drawn in the [scheme] variant (not
  /// hidden with `display:none`, itself or through an ancestor).
  static bool isShown(String svg, ElementPath path, SvgColorScheme scheme) =>
      _shownIn(_resolved(svg, scheme), path);

  /// The element standing for [path] when the file is switched from [from] to
  /// [to]: [path] itself when it is drawn in [to] too, else the sibling that
  /// is hidden in [from] and drawn in [to] (a "night" group and its "day"
  /// twin), the nearest one. [path] again when there is none.
  static ElementPath counterpart(
    String svg,
    ElementPath path,
    SvgColorScheme from,
    SvgColorScheme to,
  ) {
    final parent = path.parent;
    if (parent == null || path.isRoot) return path;
    final inFrom = _resolved(svg, from);
    final inTo = _resolved(svg, to);
    if (_shownIn(inTo, path)) return path;
    final holder = inTo == null ? null : parent.resolve(inTo.rootElement);
    final count = parent.isRoot
        ? inTo?.rootElement.childElements.length
        : holder?.childElements.length;
    if (count == null) return path;
    final own = path.indices.last;
    ElementPath? best;
    for (var i = 0; i < count; i++) {
      if (i == own) continue;
      final sibling = parent.child(i);
      if (_shownIn(inFrom, sibling) || !_shownIn(inTo, sibling)) continue;
      if (best == null || (i - own).abs() < (best.indices.last - own).abs()) best = sibling;
    }
    return best ?? path;
  }

  static XmlDocument? _resolved(String svg, SvgColorScheme scheme) =>
      tryParseSvg(SvgThemeResolver.resolve(svg, scheme));

  static bool _shownIn(XmlDocument? document, ElementPath path) {
    if (document == null) return true;
    var element = path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return true;
    final rules = simpleRules(document.rootElement, (p) => p == 'display');
    while (element != null) {
      final value = cssValueOf(element, rules, 'display');
      if (value != null && value.trim() == 'none') return false;
      element = element.parentElement;
    }
    return true;
  }

  /// Sets the fill of the element at [path] to [color] in the [scheme] variant
  /// only; the other variant keeps the paint it has now.
  static String setFill(String svg, ElementPath path, String color, SvgColorScheme scheme) =>
      setPaint(svg, path, color, scheme, 'fill');

  /// Same as [setFill] for [property] (`fill` or `stroke`).
  static String setPaint(
    String svg,
    ElementPath path,
    String color,
    SvgColorScheme scheme,
    String property,
  ) {
    final keep = paintFor(svg, path, scheme.opposite, property) ?? '#000000';
    final document = tryParseSvg(svg);
    final element = _target(document, path);
    if (document == null || element == null) return svg;
    final root = document.rootElement;

    final id = element.getAttribute(_attribute) ?? _nextId(root);
    element.setAttribute(_attribute, id);
    final style = element.getAttribute('style');
    if (style != null) {
      final cleaned = mapDeclarations(style, (name, old) => name == property ? null : old);
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
          r'\[data-sm-t="(\d+)"\]\s*\{\s*(fill|stroke)\s*:\s*([^;}!]+)',
        ).allMatches(inner)) {
          values[which]!['${match.group(2)}|${match.group(1)}'] = match.group(3)!.trim();
        }
      }
    }
    values[scheme]!['$property|$id'] = color;
    values[scheme.opposite]!['$property|$id'] = keep;

    final css = StringBuffer();
    for (final s in SvgColorScheme.values) {
      css.write('@media (prefers-color-scheme: ${s.name}){');
      for (final entry in values[s]!.entries) {
        final parts = entry.key.split('|');
        css.write('[$_attribute="${parts[1]}"]{${parts[0]}:${entry.value} !important}');
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
}
