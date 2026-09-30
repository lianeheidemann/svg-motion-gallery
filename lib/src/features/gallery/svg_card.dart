import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_actions_menu.dart';
import '../../widgets/svg_preview.dart';

/// Gallery tile: animated preview, favorite toggle, light/dark badge, name,
/// size and the file actions menu. In selection mode the tile shows a check
/// mark instead and the actions are hidden.
class SvgCard extends StatefulWidget {
  const SvgCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    this.stillPreview = false,
  });

  final SvgDocument document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Some tile is selected: tapping selects instead of opening.
  final bool selecting;
  final bool selected;

  /// Draw the lightweight still preview (the grid is scrolling).
  final bool stillPreview;

  @override
  State<SvgCard> createState() => _SvgCardState();
}

class _SvgCardState extends State<SvgCard> {
  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final library = AppScope.of(context).library;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = GalleryColors.of(context).muted;
    final loaded = library.hasContent(document);
    final unreadable = !loaded && library.isUnreadable(document);
    if (!loaded && !unreadable) {
      // Phone files are read only once their card is built (i.e. visible),
      // and again if a rescan found the file changed. Idempotent while loading.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(library.ensureContent(document));
      });
    }
    final adaptive = loaded && library.metadataOf(document).themeSupport.isAdaptive;
    final folder = document.folder?.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => '');

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(
          color: widget.selected ? scheme.primary : scheme.outline,
          width: widget.selected ? 2.5 : 1,
        ),
      ),
      child: Semantics(
        selected: widget.selected,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: loaded
                          ? SvgPreview(
                              svg: library.contentOf(document),
                              thumbnail: true,
                              forceStill: widget.stillPreview,
                              borderRadius: 0,
                              padding: const EdgeInsets.all(10),
                              semanticLabel: l10n.previewOf(document.name),
                            )
                          : Stage(
                              borderRadius: 0,
                              child: Center(
                                child: Icon(
                                  unreadable ? Icons.broken_image_outlined : Icons.image_outlined,
                                  color: muted,
                                ),
                              ),
                            ),
                    ),
                    if (adaptive)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Badge(icon: Icons.contrast_rounded, label: l10n.adaptiveBadge),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: widget.selecting
                          ? _SelectionMark(selected: widget.selected)
                          : FavoriteButton(document: document, compact: true),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 6, widget.selecting ? 12 : 0, 6),
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
                            ),
                          ),
                          Row(
                            children: [
                              if (document.isOnDevice) ...[
                                Tooltip(
                                  message: l10n.onPhoneBadge,
                                  child: Icon(Icons.smartphone_rounded, size: 13, color: muted),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  [
                                    if (folder != null && folder.isNotEmpty) folder,
                                    l10n.bytes(document.sizeBytes),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!widget.selecting) SvgActionsMenu(document: document),
                  ],
                ),
              ),
            ],
          ),
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
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .7),
              minimumSize: const Size(36, 36),
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            )
          : null,
      onPressed: () => library.toggleFavorite(document),
      icon: Icon(
        favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: favorite ? color : null,
        size: compact ? 20 : null,
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primary : scheme.surface.withValues(alpha: .85),
          border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
