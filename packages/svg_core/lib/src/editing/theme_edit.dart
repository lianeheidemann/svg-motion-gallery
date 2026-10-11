import 'package:xml/xml.dart';

import '../colors.dart';
import '../css.dart';
import '../css_rules.dart';
import '../theme/color_scheme.dart';
import '../theme/theme_resolver.dart';
import '../theme/theme_support.dart';
import '../xml_support.dart';
import 'element_path.dart';
import 'theme_marks.dart';

/// Editing one variant (light or dark) of an SVG that changes with
/// `@media (prefers-color-scheme)`, leaving the other one as it was.
///
/// A shape's color (or whether it is drawn) for one variant is kept in a
/// managed `<style data-sm-theme>` block, keyed by a `data-sm-t` number on the
/// shape:
/// `@media (prefers-color-scheme: light){[data-sm-t="3"]{fill:#abc !important}}`.
/// A color is written for both variants, so the other one keeps what it
/// showed.
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
    return _editManaged(svg, path, (element, values, id) {
      final style = element.getAttribute('style');
      if (style != null) {
        final cleaned = mapDeclarations(style, (name, old) => name == property ? null : old);
        element.setAttribute('style', cleaned.trim().isEmpty ? null : cleaned);
      }
      values[scheme]!['$property|$id'] = color;
      values[scheme.opposite]!['$property|$id'] = keep;
    });
  }

  /// Whether the element at [path] itself is drawn in the [scheme] variant,
  /// whatever its groups do (see [isShown] for what ends up on screen).
  static bool isOwnShown(String svg, ElementPath path, SvgColorScheme scheme) {
    final document = _resolved(svg, scheme);
    final element = _target(document, path);
    if (document == null || element == null) return true;
    final rules = simpleRules(document.rootElement, (p) => p == 'display');
    return cssValueOf(element, rules, 'display')?.trim() != 'none';
  }

  /// Shows or hides the element at [path] in the [scheme] variant only; the
  /// other variant is left as it is. Nothing is kept when the element already
  /// does that without the editor's help.
  static String setShown(String svg, ElementPath path, bool shown, SvgColorScheme scheme) {
    final cleared = _editManaged(
      svg,
      path,
      (_, values, id) => values[scheme]!.remove('display|$id'),
      assign: false,
    );
    if (isOwnShown(cleared, path, scheme) == shown) return cleared;
    return _editManaged(
      cleared,
      path,
      (_, values, id) => values[scheme]!['display|$id'] = shown ? 'inline' : 'none',
    );
  }

  /// What a property shows when nothing sets it.
  static const _initial = {
    'fill': '#000000',
    'stroke': 'none',
    'display': 'inline',
    'visibility': 'visible',
    'opacity': '1',
    'fill-opacity': '1',
    'stroke-opacity': '1',
    'stroke-width': '1',
  };

  /// Gives [property] of the element at [path] back the value both variants
  /// share, in the [scheme] variant only: what the editor set there goes, and
  /// when a rule of the file still sets something else for that variant, the
  /// shared value is set over it.
  static String clearOwn(String svg, ElementPath path, SvgColorScheme scheme, String property) {
    final cleared = _editManaged(
      svg,
      path,
      (_, values, id) => values[scheme]!.remove('$property|$id'),
      assign: false,
    );
    final document = tryParseSvg(cleared);
    final element = _target(document, path);
    if (element == null) return cleared;
    final mark = SvgThemeMarks.list(cleared)[ElementPath.of(element)];
    if (mark == null || !mark.ownIn(scheme).contains(property)) return cleared;
    final shared = SvgThemeMarks.sharedValue(cleared, path, property) ?? _initial[property];
    if (shared == null) return cleared;
    return _editManaged(
      cleared,
      path,
      (_, values, id) => values[scheme]!['$property|$id'] = shared,
    );
  }

  /// Runs [change] on the editor's per-variant values (`property|id` →
  /// value, for each variant) with the `data-sm-t` id of the element at
  /// [path], then writes them back. A new id is given to the element unless
  /// [assign] is false, in which case an element without one is left alone.
  static String _editManaged(
    String svg,
    ElementPath path,
    void Function(XmlElement element, Map<SvgColorScheme, Map<String, String>> values, String id)
    change, {
    bool assign = true,
  }) {
    final document = tryParseSvg(svg);
    final element = _target(document, path);
    if (document == null || element == null) return svg;
    final root = document.rootElement;

    var id = element.getAttribute(_attribute);
    if (id == null) {
      if (!assign) return svg;
      id = _nextId(root);
      element.setAttribute(_attribute, id);
    }

    final block = root.childElements.where((e) => e.getAttribute(_marker) != null).firstOrNull;
    final values = {for (final s in SvgColorScheme.values) s: <String, String>{}};
    if (block != null) {
      final text = styleText(block);
      for (final rule in findAtRules(text, 'media')) {
        final which = rule.prelude.contains('dark') ? SvgColorScheme.dark : SvgColorScheme.light;
        final inner = text.substring(rule.blockStart + 1, rule.blockEnd);
        for (final match in _managedRule.allMatches(inner)) {
          values[which]!['${match.group(2)}|${match.group(1)}'] = match.group(3)!.trim();
        }
      }
    }
    change(element, values, id);

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

  /// One entry of the editor's block: `[data-sm-t="3"]{fill:#abc !important}`.
  static final _managedRule = RegExp(r'\[data-sm-t="(\d+)"\]\s*\{\s*([a-z-]+)\s*:\s*([^;}!]+)');

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
