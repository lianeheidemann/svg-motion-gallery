import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../app_scope.dart';
import '../../data/svg_document.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_actions_menu.dart';
import '../../widgets/svg_preview.dart';
import '../editor/editor_screen.dart';
import '../gallery/svg_card.dart';
import 'viewer_widgets.dart';

/// Shows one SVG at a time (swipe or arrows to move through [documentIds])
/// with playback controls, light/dark variants and file information.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.documentIds, this.initialIndex = 0});

  final List<String> documentIds;
  final int initialIndex;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late final _ids = List.of(widget.documentIds);
  SvgPlaybackController? _playback;
  var _variant = VariantMode.auto;
  Timer? _slideshow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playback == null) {
      _playback = SvgPlaybackController(autoplay: AppScope.of(context).settings.value.autoplay);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPageShown());
    }
  }

  @override
  void dispose() {
    _slideshow?.cancel();
    _pages.dispose();
    _playback?.dispose();
    super.dispose();
  }

  List<SvgDocument> _documents() {
    final library = AppScope.of(context).library;
    return _ids.map(library.byId).whereType<SvgDocument>().toList();
  }

  void _onPageShown() {
    if (!mounted) return;
    final documents = _documents();
    if (documents.isEmpty) return;
    final index = _index.clamp(0, documents.length - 1);
    final document = documents[index];
    final library = AppScope.of(context).library;
    _playback?.cycle = library.metadataOf(document).cycleDuration;
    library.markOpened(document);
    // Phone files are read on demand: this page and its neighbours now.
    for (var i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < documents.length) unawaited(library.ensureContent(documents[i]));
    }
  }

  void _goTo(int index, int count) {
    final target = (index + count) % count;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _toggleSlideshow() {
    if (_slideshow != null) {
      _slideshow!.cancel();
      setState(() => _slideshow = null);
      return;
    }
    final seconds = AppScope.of(context).settings.value.slideshowSeconds;
    setState(() {
      _slideshow = Timer.periodic(Duration(seconds: seconds), (_) {
        final count = _documents().length;
        if (count > 1) _goTo(_index + 1, count);
      });
    });
  }

  SvgColorScheme? get _forcedScheme => switch (_variant) {
    VariantMode.light => SvgColorScheme.light,
    VariantMode.dark => SvgColorScheme.dark,
    _ => null,
  };

  void _openFullscreen(String svg) {
    final scheme = _forcedScheme ?? schemeOf(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenViewer(svg: svg, scheme: scheme),
      ),
    );
  }

  Future<void> _edit(SvgDocument document) async {
    final library = AppScope.of(context).library;
    await library.ensureContent(document);
    if (!mounted || !library.hasContent(document)) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => EditorScreen(documentId: document.id)));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final library = services.library;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final documents = _documents();
        if (documents.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.hide_image_outlined, title: l10n.fileMissing),
          );
        }
        final index = _index.clamp(0, documents.length - 1);
        final document = documents[index];
        final metadata = library.metadataOf(document);
        final svg = library.contentOf(document);
        _playback?.cycle = metadata.cycleDuration;
        final adaptive = metadata.themeSupport.isAdaptive;
        final live = SvgView.supportsLiveRendering;
        final stageHeight = math.min(MediaQuery.sizeOf(context).height * .42, 440.0);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.name, overflow: TextOverflow.ellipsis),
                Text(
                  l10n.bytes(document.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: GalleryColors.of(context).muted),
                ),
              ],
            ),
            actions: [
              FavoriteButton(document: document),
              IconButton(
                tooltip: l10n.actionShare,
                onPressed: () => runSvgAction(context, SvgAction.share, document),
                icon: const Icon(Icons.share_outlined),
              ),
              SvgActionsMenu(
                document: document,
                actions: document.isOnDevice
                    ? const [SvgAction.rename, SvgAction.delete]
                    : const [SvgAction.rename, SvgAction.duplicate, SvgAction.delete],
                onDuplicated: (copy) => setState(() => _ids.insert(index + 1, copy.id)),
                onDeleted: () {
                  if (_documents().isEmpty) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          // Keeps the last button above the system navigation bar.
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SizedBox(
                  height: stageHeight,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pages,
                        itemCount: documents.length,
                        onPageChanged: (page) {
                          setState(() {
                            _index = page;
                            _variant = VariantMode.auto;
                          });
                          _onPageShown();
                        },
                        itemBuilder: (context, page) {
                          final pageDocument = documents[page];
                          final pageSvg = library.contentOf(pageDocument);
                          if (!library.hasContent(pageDocument)) {
                            return Center(
                              child: library.isUnreadable(pageDocument)
                                  ? const Icon(Icons.broken_image_outlined, size: 56)
                                  : const CircularProgressIndicator(),
                            );
                          }
                          if (page == index && _variant == VariantMode.sideBySide) {
                            return SideBySideVariants(svg: pageSvg);
                          }
                          return SvgPreview(
                            key: ValueKey('page-${pageDocument.id}'),
                            svg: pageSvg,
                            scheme: page == index ? _forcedScheme : null,
                            controller: page == index ? _playback : null,
                            padding: const EdgeInsets.all(20),
                            semanticLabel: l10n.previewOf(pageDocument.name),
                          );
                        },
                      ),
                      if (documents.length > 1) ...[
                        _PageArrow(
                          alignment: Alignment.centerLeft,
                          icon: Icons.chevron_left_rounded,
                          tooltip: l10n.previous,
                          onPressed: () => _goTo(index - 1, documents.length),
                        ),
                        _PageArrow(
                          alignment: Alignment.centerRight,
                          icon: Icons.chevron_right_rounded,
                          tooltip: l10n.next,
                          onPressed: () => _goTo(index + 1, documents.length),
                        ),
                      ],
                    ],
                  ),
                ),
                if (documents.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.pageOf(index + 1, documents.length),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GalleryColors.of(context).muted),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                PlaybackBar(
                  controller: _playback!,
                  animated: metadata.isAnimated && live,
                  slideshowOn: _slideshow != null,
                  onToggleSlideshow: _toggleSlideshow,
                  onFullscreen: () => _openFullscreen(svg),
                ),
                if (adaptive) ...[
                  const SizedBox(height: AppSpacing.md),
                  VariantSelector(
                    mode: _variant,
                    onChanged: (mode) => setState(() => _variant = mode),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FileInfoCard(document: document, metadata: metadata),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('edit-svg'),
                  onPressed: () => _edit(document),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.editSvg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: IconButton.filledTonal(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
    ),
  );
}

class _FullscreenViewer extends StatelessWidget {
  const _FullscreenViewer({required this.svg, required this.scheme});

  final String svg;
  final SvgColorScheme scheme;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: context.l10n.close,
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    ),
    body: SafeArea(
      child: SvgPreview(svg: svg, scheme: scheme, interactive: true, borderRadius: 0),
    ),
  );
}
