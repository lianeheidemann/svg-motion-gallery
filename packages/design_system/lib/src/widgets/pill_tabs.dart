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
  var _moreBefore = false;
  var _moreAfter = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
  }

  /// Whether there is more to see on either side of the strip.
  void _updateArrows() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final before = position.pixels > 1;
    final after = position.pixels < position.maxScrollExtent - 1;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrows);
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
        // The strip scrolls by touch; arrows (not a scrollbar) tell there is more.
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateArrows();
            });
            return false;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: _strip(context, scheme),
                ),
              ),
              _arrow(scheme, atEnd: false, visible: _moreBefore),
              _arrow(scheme, atEnd: true, visible: _moreAfter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(ColorScheme scheme, {required bool atEnd, required bool visible}) {
    return Positioned(
      left: atEnd ? null : 0,
      right: atEnd ? 0 : null,
      top: 0,
      bottom: 8,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: Key(atEnd ? 'pill-tabs-more-after' : 'pill-tabs-more-before'),
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: atEnd ? Alignment.centerLeft : Alignment.centerRight,
                end: atEnd ? Alignment.centerRight : Alignment.centerLeft,
                colors: [scheme.surface.withValues(alpha: 0), scheme.surface],
                stops: const [0, .6],
              ),
            ),
            alignment: atEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Icon(
              atEnd ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _strip(BuildContext context, ColorScheme scheme) {
    return SizedBox(
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
    );
  }
}
