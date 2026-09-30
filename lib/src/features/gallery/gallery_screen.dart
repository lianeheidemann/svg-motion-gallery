import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../l10n/l10n.dart';
import '../../services/device_storage.dart';
import '../../state/library_controller.dart';
import '../../widgets/app_bar_toggles.dart';
import '../../widgets/svg_actions_menu.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_screen.dart';
import 'svg_card.dart';

/// Home screen: filters, search, the animated grid, the theme and language
/// toggles, the import button and — where the platform allows it — every
/// `.svg` found on the phone, with multi-select delete.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _grid = ScrollController();
  final _selected = <String>{};
  LibraryController? _library;
  Timer? _scrollIdle;
  var _searching = false;
  var _scrolling = false;
  var _promptStarted = false;
  var _bannerDismissed = false;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_library != null) return;
    _library = AppScope.of(context).library..addListener(_libraryChanged);
    _libraryChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _library?.removeListener(_libraryChanged);
    _scrollIdle?.cancel();
    _search.dispose();
    _grid.dispose();
    super.dispose();
  }

  /// Back from the system screen where file access is allowed: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final library = _library;
    if (state != AppLifecycleState.resumed || library == null) return;
    if (library.supportsDevice && library.deviceAccess != DeviceAccess.granted) {
      unawaited(library.refreshDevice());
    }
  }

  /// Asks for file access the first time the app finds it is missing.
  void _libraryChanged() {
    final library = _library!;
    if (_promptStarted || library.isLoading || library.deviceAccess != DeviceAccess.denied) return;
    _promptStarted = true;
    unawaited(_promptForAccess());
  }

  Future<void> _promptForAccess() async {
    final library = _library!;
    if (!await library.shouldPromptForDevice()) return;
    await library.markDevicePrompted();
    if (!mounted) return;
    final l10n = context.l10n;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.sd_storage_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(l10n.devicePromptTitle),
        content: Text(l10n.devicePromptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.deviceNotNow),
          ),
          FilledButton(
            key: const Key('device-allow'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deviceAllow),
          ),
        ],
      ),
    );
    if (allow == true) await library.requestDeviceAccess();
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

  // ------------------------------------------------------------ selection

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _clearSelection() => setState(_selected.clear);

  void _selectAll() => setState(
    () => _selected
      ..clear()
      ..addAll(_library!.visible.map((document) => document.id)),
  );

  Future<void> _deleteSelected() async {
    final library = _library!;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final documents = [for (final id in _selected) ?library.byId(id)];
    if (documents.isEmpty) return;
    final onDevice = documents.where((document) => document.isOnDevice).length;
    final inLibrary = documents.length - onDevice;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteManyTitle(documents.length),
      message: [
        if (onDevice > 0) l10n.deleteManyDevice(onDevice),
        if (inLibrary > 0) l10n.deleteManyLibrary(inLibrary),
        if (onDevice > 0) l10n.cannotUndo,
      ].join('\n'),
      confirm: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    final report = await library.deleteMany(documents);
    if (!mounted) return;
    setState(_selected.clear);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          report.failed == 0
              ? l10n.deletedCount(report.deleted)
              : l10n.deletePartial(report.deleted, report.failed),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ scrolling

  /// While the grid moves, cards that appear are drawn still and start
  /// animating shortly after it stops; cards already live are left alone.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
      _scrollIdle?.cancel();
      if (!_scrolling) setState(() => _scrolling = true);
    } else if (notification is ScrollEndNotification) {
      _scrollIdle?.cancel();
      _scrollIdle = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _scrolling = false);
      });
    }
    return false;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final l10n = context.l10n;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar(l10n) : _mainBar(l10n),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: _import,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(l10n.importSvg),
              ),
        body: ListenableBuilder(
          listenable: library,
          builder: (context, _) => Column(
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
                  if (library.supportsDevice) ChipOption(GalleryFilter.device, l10n.filterDevice),
                  ChipOption(GalleryFilter.favorites, l10n.filterFavorites),
                  ChipOption(GalleryFilter.recent, l10n.filterRecent),
                  ChipOption(GalleryFilter.adaptive, l10n.filterAdaptive),
                ],
              ),
              if (library.supportsDevice &&
                  library.deviceAccess == DeviceAccess.denied &&
                  !_bannerDismissed &&
                  !_selecting)
                _AccessBanner(
                  onAllow: library.requestDeviceAccess,
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
              if (library.isScanningDevice)
                Semantics(
                  label: l10n.deviceScanning,
                  child: const LinearProgressIndicator(minHeight: 2),
                ),
              Expanded(child: _content(library)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _mainBar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return AppBar(
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
    );
  }

  PreferredSizeWidget _selectionBar(AppLocalizations l10n) => AppBar(
    toolbarHeight: 68,
    leading: IconButton(
      tooltip: l10n.close,
      onPressed: _clearSelection,
      icon: const Icon(Icons.close_rounded),
    ),
    title: Text(l10n.selectedCount(_selected.length)),
    actions: [
      IconButton(
        tooltip: l10n.selectAll,
        onPressed: _selectAll,
        icon: const Icon(Icons.select_all_rounded),
      ),
      IconButton(
        key: const Key('delete-selected'),
        tooltip: l10n.deleteSelected,
        onPressed: _deleteSelected,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _content(LibraryController library) {
    final l10n = context.l10n;
    if (library.isLoading) return const Center(child: CircularProgressIndicator());
    final visible = library.visible;
    if (visible.isEmpty) return _emptyState(library);
    final ids = [for (final document in visible) document.id];
    final grid = GridView.builder(
      controller: _grid,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .8,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final document = visible[index];
        return SvgCard(
          key: ValueKey(document.id),
          document: document,
          selecting: _selecting,
          selected: _selected.contains(document.id),
          stillPreview: _scrolling,
          onTap: () => _selecting ? _toggle(document.id) : _open(ids, index),
          onLongPress: () => _toggle(document.id),
        );
      },
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: library.supportsDevice
          ? RefreshIndicator(
              onRefresh: library.refreshDevice,
              semanticsLabel: l10n.deviceScanning,
              child: grid,
            )
          : grid,
    );
  }

  Widget _emptyState(LibraryController library) {
    final l10n = context.l10n;
    if (library.query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.emptySearchTitle,
        message: l10n.emptySearchMessage,
      );
    }
    return switch (library.filter) {
      GalleryFilter.favorites => EmptyState(
        icon: Icons.favorite_border_rounded,
        title: l10n.emptyFavoritesTitle,
        message: l10n.emptyFavoritesMessage,
      ),
      GalleryFilter.recent => EmptyState(
        icon: Icons.history_rounded,
        title: l10n.emptyRecentTitle,
        message: l10n.emptyRecentMessage,
      ),
      GalleryFilter.adaptive => EmptyState(
        icon: Icons.contrast_rounded,
        title: l10n.emptyAdaptiveTitle,
        message: l10n.emptyAdaptiveMessage,
      ),
      GalleryFilter.device =>
        library.deviceAccess == DeviceAccess.denied
            ? EmptyState(
                icon: Icons.sd_storage_outlined,
                title: l10n.emptyDeviceTitle,
                message: l10n.emptyDeviceDeniedMessage,
                action: FilledButton(
                  onPressed: library.requestDeviceAccess,
                  child: Text(l10n.deviceAllow),
                ),
              )
            : EmptyState(
                icon: Icons.sd_storage_outlined,
                title: l10n.emptyDeviceTitle,
                message: l10n.emptyDeviceMessage,
              ),
      GalleryFilter.all => EmptyState(
        icon: Icons.collections_outlined,
        title: l10n.emptyLibraryTitle,
        message: l10n.emptyLibraryMessage,
      ),
    };
  }
}

/// Reminder shown while file access has not been allowed.
class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.onAllow, required this.onDismiss});

  final VoidCallback onAllow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.sd_storage_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deviceBannerTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    l10n.deviceBannerMessage,
                    style: TextStyle(color: GalleryColors.of(context).muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('banner-allow'),
              onPressed: onAllow,
              child: Text(l10n.deviceAllow),
            ),
            IconButton(
              tooltip: l10n.deviceNotNow,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
