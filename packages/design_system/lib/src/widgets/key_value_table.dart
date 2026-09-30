import 'package:flutter/material.dart';

import '../theme/gallery_colors.dart';

/// Two-column list of labels and values (the viewer's "Informações").
class KeyValueTable extends StatelessWidget {
  const KeyValueTable({super.key, required this.rows, this.labelFlex = 2, this.valueFlex = 3});

  final List<(String label, String value)> rows;
  final int labelFlex;
  final int valueFlex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = GalleryColors.of(context).muted;
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: labelFlex,
                    child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ),
                  Expanded(
                    flex: valueFlex,
                    child: Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
