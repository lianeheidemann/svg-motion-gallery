import 'package:xml/xml.dart';

import '../css.dart';
import '../xml_support.dart';
import 'element_path.dart';
import 'layer_tree.dart';

/// A drawable element shown in the editor's layer list.
class SvgLayer {
  const SvgLayer({
    required this.path,
    required this.tag,
    required this.depth,
    required this.visible,
    this.id,
    this.name,
    this.text,
    this.isEditorGroup = false,
    this.isAnimated = false,
  });

  final ElementPath path;
  final String tag;
  final String? id;

  /// Name the user gave the layer (`data-name`), or null for the default.
  final String? name;

  /// Text content for `<text>` elements (trimmed, first 24 characters).
  final String? text;
  final int depth;
  final bool visible;

  /// True for a group the editor created that is not folded into a layer
  /// (one holding several elements, after the code was edited by hand).
  final bool isEditorGroup;

  /// Has SMIL children or a CSS animation of its own, or a preset motion.
  final bool isAnimated;
}

/// Layer (element) operations. All functions take and return SVG text.
class SvgLayers {
  const SvgLayers._();

  /// Drawable elements in document (paint) order, depth-first. The groups
  /// the editor adds to keep a layer's transform or animation are not listed:
  /// the layer stands where they begin (its [SvgLayer.path] is the outermost
  /// one), so it moves, orders and deletes along with them.
  static List<SvgLayer> list(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return const [];
    return [for (final slot in layerSlots(document.rootElement)) _layerOf(slot)];
  }

  static SvgLayer _layerOf(LayerSlot slot) {
    final element = slot.element;
    final text = element.localName == 'text' ? element.innerText.trim() : null;
    return SvgLayer(
      path: slot.path,
      tag: element.localName,
      id: element.getAttribute('id'),
      name: _nameOf(element),
      text: text == null || text.isEmpty
          ? null
          : (text.length > 24 ? '${text.substring(0, 24)}…' : text),
      depth: slot.depth,
      visible: ![...slot.wrappers, element].any(_isHidden),
      isEditorGroup: isEditorGroup(element),
      isAnimated:
          element.childElements.any((e) => smilTags.contains(e.localName)) ||
          [
            ...slot.wrappers,
            element,
          ].any((e) => e.getAttribute('style')?.contains('animation') ?? false),
    );
  }

  static String? _nameOf(XmlElement element) {
    final name = element.getAttribute(nameAttribute)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static bool _isHidden(XmlElement element) =>
      element.getAttribute('display') == 'none' ||
      RegExp(r'display\s*:\s*none').hasMatch(element.getAttribute('style') ?? '');

  /// Runs [change] on the element at [path]: the layer's outermost editor
  /// group with [whole] (so its transform and animation go along), else
  /// what the user drew inside them.
  static String _edit(
    String svg,
    ElementPath path,
    void Function(XmlElement) change, {
    required bool whole,
  }) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return svg;
    change(whole ? chainTop(element) : chainBottom(element));
    return document!.toXmlString();
  }

  /// Shows a hidden layer or hides a visible one (hidden by itself or by one
  /// of its editor groups), in both versions of a light/dark SVG.
  ///
  /// The layer is hidden with `display:none !important` in its own `style`:
  /// a `display` attribute loses to any rule of the stylesheet that sets
  /// `display` (`.night { display: inline }`), the editor's theme rules
  /// included. Showing it takes that off, and the attribute older versions
  /// wrote.
  static String toggleVisibility(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return svg;
    final top = chainTop(element);
    final chain = [...chainWrappers(top), chainBottom(top)];
    if (chain.any(_isHidden)) {
      for (final node in chain) {
        if (node.getAttribute('display') == 'none') node.removeAttribute('display');
        _setStyle(
          node,
          mapDeclarations(node.getAttribute('style') ?? '', (name, value) {
            return name == 'display' && _hiddenValue.hasMatch(value) ? null : value;
          }),
        );
      }
    } else {
      final rest = mapDeclarations(
        top.getAttribute('style') ?? '',
        (name, value) => name == 'display' ? null : value,
      );
      _setStyle(top, [rest.trim(), 'display:none !important'].where((s) => s.isNotEmpty).join(';'));
    }
    return document!.toXmlString();
  }

  /// A `display` value that hides, with or without `!important`.
  static final _hiddenValue = RegExp(r'^\s*none\s*(!\s*important\s*)?$', caseSensitive: false);

  static void _setStyle(XmlElement element, String style) {
    final cleaned = style.trim().replaceAll(RegExp(r'^;+|;+$'), '').trim();
    element.setAttribute('style', cleaned.isEmpty ? null : cleaned);
  }

  /// Deletes the layer, with its editor groups. Nothing is selected afterwards.
  static SvgEditResult remove(String svg, ElementPath path) =>
      SvgEditResult(_edit(svg, path, (element) => element.remove(), whole: true));

  /// Inserts a copy right after the layer (with its editor groups) and
  /// selects the copy. `id`s in the copy are suffixed so they stay unique.
  static SvgEditResult duplicate(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    final found = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (found == null) return SvgEditResult(svg, selection: path);
    final element = chainTop(found);
    final copy = element.copy();
    for (final node in [copy, ...copy.descendantElements]) {
      final id = node.getAttribute('id');
      if (id != null) node.setAttribute('id', '$id-copy');
    }
    final siblings = element.parent!.children;
    siblings.insert(siblings.indexOf(element) + 1, copy);
    return SvgEditResult(document!.toXmlString(), selection: ElementPath.of(copy));
  }

  /// Moves the element one step towards the front (painted later).
  static SvgEditResult bringForward(String svg, ElementPath path) => _move(svg, path, 1);

  /// Moves the element one step towards the back (painted earlier).
  static SvgEditResult sendBackward(String svg, ElementPath path) => _move(svg, path, -1);

  static SvgEditResult _move(String svg, ElementPath path, int direction) {
    final document = tryParseSvg(svg);
    final found = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (found == null) return SvgEditResult(svg, selection: path);
    final element = chainTop(found);
    final parent = element.parent!;
    final siblings = parent.childElements.where(isVisual).toList();
    final position = siblings.indexOf(element);
    final target = position + direction;
    if (target < 0 || target >= siblings.length) return SvgEditResult(svg, selection: path);
    final other = siblings[target];
    element.remove();
    final nodes = parent.children;
    final otherIndex = nodes.indexOf(other);
    nodes.insert(direction > 0 ? otherIndex + 1 : otherIndex, element);
    return SvgEditResult(document!.toXmlString(), selection: ElementPath.of(element));
  }

  /// Replaces the text of a `<text>` element.
  /// Gives the layer a name of the user's choosing, stored as `data-name`
  /// (the `id`, which CSS and animations may point at, is left alone). An
  /// empty [name] removes it, so the layer goes back to its default name.
  static String rename(String svg, ElementPath path, String name) => _edit(svg, path, (element) {
    final trimmed = name.trim();
    element.setAttribute(nameAttribute, trimmed.isEmpty ? null : trimmed);
  }, whole: false);

  static String setText(String svg, ElementPath path, String text) => _edit(svg, path, (element) {
    element.children
      ..clear()
      ..add(XmlText(text));
  }, whole: false);
}
