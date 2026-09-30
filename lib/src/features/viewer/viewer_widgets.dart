import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_preview.dart';

/// Which variant of an adaptive SVG the viewer shows.
enum VariantMode { auto, light, dark, sideBySide }

/// Play/pause, position slider, restart, slideshow and fullscreen controls.
class PlaybackBar extends StatefulWidget {
  const PlaybackBar({
    super.key,
    required this.controller,
    required this.animated,
    required this.slideshowOn,
    required this.onToggleSlideshow,
    required this.onFullscreen,
  });

  final SvgPlaybackController controller;

  /// False for static SVGs: only slideshow and fullscreen are shown.
  final bool animated;
  final bool slideshowOn;
  final VoidCallback onToggleSlideshow;
  final VoidCallback onFullscreen;

  @override
  State<PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<PlaybackBar> {
  var _resumeAfterSeek = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Row(
            children: [
              if (widget.animated) ...[
                IconButton.filledTonal(
                  key: const Key('play-pause'),
                  tooltip: controller.isPlaying ? l10n.pause : l10n.play,
                  onPressed: controller.toggle,
                  icon: Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                Expanded(
                  child: Slider(
                    value: controller.progress,
                    semanticFormatterCallback: (value) =>
                        l10n.positionPercent((value * 100).round()),
                    onChangeStart: (_) {
                      _resumeAfterSeek = controller.isPlaying;
                      controller.pause();
                    },
                    onChanged: controller.seekFraction,
                    onChangeEnd: (_) {
                      if (_resumeAfterSeek) controller.play();
                    },
                  ),
                ),
                IconButton(
                  tooltip: l10n.restart,
                  onPressed: controller.restart,
                  icon: const Icon(Icons.replay_rounded),
                ),
              ] else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      l10n.staticSvg,
                      style: TextStyle(color: GalleryColors.of(context).muted),
                    ),
                  ),
                ),
              IconButton(
                key: const Key('slideshow'),
                tooltip: widget.slideshowOn ? l10n.slideshowStop : l10n.slideshowStart,
                isSelected: widget.slideshowOn,
                onPressed: widget.onToggleSlideshow,
                icon: const Icon(Icons.slideshow_outlined),
                selectedIcon: Icon(
                  Icons.slideshow_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                tooltip: l10n.fullscreen,
                onPressed: widget.onFullscreen,
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auto / Light / Dark / Side by side, shown only for adaptive SVGs.
class VariantSelector extends StatelessWidget {
  const VariantSelector({super.key, required this.mode, required this.onChanged});

  final VariantMode mode;
  final ValueChanged<VariantMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      icon: Icons.contrast_rounded,
      title: l10n.variantTitle,
      children: [
        Text(l10n.variantHint, style: TextStyle(color: GalleryColors.of(context).muted)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label, icon) in [
              (VariantMode.auto, l10n.variantAuto, Icons.brightness_auto_rounded),
              (VariantMode.light, l10n.variantLight, Icons.light_mode_rounded),
              (VariantMode.dark, l10n.variantDark, Icons.dark_mode_rounded),
              (VariantMode.sideBySide, l10n.variantBoth, Icons.compare_rounded),
            ])
              ChoiceChip(
                avatar: Icon(icon, size: 18, color: value == mode ? Colors.white : null),
                label: Text(label, style: TextStyle(color: value == mode ? Colors.white : null)),
                selected: value == mode,
                onSelected: (_) => onChanged(value),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
          ],
        ),
      ],
    );
  }
}

/// Light and dark variants next to each other, each on a matching backdrop.
class SideBySideVariants extends StatelessWidget {
  const SideBySideVariants({super.key, required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget variant(SvgColorScheme scheme, String label, Brightness brightness) => Expanded(
      child: Theme(
        data: buildAppTheme(brightness: brightness, accent: Theme.of(context).colorScheme.primary),
        child: Builder(
          builder: (context) => Column(
            children: [
              Expanded(
                child: SvgPreview(svg: svg, scheme: scheme, semanticLabel: label),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        variant(SvgColorScheme.light, l10n.variantLight, Brightness.light),
        const SizedBox(width: AppSpacing.sm),
        variant(SvgColorScheme.dark, l10n.variantDark, Brightness.dark),
      ],
    );
  }
}

/// The "Informações" card.
class FileInfoCard extends StatelessWidget {
  const FileInfoCard({super.key, required this.document, required this.metadata});

  final SvgDocument document;
  final SvgMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      icon: Icons.info_outline_rounded,
      title: l10n.infoTitle,
      children: [
        KeyValueTable(
          rows: [
            (l10n.infoName, document.name),
            (l10n.infoSize, l10n.bytes(document.sizeBytes)),
            (l10n.infoDimensions, l10n.dimensions(metadata)),
            (l10n.infoElements, l10n.elementCount(metadata.elementCount)),
            (l10n.infoAnimations, l10n.animationSummary(metadata)),
            (l10n.infoTheme, l10n.themeSummary(metadata.themeSupport)),
            (l10n.infoModified, l10n.dateTime(document.modifiedAt)),
          ],
        ),
      ],
    );
  }
}
