import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One tab of [PillTabs].
class PillTab {
  const PillTab(this.label, {this.icon, this.emphasized = false, this.accent});

  final String label;
  final IconData? icon;

  /// Always shows its label and a soft tint, even when not selected.
  final bool emphasized;

  /// Highlight color for this tab (defaults to the theme's primary color).
  final Color? accent;
}

/// Segmented, horizontally scrollable tab strip in a rounded container
/// (the "Propriedades | Animação | Cores | Camadas" row of the mockup).
///
/// With [labelSelectedOnly], unselected tabs show just their icon (label in
/// a tooltip), so many tabs fit on a phone without hidden options.
class PillTabs extends StatefulWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.labelSelectedOnly = false,
  });

  final List<PillTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool labelSelectedOnly;

  @override
  State<PillTabs> createState() => _PillTabsState();
}

class _PillTabsState extends State<PillTabs> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: widget.tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 2),
          itemBuilder: (context, index) {
            final tab = widget.tabs[index];
            final selected = index == widget.selectedIndex;
            final accent = tab.accent ?? scheme.primary;
            final color = selected
                ? Colors.white
                : (tab.emphasized ? accent : scheme.onSurfaceVariant);
            final showLabel =
                selected || tab.emphasized || !widget.labelSelectedOnly || tab.icon == null;
            return Semantics(
              selected: selected,
              button: true,
              label: showLabel ? null : tab.label,
              child: Tooltip(
                message: tab.label,
                child: Material(
                  color: selected
                      ? accent
                      : (tab.emphasized ? accent.withValues(alpha: .16) : Colors.transparent),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    onTap: () => widget.onChanged(index),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 8),
                      child: Row(
                        children: [
                          if (tab.icon != null) Icon(tab.icon, size: 20, color: color),
                          if (tab.icon != null && showLabel) const SizedBox(width: 6),
                          if (showLabel)
                            Text(
                              tab.label,
                              style: TextStyle(
                                color: color,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
