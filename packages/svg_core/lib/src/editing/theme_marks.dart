import 'package:xml/xml.dart';

import '../colors.dart';
import '../css_rules.dart';
import '../theme/color_scheme.dart';
import '../theme/theme_resolver.dart';
import '../theme/theme_support.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Where what a layer shows in one theme comes from.
enum SvgThemeOrigin {
  /// The layer itself has a setting for that theme.
  own,

  /// A group around it has one, and the layer follows it.
  inherited,
}

/// What one layer shows differently in the light or the dark version,
/// compared with what both versions share (the file with no theme rule).
class SvgThemeMark {
  const SvgThemeMark({
    required this.path,
    this.own = const {},
    this.inherited = const {},
    this.shownIn = const {SvgColorScheme.light, SvgColorScheme.dark},
  });

  final ElementPath path;

  /// Per theme, the properties (`fill`, `display`...) the layer itself sets
  /// for that theme only.
  final Map<SvgColorScheme, Set<String>> own;

  /// Per theme, the properties that reach the layer from a group around it,
  /// each with the nearest group that sets it.
  final Map<SvgColorScheme, Map<String, ElementPath>> inherited;

  /// The versions the layer is drawn in (not hidden, itself or by a group).
  final Set<SvgColorScheme> shownIn;

  Set<String> ownIn(SvgColorScheme scheme) => own[scheme] ?? const {};

  Map<String, ElementPath> inheritedIn(SvgColorScheme scheme) => inherited[scheme] ?? const {};

  /// [SvgThemeOrigin.own] when the layer has a setting of its own for
  /// [scheme], [SvgThemeOrigin.inherited] when only a group's reaches it, null
  /// when that theme shows the shared look.
  SvgThemeOrigin? originIn(SvgColorScheme scheme) => ownIn(scheme).isNotEmpty
      ? SvgThemeOrigin.own
      : inheritedIn(scheme).isNotEmpty
      ? SvgThemeOrigin.inherited
      : null;

  /// The nearest group whose setting for [scheme] reaches the layer.
  ElementPath? sourceIn(SvgColorScheme scheme) {
    ElementPath? nearest;
    for (final path in inheritedIn(scheme).values) {
      if (nearest == null || path.depth > nearest.depth) nearest = path;
    }
    return nearest;
  }

  /// Whether both themes show the shared look.
  bool get isEmpty => SvgColorScheme.values.every((scheme) => originIn(scheme) == null);
}

/// Finds which layers of an SVG with light and dark versions (see
/// [SvgThemeSupport]) look different in one of them, and whether the layer
/// itself or a group around it is the reason.
///
/// The file is read three times: resolved for light, resolved for dark, and
/// with no theme at all (every `prefers-color-scheme` block dropped). A
/// layer has a setting of its own for a theme when what it declares there
/// differs from what it declares with no theme and that changes what it
/// shows; when only what it shows changes, the setting comes from a group.
class SvgThemeMarks {
  const SvgThemeMarks._();

  /// Properties a layer that sets none takes from its group.
  static const _passedDown = {
    'fill',
    'stroke',
    'visibility',
    'fill-opacity',
    'stroke-opacity',
    'stroke-width',
  };

  /// Not passed down, but they hide or fade everything inside the group.
  static const _wholeGroup = {'display': 'inline', 'opacity': '1'};

  /// Every property looked at.
  static final properties = {..._passedDown, ..._wholeGroup.keys};

