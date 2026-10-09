import 'package:flutter/material.dart';

/// One choice of [AdjustTabs]: a round icon with its name below.
class AdjustTab<T> {
  const AdjustTab({required this.id, required this.icon, required this.label});

  final T id;
  final IconData icon;
  final String label;
}

/// A scrolling row of round icon buttons (photo-editor style); the selected
/// one is filled with the accent color.
class AdjustTabs<T> extends StatefulWidget {
  const AdjustTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<AdjustTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

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
    return SizedBox(
      height: 86,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final on = tab.id == widget.selected;
          return Semantics(
            button: true,
            selected: on,
            label: tab.label,
            child: InkResponse(
              key: Key('adjust-${tab.id}'),
              onTap: () => widget.onSelected(tab.id),
              radius: 40,
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? scheme.primary : scheme.surfaceContainerHighest,
                      ),
                      child: Icon(tab.icon, color: on ? scheme.onPrimary : scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
  }
}
