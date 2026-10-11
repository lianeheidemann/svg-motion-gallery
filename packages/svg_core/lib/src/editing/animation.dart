import 'package:xml/xml.dart';

import '../css.dart';
import '../css_rules.dart';
import '../time.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Ready-made motions the editor can add to an element.
enum SvgAnimationPreset {
  spin('sm-spin', 'linear'),
  pulse('sm-pulse', 'ease-in-out'),
  float('sm-float', 'ease-in-out'),
  sway('sm-sway', 'ease-in-out'),
  fade('sm-fade', 'ease-in-out');

  const SvgAnimationPreset(this.keyframesName, this.easing);

  final String keyframesName;
  final String easing;
}

/// The presets' keyframes. How strong a motion is comes from `--sm-i` on the
/// layer's wrapper (1 = the original strength; 1 when it is missing, so old
/// files keep working), so every layer can have its own without more keyframes.
/// A spin is a full turn whatever the strength.
const _presetKeyframes =
    '@keyframes sm-spin{to{transform:rotate(360deg)}}'
    '@keyframes sm-pulse{50%{transform:scale(calc(1 + .15 * var(--sm-i,1)))}}'
    '@keyframes sm-float{50%{transform:translateY(calc(-8% * var(--sm-i,1)))}}'
    '@keyframes sm-sway{25%{transform:rotate(calc(-8deg * var(--sm-i,1)))}'
    '75%{transform:rotate(calc(8deg * var(--sm-i,1)))}}'
    '@keyframes sm-fade{50%{opacity:calc(1 - .75 * var(--sm-i,1))}}';

/// Name of the custom property holding a motion's strength.
const _intensityProperty = '--sm-i';

const _timingAttributes = {'dur', 'begin', 'end', 'repeatDur'};

/// Animation edits: speed, removal and presets.
class SvgAnimationEdit {
  const SvgAnimationEdit._();

  /// Plays every animation [factor] times faster (0.5 = half speed): SMIL
  /// `dur`/`begin`/`end`/`repeatDur` and CSS `animation*` times are divided.
  ///
  /// With [only] (non-empty) just those elements change: each one, everything
  /// inside it, and the animation wrappers around it. Animations that come
  /// from a shared `<style>` rule are not edited there (other layers use them
  /// too): the scaled times go on the element's own `style` instead.
  static String changeSpeed(String svg, double factor, {List<ElementPath>? only}) {
    if (factor <= 0 || factor == 1) return svg;
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    final scale = 1 / factor;
    String? scaleCss(String property, String value) =>
        property.startsWith('animation') ? scaleCssTimes(value, scale) : value;

    final scoped = only != null && only.isNotEmpty;
    final Iterable<XmlElement> elements;
    if (scoped) {
      final chosen = <XmlElement>{};
      for (final path in only) {
        final target = path.isRoot ? root : path.resolve(root);
        if (target == null) continue;
        chosen.addAll([target, ...target.descendantElements]);
        for (final up in target.ancestorElements) {
          if (up.getAttribute(animationAttribute) != null) chosen.add(up);
        }
      }
      elements = chosen;
    } else {
      elements = [root, ...root.descendantElements];
    }

    final sheetRules = scoped
        ? simpleRules(root, (property) => property.startsWith('animation'))
        : const <CssRule>[];
    for (final element in elements) {
      if (smilTags.contains(element.localName)) {
        for (final name in _timingAttributes) {
          final raw = element.getAttribute(name);
          if (raw == null) continue;
          final scaled = raw
              .split(';')
              .map((part) {
                final seconds = parseClockValue(part);
                return seconds == null ? part : formatClockValue(seconds * scale);
              })
              .join(';');
          element.setAttribute(name, scaled);
        }
      }
      var style = element.getAttribute('style');
      if (style != null) {
        style = mapDeclarations(style, scaleCss);
        element.setAttribute('style', style);
      }
      if (scoped) {
        final own = {
          for (final piece in splitTopLevel(style ?? '', ';'))
            if (piece.contains(':')) piece.substring(0, piece.indexOf(':')).trim().toLowerCase(),
        };
        final inherited = <String, String>{};
        for (final rule in sheetRules) {
          if (rule.matches(element)) inherited.addAll(rule.declarations);
        }
        final extra = [
          for (final entry in inherited.entries)
            if (!own.contains(entry.key)) '${entry.key}:${scaleCssTimes(entry.value, scale)}',
        ];
        if (extra.isNotEmpty) {
          final base = (style ?? '').trim();
          final glue = base.isEmpty || base.endsWith(';') ? '' : ';';
          element.setAttribute('style', '$base$glue${extra.join(';')}');
        }
      }
      if (!scoped && element.localName == 'style') {
        setStyleText(element, mapStylesheetDeclarations(styleText(element), scaleCss));
      }
    }
    return document.toXmlString();
  }

