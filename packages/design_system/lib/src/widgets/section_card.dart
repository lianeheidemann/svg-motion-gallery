import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rounded, outlined container with an optional icon + title header.
/// Used for settings groups, the viewer's info card and editor panels.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.children,
    this.title,
    this.icon,
    this.trailing,
    this.onTitleDoubleTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.spacing = AppSpacing.md,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;

  /// Called when the header (icon + title) is tapped twice.
  final VoidCallback? onTitleDoubleTap;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  /// The icon + title; a taller touch target when it answers a double tap.
  /// [trailing] stays outside, so its own taps never wait for a second one.
  Widget _titleArea(Widget row) => onTitleDoubleTap == null
      ? row
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onTitleDoubleTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(alignment: Alignment.centerLeft, child: row),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _titleArea(
                      Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: theme.colorScheme.primary, size: 22),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              SizedBox(height: spacing),
            ],
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
