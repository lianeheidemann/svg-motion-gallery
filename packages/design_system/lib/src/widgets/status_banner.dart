import 'package:flutter/material.dart';

import '../theme/gallery_colors.dart';
import '../theme/tokens.dart';

/// Success/error line with an icon, e.g. "SVG válido — Nenhum erro encontrado".
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.ok,
    this.warning = false,
    required this.title,
    this.message,
    this.trailing,
  });

  final bool ok;

  /// Amber instead of red: something to look at, but nothing is blocked.
  final bool warning;
  final String title;
  final String? message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = GalleryColors.of(context);
    final theme = Theme.of(context);
    final tone = ok ? colors.success : (warning ? const Color(0xFFF5A524) : colors.danger);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_rounded
                  : (warning ? Icons.warning_amber_rounded : Icons.error_rounded),
              color: tone,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
