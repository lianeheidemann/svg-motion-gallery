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
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.spacing = AppSpacing.md,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

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
              SizedBox(
                minHeight: AppSizes.compactControlHeight,
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: AppSizes.cardIcon,
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title!, style: theme.textTheme.titleMedium),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
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
