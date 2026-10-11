import 'package:xml/xml.dart';

import '../xml_support.dart';
import 'element_path.dart';

/// One row of the layer list: what the user drew, standing where the editor
/// groups around it (its transform, its animation) begin.
class LayerSlot {
  const LayerSlot({
    required this.path,
    required this.element,
    required this.elementPath,
    required this.wrappers,
    required this.depth,
  });

  /// Where the layer starts: its outermost editor group, else the element.
  final ElementPath path;

  /// What the user drew, and where it is.
  final XmlElement element;
  final ElementPath elementPath;

  /// The editor groups around [element], outermost first.
  final List<XmlElement> wrappers;

  final int depth;
}

/// Every layer under [root] in paint order, depth first. The editor groups
/// around a layer are folded into it (they are how its transform and
/// animation are kept, not layers of their own), and the group around the
/// whole drawing is left out: what is in it is listed at the top.
List<LayerSlot> layerSlots(XmlElement root) {
  final slots = <LayerSlot>[];
  void visit(XmlElement parent, ElementPath parentPath, int depth) {
    var index = 0;
    for (final child in parent.childElements) {
      final path = parentPath.child(index++);
      if (!isVisual(child)) continue;
      if (isRootWrapper(child)) {
        visit(child, path, depth);
        continue;
      }
      var element = child;
      var elementPath = path;
      final wrappers = <XmlElement>[];
      while (isChainWrapper(element)) {
        final children = element.childElements.toList();
        final inner = children.where(isVisual).single;
        wrappers.add(element);
        elementPath = elementPath.child(children.indexOf(inner));
        element = inner;
      }
      slots.add(
        LayerSlot(
          path: path,
          element: element,
          elementPath: elementPath,
          wrappers: wrappers,
          depth: depth,
        ),
      );
      visit(element, elementPath, depth + 1);
    }
  }

  visit(root, ElementPath.root, 0);
  return slots;
}