  /// The mark of every layer, by path. Empty when [svg] has no light and dark
  /// versions in its code (no `prefers-color-scheme` media query) or does not
  /// parse.
  static Map<ElementPath, SvgThemeMark> list(String svg) {
    if (!SvgThemeSupport.detect(svg).uses(SvgThemeMechanism.mediaQuery)) return const {};
    final shared = _Version.parse(withoutThemeVariants(svg));
    final themed = {
      for (final scheme in SvgColorScheme.values)
        scheme: _Version.parse(SvgThemeResolver.resolve(svg, scheme)),
    };
    if (shared == null || themed.values.any((version) => version == null)) return const {};

    final marks = <ElementPath, SvgThemeMark>{};
    void visit(
      XmlElement element,
      Map<SvgColorScheme, XmlElement> twins,
      ElementPath path,
      Map<SvgColorScheme, _Context> contexts,
    ) {
      final own = <SvgColorScheme, Set<String>>{};
      final inherited = <SvgColorScheme, Map<String, ElementPath>>{};
      final shownIn = <SvgColorScheme>{};
      final next = <SvgColorScheme, _Context>{};
      for (final scheme in SvgColorScheme.values) {
        final version = themed[scheme]!;
        final twin = twins[scheme]!;
        final context = contexts[scheme]!;
        final ownHere = <String>{};
        final fromGroups = <String, ElementPath>{};
        final values = <String, String?>{};
        final sharedValues = <String, String?>{};
        final sources = <String, ElementPath>{};
        for (final property in _passedDown) {
          final declared = version.declared(twin, property);
          final declaredShared = shared.declared(element, property);
          final value = declared ?? context.values[property];
          final sharedValue = declaredShared ?? context.sharedValues[property];
          values[property] = value;
          sharedValues[property] = sharedValue;
          if (value == sharedValue) continue;
          if (declared != declaredShared) {
            ownHere.add(property);
            sources[property] = path;
          } else if (context.sources[property] case final source?) {
            fromGroups[property] = source;
            sources[property] = source;
          }
        }
        final groups = {...context.groups};
        for (final MapEntry(key: property, value: initial) in _wholeGroup.entries) {
          final declared = version.declared(twin, property) ?? initial;
          final declaredShared = shared.declared(element, property) ?? initial;
          if (context.groups[property] case final source?) fromGroups[property] = source;
          if (declared != declaredShared) {
            ownHere.add(property);
            groups[property] = path;
          }
        }
        own[scheme] = ownHere;
        inherited[scheme] = fromGroups;
        final shown = context.shown && version.declared(twin, 'display') != 'none';
        if (shown) shownIn.add(scheme);
        next[scheme] = _Context(values, sharedValues, sources, groups, shown);
      }
      if (!path.isRoot) {
        marks[path] = SvgThemeMark(path: path, own: own, inherited: inherited, shownIn: shownIn);
      }

      final children = element.childElements.toList();
      final twinChildren = {
        for (final entry in twins.entries) entry.key: entry.value.childElements.toList(),
      };
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (!isVisual(child)) continue;
        if (twinChildren.values.any((list) => i >= list.length)) break;
        visit(
          child,
          {for (final entry in twinChildren.entries) entry.key: entry.value[i]},
          path.child(i),
          next,
        );
      }
    }

    visit(
      shared.root,
      {for (final entry in themed.entries) entry.key: entry.value!.root},
      ElementPath.root,
      {for (final scheme in SvgColorScheme.values) scheme: _Context.empty},
    );
    return marks;
  }

  /// What [property] of the element at [path] shows with no theme: its own
  /// value, else (for `fill`, `stroke`...) its nearest group's. Null when
  /// nothing sets it. Editor wrappers are skipped, like [SvgThemeEdit] does.
  static String? sharedValue(String svg, ElementPath path, String property) {
    final shared = _Version.parse(withoutThemeVariants(svg));
    if (shared == null || path.isRoot) return null;
    var element = path.resolve(shared.root);
    if (element == null) return null;
    element = unwrapEditorGroups(element);
    final passedDown = _passedDown.contains(property);
    XmlElement? current = element;
    while (current != null) {
      final value = shared.declared(current, property);
      if (value != null || !passedDown) return value;
      current = current.parentElement;
    }
    return null;
  }
}

/// One way the file is read (light, dark or no theme), with its rules.
class _Version {
  _Version(this.root, this.rules);

  final XmlElement root;
  final List<CssRule> rules;

  static _Version? parse(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return null;
    final root = document.rootElement;
    return _Version(root, simpleRules(root, SvgThemeMarks.properties.contains));
  }

  /// What [element] itself sets for [property], normalized so equal values
  /// compare equal (`#abc` and `#AABBCC`, `.5` and `0.5`).
  String? declared(XmlElement element, String property) {
    final value = cssValueOf(element, rules, property);
    if (value == null) return null;
    final trimmed = value.trim();
    final color = SvgColorValue.normalize(trimmed);
    if (color != null) return color;
    final number = double.tryParse(trimmed);
    if (number != null) return formatNumber(number);
    return trimmed.toLowerCase();
  }
}

/// What a group hands down to what is inside it, in one theme.
class _Context {
  const _Context(this.values, this.sharedValues, this.sources, this.groups, this.shown);

  static const empty = _Context({}, {}, {}, {}, true);

  /// What the passed-down properties show in the theme, and with no theme.
  final Map<String, String?> values;
  final Map<String, String?> sharedValues;

  /// For each passed-down property that differs from the shared look, the
  /// nearest element that sets it for the theme.
  final Map<String, ElementPath> sources;

  /// For `display` and `opacity`, the nearest group with a setting of its own
  /// for the theme (it hides or fades everything inside).
  final Map<String, ElementPath> groups;

  /// Whether the group is drawn in the theme.
  final bool shown;
}
