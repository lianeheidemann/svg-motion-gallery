import 'package:xml/xml.dart';

/// Address of an element as child-element indices from the `<svg>` root.
/// The empty path is the root itself.
class ElementPath {
  const ElementPath(this.indices);

  static const root = ElementPath([]);

  final List<int> indices;

  bool get isRoot => indices.isEmpty;
  int get depth => indices.length;

  ElementPath child(int index) => ElementPath([...indices, index]);

  ElementPath? get parent => isRoot ? null : ElementPath(indices.sublist(0, indices.length - 1));

  /// Resolves this path against [svgRoot], or null when it no longer exists.
  XmlElement? resolve(XmlElement svgRoot) {
    var current = svgRoot;
    for (final index in indices) {
      final children = current.childElements.toList();
      if (index < 0 || index >= children.length) return null;
      current = children[index];
    }
    return current;
  }

  /// Path of [element] relative to the root element of its document.
  static ElementPath of(XmlElement element) {
    final indices = <int>[];
    XmlElement current = element;
    while (current.parentElement != null) {
      final parent = current.parentElement!;
      indices.insert(0, parent.childElements.toList().indexOf(current));
      current = parent;
    }
    return ElementPath(indices);
  }

  @override
  bool operator ==(Object other) {
    if (other is! ElementPath || other.indices.length != indices.length) return false;
    for (var i = 0; i < indices.length; i++) {
      if (other.indices[i] != indices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(indices);

  @override
  String toString() => indices.isEmpty ? '/' : '/${indices.join('/')}';
}

/// New document text plus the element that should be selected afterwards.
class SvgEditResult {
  const SvgEditResult(this.svg, {this.selection});

  final String svg;

  /// Null means "nothing selected" (the whole document).
  final ElementPath? selection;
}
