import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../../l10n/l10n.dart';
import '../../editor_controller.dart';
import '../layers_panel.dart';
import 'theme_badge.dart';

/// Opens the light/dark settings of the layer at [path] (see
/// [LayerThemeSheet]). [onOpenColors] goes to the Colors tab.
Future<void> showLayerThemeSheet(
  BuildContext context, {
  required EditorController editor,
  required ElementPath path,
  VoidCallback? onOpenColors,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  // Light, so the drawing on the stage stays readable while it changes.
  barrierColor: Colors.black.withValues(alpha: .2),
  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .62),
  builder: (context) => LayerThemeSheet(editor: editor, path: path, onOpenColors: onOpenColors),
);

/// What one layer shows in the light and in the dark version, side by side:
/// fill, outline and whether it is drawn, each saying whether the layer sets
/// it for that version, takes it from a group or shows the value both share.
/// Only the column of the version being edited (the one on the stage) can be
/// changed, so the other one is never touched by accident; tapping the other
/// column switches to it.
class LayerThemeSheet extends StatelessWidget {
  const LayerThemeSheet({super.key, required this.editor, required this.path, this.onOpenColors});

  final EditorController editor;
  final ElementPath path;
  final VoidCallback? onOpenColors;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        final active = editor.themeScheme;
        final layer = editor.layers.where((l) => l.path == path).firstOrNull;
        // Undone away, or the file lost its versions in the code tab.
        if (active == null || layer == null) return const SizedBox(height: 80);
        return _content(context, active, layer);
      },
    );
  }

  String _nameOf(AppLocalizations l10n, ElementPath path) {
    if (path.isRoot) return l10n.themeWholeDrawing;
    final layer = editor.layers.where((l) => l.path == path).firstOrNull;
    return layer == null ? '' : l10n.layerLabel(layer, editor.layers);
  }

  Widget _content(BuildContext context, SvgColorScheme active, SvgLayer layer) {
    final l10n = context.l10n;
    final muted = GalleryColors.of(context).muted;
    final svg = editor.svg;
    final mark = editor.themeMarks[path] ?? SvgThemeMark(path: path);
    final source = mark.sourceIn(active);
    final hiddenByGroup =
        !SvgThemeEdit.isShown(svg, path, active) && SvgThemeEdit.isOwnShown(svg, path, active);
    final others = mark.ownIn(active).difference({'fill', 'stroke', 'display'});

    return SingleChildScrollView(
      key: const Key('theme-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LayersPanel.iconFor(layer), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.layerLabel(layer, editor.layers),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Text(l10n.themeSettings, style: TextStyle(color: muted)),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<SvgColorScheme>(
            key: const Key('theme-segment'),
            showSelectedIcon: false,
            segments: [
              for (final scheme in SvgColorScheme.values)
                ButtonSegment(
                  value: scheme,
                  icon: Icon(themeIcon(scheme), color: themeColor(context, scheme, active: true)),
                  label: Text(l10n.themeTitle(scheme)),
                ),
            ],
            selected: {active},
            onSelectionChanged: (chosen) {
              if (chosen.single != active) editor.toggleTheme();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.themeEditingOnly(l10n.themeName(active), l10n.themeName(active.opposite)),
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          _table(context, active, mark),
          if (source != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('theme-comes-from'),
                icon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 18),
                label: Text(l10n.themeComesFrom(_nameOf(l10n, source))),
                // Select the group the setting comes from, to change it there.
                onPressed: source.isRoot
                    ? null
                    : () {
                        editor.replaceSelection([source]);
                        Navigator.of(context).pop();
                      },
              ),
            ),
          if (hiddenByGroup && source != null)
            _note(
              context,
              Icons.visibility_off_outlined,
              l10n.themeHiddenByGroup(_nameOf(l10n, source)),
            ),
          if (others.isNotEmpty)
            _note(context, Icons.info_outline_rounded, l10n.themeAlsoChanges(others.join(', '))),
          if (layer.tag == 'g') _note(context, Icons.folder_outlined, l10n.themeGroupNote),
          if (onOpenColors != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: const Key('theme-edit-colors'),
              icon: const Icon(Icons.palette_outlined),
              label: Text(l10n.themeEditColors),
              onPressed: () {
                if (!editor.targets.contains(path)) editor.replaceSelection([path]);
                Navigator.of(context).pop();
                onOpenColors!();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    final muted = GalleryColors.of(context).muted;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// Fill, outline and whether it is drawn, each with the light value next to
  /// the dark one, under the head of each version.
  Widget _table(BuildContext context, SvgColorScheme active, SvgThemeMark mark) {
    final l10n = context.l10n;
    final svg = editor.svg;

    String origin(SvgColorScheme scheme, String property) {
      if (mark.ownIn(scheme).contains(property)) return l10n.themeOwn;
      if (mark.inheritedIn(scheme).containsKey(property)) return l10n.themeInherited;
      return l10n.themeShared;
    }

    Widget pair(Widget Function(SvgColorScheme scheme) cell) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final scheme in SvgColorScheme.values) Expanded(child: cell(scheme))],
    );

    Widget paint(String label, String property) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowLabel(context, label),
        pair(
          (scheme) => _Cell(
            active: scheme == active,
            origin: origin(scheme, property),
            own: mark.ownIn(scheme).contains(property),
            resetKey: Key('theme-reset-$property'),
            onReset: () => editor.commit(SvgThemeEdit.clearOwn(editor.svg, path, active, property)),
            // Nothing set: a fill is black, an outline is not drawn.
            child: _PaintValue(
              value:
                  SvgThemeEdit.paintFor(svg, path, scheme, property) ??
                  (property == 'fill' ? '#000000' : 'none'),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair((scheme) => _header(context, scheme, active)),
        paint(l10n.fill, 'fill'),
        paint(l10n.outline, 'stroke'),
        _rowLabel(context, l10n.themeVisible),
        pair(
          (scheme) => _Cell(
            active: scheme == active,
            origin: origin(scheme, 'display'),
            own: false,
            child: scheme == active
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Switch(
                      key: const Key('theme-visible-switch'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: SvgThemeEdit.isOwnShown(svg, path, scheme),
                      onChanged: (shown) =>
                          editor.commit(SvgThemeEdit.setShown(editor.svg, path, shown, scheme)),
                    ),
                  )
                : Icon(
                    SvgThemeEdit.isShown(svg, path, scheme)
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _rowLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: GalleryColors.of(context).muted,
      ),
    ),
  );

  /// The column head: the version, and either "editando" or a lock that
  /// switches to it.
  Widget _header(BuildContext context, SvgColorScheme scheme, SvgColorScheme active) {
    final l10n = context.l10n;
    final isActive = scheme == active;
    final color = themeColor(context, scheme, active: isActive);
    final head = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          Icon(themeIcon(scheme), size: 18, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isActive
                  ? '${l10n.themeTitle(scheme)} · ${l10n.themeEditing}'
                  : l10n.themeTitle(scheme),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isActive ? FontWeight.w700 : null),
            ),
          ),
          if (!isActive) ...[
            const SizedBox(width: 4),
            Icon(Icons.lock_outline_rounded, size: 14, color: color),
          ],
        ],
      ),
    );
    if (isActive) return head;
    return Tooltip(
      message: l10n.themeSwitchTo(l10n.themeName(scheme)),
      child: InkWell(
        key: Key('theme-switch-${scheme.name}'),
        borderRadius: BorderRadius.circular(8),
        onTap: editor.toggleTheme,
        child: head,
      ),
    );
  }
}

