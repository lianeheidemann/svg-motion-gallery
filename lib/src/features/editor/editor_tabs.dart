import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'editor_controller.dart';

/// The editor's tabs, in the order of the bar.
enum EditorTab { layers, transform, window, align, colors, animation, insert, text, code }

/// The bar of tabs under the panel.
class EditorTabBar extends StatelessWidget {
  const EditorTabBar({super.key, required this.editor, required this.tab, required this.onChanged});

  final EditorController editor;
  final EditorTab tab;
  final ValueChanged<EditorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PillTabs(
      labelSelectedOnly: true,
      selectedIndex: tab.index,
      onChanged: (index) => onChanged(EditorTab.values[index]),
      tabs: [
        // Always first and highlighted; another color while the
        // whole drawing (every layer) is the target.
        PillTab(
          l10n.tabLayers,
          icon: Icons.layers_outlined,
          emphasized: true,
          accent: editor.selection == null ? GalleryColors.of(context).success : null,
        ),
        PillTab(l10n.tabTransform, icon: Icons.open_with_rounded),
        PillTab(l10n.tabWindow, icon: Icons.aspect_ratio_rounded),
        PillTab(l10n.tabAlign, icon: Icons.align_horizontal_center_rounded),
        PillTab(l10n.tabColors, icon: Icons.palette_outlined),
        PillTab(l10n.tabAnimation, icon: Icons.animation_rounded),
        PillTab(l10n.tabInsert, icon: Icons.add_box_outlined),
        PillTab(l10n.tabText, icon: Icons.text_fields_rounded),
        PillTab(l10n.tabCode, icon: Icons.code_rounded),
      ],
    );
  }
}
