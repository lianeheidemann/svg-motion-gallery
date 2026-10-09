import 'package:flutter/material.dart';

/// One choice of [AdjustTabs]: a round icon with its name below.
class AdjustTab<T> {
  const AdjustTab({required this.id, required this.icon, required this.label});

  final T id;
  final IconData icon;
  final String label;
}

/// A row of round icon buttons (photo-editor style) that swipes sideways, with
/// no scrollbar; the selected one is filled with the accent color.
class AdjustTabs<T> extends StatefulWidget {
  const AdjustTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final List<AdjustTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  /// A widget after the last tab (e.g. a reset button); it scrolls with them.
  final Widget? trailing;

  @override
  State<AdjustTabs<T>> createState() => _AdjustTabsState<T>();
}

class _AdjustTabsState<T> extends State<AdjustTabs<T>> {
  // Its own controller: the page's scroll controller belongs to the list that
  // holds this row.
  final _scroll = ScrollController();

  List<AdjustTab<T>> get tabs => widget.tabs;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        // A handful of items: all stay built, so each can be found and scrolled to.
        scrollCacheExtent: const ScrollCacheExtent.viewport(3),
        itemCount: tabs.length + (widget.trailing == null ? 0 : 1),
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          // The trailing widget is the last item, so it swipes with the rest.
          if (index == tabs.length) return widget.trailing!;
          final tab = tabs[index];
          final on = tab.id == widget.selected;
          return Semantics(
            button: true,
            selected: on,
            label: tab.label,
            child: InkResponse(
              key: Key('adjust-${tab.id}'),
              onTap: () => widget.onSelected(tab.id),
              radius: 42,
              child: SizedBox(
                width: 84,
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? scheme.primary : scheme.surfaceContainerHighest,
                      ),
                      child: Icon(tab.icon, color: on ? scheme.onPrimary : scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: on ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    return SizedBox(height: 66, child: row);
  }
}