/// One value of the table: highlighted in the column being edited, faded in
/// the other one, with where it comes from under it and, for a setting of
/// the layer's own in the edited version, a button that gives back the
/// shared value.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.active,
    required this.origin,
    required this.own,
    required this.child,
    this.onReset,
    this.resetKey,
  });

  final bool active;
  final String origin;
  final bool own;
  final Widget child;
  final VoidCallback? onReset;
  final Key? resetKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = GalleryColors.of(context).muted;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Opacity(
        opacity: active ? 1 : .55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? scheme.primary.withValues(alpha: .08) : null,
            border: Border.all(
              color: active ? scheme.primary.withValues(alpha: .6) : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      child,
                      Text(
                        origin,
                        style: TextStyle(
                          fontSize: 11,
                          color: own ? scheme.primary : muted,
                          fontWeight: own ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active && own && onReset != null)
                  IconButton(
                    key: resetKey,
                    tooltip: l10n.themeUseShared,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: onReset,
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A fill or outline: a swatch and its hex code, or what it is when it is
/// not a plain color (none, a gradient).
class _PaintValue extends StatelessWidget {
  const _PaintValue({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paint = value;
    final hex = paint != null && paint.startsWith('#') ? paint : null;
    final color = hex == null ? null : Color(int.parse('FF${hex.substring(1)}', radix: 16));
    final Widget swatch = color != null
        ? Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          )
        : Icon(
            paint != null && paint.startsWith('url(')
                ? Icons.gradient_rounded
                : Icons.block_rounded,
            size: 16,
          );
    final text =
        hex ?? (paint != null && paint.startsWith('url(') ? l10n.themeGradient : l10n.themeNoPaint);
    return Row(
      children: [
        swatch,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
