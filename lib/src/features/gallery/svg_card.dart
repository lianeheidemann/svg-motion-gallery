import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_actions_menu.dart';
import '../../widgets/svg_preview.dart';

/// Gallery tile: animated preview, favorite toggle, light/dark badge, name,
/// size and the file actions menu.
class SvgCard extends StatelessWidget {
  const SvgCard({super.key, required this.document, required this.onOpen});

  final SvgDocument document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final adaptive = library.metadataOf(document).themeSupport.isAdaptive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SvgPreview(
                          svg: library.contentOf(document),
                          thumbnail: true,
                          borderRadius: AppSpacing.radiusSmall,
                          padding: const EdgeInsets.all(12),
                          semanticLabel: l10n.previewOf(document.name),
                        ),
                      ),
                      if (adaptive)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _AdaptiveIconBadge(label: l10n.adaptiveBadge),
                        ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: FavoriteButton(document: document, compact: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.bytes(document.sizeBytes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: GalleryColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SvgActionsMenu(document: document),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart toggle shared by the gallery card and the viewer.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.document, this.compact = false});

  final SvgDocument document;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final l10n = context.l10n;
    final favorite = document.isFavorite;
    final color = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: favorite ? l10n.removeFavorite : l10n.addFavorite,
      isSelected: favorite,
      style: compact
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
              minimumSize: const Size(34, 34),
              fixedSize: const Size(34, 34),
              padding: EdgeInsets.zero,
            )
          : null,
      onPressed: () => library.toggleFavorite(document),
      icon: Icon(
        favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: favorite ? color : null,
        size: compact ? 19 : null,
      ),
    );
  }
}

class _AdaptiveIconBadge extends StatelessWidget {
  const _AdaptiveIconBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .88),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.contrast_rounded,
            size: 16,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
