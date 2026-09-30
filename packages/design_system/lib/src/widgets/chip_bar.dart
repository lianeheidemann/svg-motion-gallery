import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One option of a [ScrollableChipBar].
class ChipOption<T> {
  const ChipOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontally scrollable single-choice pills (with a scrollbar).
class ScrollableChipBar<T> extends StatefulWidget {
  const ScrollableChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
  });

  final List<ChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollableChipBar<T>> createState() => _ScrollableChipBarState<T>();
}

class _ScrollableChipBarState<T> extends State<ScrollableChipBar<T>> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 54,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding.add(const EdgeInsets.only(bottom: 10)),
        itemCount: widget.options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final option = widget.options[index];
          final selected = option.value == widget.selected;
          return ChoiceChip(
            visualDensity: VisualDensity.compact,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            selected: selected,
            onSelected: (_) => widget.onSelected(option.value),
            avatar: option.icon == null
                ? null
                : Icon(option.icon, size: 16, color: selected ? Colors.white : scheme.onSurface),
            label: Text(
              option.label,
              style: TextStyle(
                color: selected ? Colors.white : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}
