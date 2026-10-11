import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../../l10n/l10n.dart';

/// The sun of the light version or the moon of the dark one.
IconData themeIcon(SvgColorScheme scheme, {bool outlined = false}) => scheme == SvgColorScheme.light
    ? (outlined ? Icons.light_mode_outlined : Icons.light_mode_rounded)
    : (outlined ? Icons.dark_mode_outlined : Icons.dark_mode_rounded);

/// The color of [scheme]'s mark: in color while that version is the one
/// being edited, greyed out otherwise.
Color themeColor(BuildContext context, SvgColorScheme scheme, {required bool active}) {
  final colors = GalleryColors.of(context);
  if (!active) return colors.muted.withValues(alpha: .7);
  return scheme == SvgColorScheme.light ? colors.sun : colors.moon;
}

/// What a layer's marks say, one line per version, for the tooltip and
/// screen readers. [nameOf] names the group a setting comes from.
String themeMarkSummary(
  AppLocalizations l10n,
  SvgThemeMark mark,
  SvgColorScheme active,
  String Function(ElementPath path) nameOf,
) {
  final lines = [
    for (final scheme in SvgColorScheme.values)
      switch (mark.originIn(scheme)) {
        SvgThemeOrigin.own => l10n.themeMarkOwn(l10n.themeName(scheme)),
        SvgThemeOrigin.inherited => l10n.themeMarkInherited(
          nameOf(mark.sourceIn(scheme)!),
          l10n.themeName(scheme),
        ),
        null => null,
      },
    if (!mark.shownIn.contains(active)) l10n.themeNotShown(l10n.themeName(active)),
  ];
  return lines.nonNulls.join('\n');
}

/// The sun and moon after a layer's name: a solid one when the layer has a
/// setting of its own for that version, an outlined one when it takes it
/// from a group around it, with "↳ herda" when everything is taken from a
/// group (just "↳" deeper inside that group, to keep the list calm). The
/// version being edited is in color, the other one greyed out. A tap opens
/// the layer's theme settings.
class ThemeMarkBadge extends StatelessWidget {
  const ThemeMarkBadge({
    super.key,
    required this.mark,
    required this.active,
    required this.label,
    this.startsHere = true,
    this.onTap,
  });

  final SvgThemeMark mark;

  /// The version being edited.
  final SvgColorScheme active;

  /// What the marks mean (see [themeMarkSummary]).
  final String label;

  /// Whether the group the settings come from is the one right around the
  /// layer: "↳ herda" is then written out; deeper inside, the arrow is enough.
  final bool startsHere;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final origins = {for (final scheme in SvgColorScheme.values) scheme: ?mark.originIn(scheme)};
    final onlyInherited =
        origins.isNotEmpty && origins.values.every((origin) => origin == SvgThemeOrigin.inherited);
    return Tooltip(
      message: label,
      child: Semantics(
        button: onTap != null,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final MapEntry(key: scheme, value: origin) in origins.entries)
                  Icon(
                    themeIcon(scheme, outlined: origin == SvgThemeOrigin.inherited),
                    size: 18,
                    color: themeColor(context, scheme, active: scheme == active),
                  ),
                if (onlyInherited) ...[
                  const SizedBox(width: 3),
                  InheritsPill(compact: !startsHere),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "↳ herda" tag of a layer whose theme settings all come from a
/// group around it.
class InheritsPill extends StatelessWidget {
  const InheritsPill({super.key, this.compact = false});

  /// Only the arrow, without the word.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(3, 2, compact ? 3 : 6, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // An icon, not "↳": not every font has that character.
            Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: scheme.primary),
            if (!compact) ...[
              const SizedBox(width: 1),
              Text(
                context.l10n.themeInherits,
                style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tiny suns and moons next to the "+N" of a folded folder: some layer
/// inside it has a setting of its own for that version.
class ThemeInsideMarks extends StatelessWidget {
  const ThemeInsideMarks({super.key, required this.schemes, required this.active});

  final Set<SvgColorScheme> schemes;
  final SvgColorScheme active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.themeInside,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final scheme in SvgColorScheme.values)
            if (schemes.contains(scheme))
              Icon(
                themeIcon(scheme),
                size: 12,
                color: themeColor(context, scheme, active: scheme == active),
              ),
        ],
      ),
    );
  }
}
