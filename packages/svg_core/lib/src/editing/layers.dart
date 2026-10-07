import 'package:xml/xml.dart';

import '../xml_support.dart';
import 'element_path.dart';

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

  /// True for groups the editor created to hold a transform/animation.
  final bool isEditorGroup;

  /// Has SMIL children or a CSS animation of its own.
  final bool isAnimated;
}

/// Layer (element) operations. All functions take and return SVG text.
class SvgLayers {
  const SvgLayers._();

  /// Drawable elements in document (paint) order, depth-first.
  static List<SvgLayer> list(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return const [];
    final layers = <SvgLayer>[];
    void visit(XmlElement parent, ElementPath parentPath, int depth) {
      var index = 0;
      for (final child in parent.childElements) {
        final path = parentPath.child(index++);
        if (!isVisual(child)) continue;
        final text = child.localName == 'text' ? child.innerText.trim() : null;
        layers.add(
          SvgLayer(
            path: path,
            tag: child.localName,
            id: child.getAttribute('id'),
            name: _nameOf(child),
            text: text == null || text.isEmpty
                ? null
                : (text.length > 24 ? '${text.substring(0, 24)}…' : text),
            depth: depth,
            visible: !_isHidden(child),
            isEditorGroup: isEditorGroup(child),
            isAnimated:
                child.childElements.any((e) => smilTags.contains(e.localName)) ||
                (child.getAttribute('style')?.contains('animation') ?? false),
          ),
        );
        visit(child, path, depth + 1);
      }
    }

    visit(document.rootElement, ElementPath.root, 0);
    return layers;
  }

  static String? _nameOf(XmlElement element) {
    final name = element.getAttribute(nameAttribute)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static bool _isHidden(XmlElement element) =>
      element.getAttribute('display') == 'none' ||
      RegExp(r'display\s*:\s*none').hasMatch(element.getAttribute('style') ?? '');

  static String _edit(String svg, ElementPath path, void Function(XmlElement) change) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return svg;
    change(element);
    return document!.toXmlString();
  }

  /// Shows a hidden element or hides a visible one.
  static String toggleVisibility(String svg, ElementPath path) => _edit(svg, path, (element) {
    if (_isHidden(element)) {
      element.removeAttribute('display');
      final style = element.getAttribute('style');
      if (style != null) {
        final cleaned = style.replaceAll(RegExp(r'display\s*:\s*none\s*;?'), '').trim();
        element.setAttribute('style', cleaned.isEmpty ? null : cleaned);
      }
    } else {
      element.setAttribute('display', 'none');
    }
  });

  /// Deletes the element. Nothing is selected afterwards.
  static SvgEditResult remove(String svg, ElementPath path) =>
      SvgEditResult(_edit(svg, path, (element) => element.remove()));

  /// Inserts a copy right after the element and selects the copy. `id`s in
  /// the copy are suffixed so they stay unique.
  static SvgEditResult duplicate(String svg, ElementPath path) {
    final document = tryParseSvg(svg);
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return SvgEditResult(svg, selection: path);
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
    final element = document == null || path.isRoot ? null : path.resolve(document.rootElement);
    if (element == null) return SvgEditResult(svg, selection: path);
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
  });

  static String setText(String svg, ElementPath path, String text) => _edit(svg, path, (element) {
    element.children
      ..clear()
      ..add(XmlText(text));
  });
}
