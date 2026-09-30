import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../l10n/l10n.dart';
import '../../state/library_controller.dart';
import '../../widgets/app_bar_toggles.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_screen.dart';
import 'svg_card.dart';

/// Home screen: filters, search, the animated grid, the theme and language
/// toggles and the import button.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _search = TextEditingController();
  final _grid = ScrollController();
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    _grid.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _search.clear();
      AppScope.of(context).library.setQuery('');
    }
  }

  Future<void> _import() async {
    final services = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final files = await services.importer.pick();
    if (files.isEmpty) return;
    final report = await services.library.importFiles(files);
    final parts = [
      if (report.imported.isNotEmpty) l10n.importedCount(report.imported.length),
      if (report.rejected.isNotEmpty) l10n.importRejected(report.rejected.join(', ')),
    ];
    messenger.showSnackBar(SnackBar(content: Text(parts.join('\n'))));
  }

  void _open(List<String> ids, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViewerScreen(documentIds: ids, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = AppScope.of(context).library;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: AppSpacing.pageGutter,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/icon/app_logo.png', width: 38, height: 38),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
                  Text(
                    l10n.gallerySubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: GalleryColors.of(context).muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _searching ? l10n.closeSearch : l10n.search,
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          const ThemeToggleButton(),
          const LanguageToggleButton(),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.file_upload_outlined),
        label: Text(l10n.importSvg),
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: library.setQuery,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ScrollableChipBar<GalleryFilter>(
                selected: library.filter,
                onSelected: library.setFilter,
                options: [
                  ChipOption(GalleryFilter.all, l10n.filterAll),
                  ChipOption(GalleryFilter.favorites, l10n.filterFavorites),
                  ChipOption(GalleryFilter.recent, l10n.filterRecent),
                  ChipOption(GalleryFilter.adaptive, l10n.filterAdaptive),
                ],
              ),
              Expanded(child: _content(library)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(LibraryController library) {
    final l10n = context.l10n;
    if (library.isLoading) return const Center(child: CircularProgressIndicator());
    final visible = library.visible;
    if (visible.isEmpty) {
      final (icon, title, message) = library.query.isNotEmpty
          ? (Icons.search_off_rounded, l10n.emptySearchTitle, l10n.emptySearchMessage)
          : switch (library.filter) {
              GalleryFilter.favorites => (
                Icons.favorite_border_rounded,
                l10n.emptyFavoritesTitle,
                l10n.emptyFavoritesMessage,
              ),
              GalleryFilter.recent => (
                Icons.history_rounded,
                l10n.emptyRecentTitle,
                l10n.emptyRecentMessage,
              ),
              GalleryFilter.adaptive => (
                Icons.contrast_rounded,
                l10n.emptyAdaptiveTitle,
                l10n.emptyAdaptiveMessage,
              ),
              GalleryFilter.all => (
                Icons.collections_outlined,
                l10n.emptyLibraryTitle,
                l10n.emptyLibraryMessage,
              ),
            };
      return EmptyState(icon: icon, title: title, message: message);
    }
    final ids = [for (final document in visible) document.id];
    return GridView.builder(
      controller: _grid,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .8,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) => SvgCard(
        key: ValueKey(visible[index].id),
        document: visible[index],
        onOpen: () => _open(ids, index),
      ),
    );
  }
}