  /// Removes all SMIL elements, CSS `animation*` declarations and
  /// `@keyframes`, leaving a static drawing.
  static String removeAll(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    for (final element in root.descendantElements.toList()) {
      if (smilTags.contains(element.localName)) element.remove();
    }
    String? dropAnimation(String property, String value) =>
        property.startsWith('animation') ? null : value;
    for (final element in [root, ...root.descendantElements]) {
      final style = element.getAttribute('style');
      if (style != null) {
        final cleaned = mapDeclarations(style, dropAnimation);
        element.setAttribute('style', cleaned.trim().isEmpty ? null : cleaned);
      }
      if (element.localName == 'style') {
        final css = removeAtRules(styleText(element), 'keyframes');
        setStyleText(element, mapStylesheetDeclarations(css, dropAnimation));
      }
    }
    return document.toXmlString();
  }

  /// Adds [preset] to the layer at [path] through an animation wrapper
  /// group (so it composes with the element's own transform). A layer has one
  /// such wrapper, right around what the user drew (inside the transform
  /// wrapper): applying a preset to a layer that has one replaces its motion,
  /// and extra ones an older version left are taken out.
  ///
  /// [intensity] is how strong the motion is (1 = the original: a pulse grows
  /// 15 %, a sway turns 8 degrees, and so on). A spin ignores it.
  static SvgEditResult addPreset(
    String svg,
    ElementPath path,
    SvgAnimationPreset preset, {
    double seconds = 2,
    double intensity = 1,
  }) {
    final document = tryParseSvg(svg);
    if (document == null || path.isRoot) return SvgEditResult(svg, selection: path);
    final root = document.rootElement;
    final element = path.resolve(root);
    if (element == null) return SvgEditResult(svg, selection: path);

    final existing = _animationWrappers(element);
    final XmlElement wrapper;
    if (existing.isEmpty) {
      wrapper = _wrap(chainBottom(element));
    } else {
      wrapper = existing.last;
      existing.sublist(0, existing.length - 1).forEach(unwrapGroup);
    }
    wrapper
      ..setAttribute(animationAttribute, preset.name)
      ..setAttribute(
        'style',
        'transform-box:fill-box;transform-origin:center;'
            '$_intensityProperty:${formatNumber(intensity.clamp(0, 5))};'
            'animation:${preset.keyframesName} ${formatClockValue(seconds)} ${preset.easing} infinite',
      );
    _ensureKeyframes(root);
    return SvgEditResult(document.toXmlString(), selection: ElementPath.of(chainTop(wrapper)));
  }

  /// Removes a preset added by [addPreset] from the layer at [path] (unwraps
  /// its animation group, leaving its transform).
  static SvgEditResult removePreset(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    final wrappers = element == null ? const <XmlElement>[] : _animationWrappers(element);
    if (wrappers.isEmpty) return SvgEditResult(svg, selection: path);
    final drawn = wrappers.last.childElements.where(isVisual).firstOrNull;
    wrappers.forEach(unwrapGroup);
    return SvgEditResult(
      document!.toXmlString(),
      selection: drawn == null ? null : ElementPath.of(chainTop(drawn)),
    );
  }

  /// The preset on the layer at [path], if it has one.
  static SvgAnimationPreset? presetAt(String svg, ElementPath path) {
    final name = _wrapperAt(svg, path)?.getAttribute(animationAttribute);
    return SvgAnimationPreset.values.where((preset) => preset.name == name).firstOrNull;
  }

  /// How strong the motion on the layer at [path] is (1 = the original).
  static double intensityAt(String svg, ElementPath path) {
    final style = _wrapperAt(svg, path)?.getAttribute('style') ?? '';
    final match = RegExp('$_intensityProperty\\s*:\\s*([0-9.]+)').firstMatch(style);
    return double.tryParse(match?.group(1) ?? '') ?? 1;
  }

  /// The animation wrappers of the layer [element] belongs to, outermost
  /// first (one, unless an older version stacked them).
  static List<XmlElement> _animationWrappers(XmlElement element) {
    final wrappers = [
      for (final wrapper in chainWrappers(element))
        if (wrapper.getAttribute(animationAttribute) != null) wrapper,
    ];
    // A wrapper holding several elements (edited by hand) still counts.
    if (wrappers.isEmpty && element.getAttribute(animationAttribute) != null) return [element];
    return wrappers;
  }

  static XmlElement? _wrapperAt(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    return element == null ? null : _animationWrappers(element).lastOrNull;
  }

  static XmlElement _wrap(XmlElement element) {
    final wrapper = buildElement('g');
    final siblings = element.parent!.children;
    siblings.insert(siblings.indexOf(element), wrapper);
    wrapper.children.add(element);
    return wrapper;
  }

  static void _ensureKeyframes(XmlElement root) {
    final existing = root.childElements
        .where((e) => e.localName == 'style' && e.getAttribute(animationAttribute) != null)
        .firstOrNull;
    if (existing != null) {
      setStyleText(existing, _presetKeyframes);
      return;
    }
    // Appended, so no element changes its path (several layers are edited in
    // a row by path).
    root.children.add(
      buildElement(
        'style',
        attributes: {animationAttribute: 'keyframes'},
        children: [XmlText(_presetKeyframes)],
      ),
    );
  }
}
