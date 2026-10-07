import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:svg_core/svg_core.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Formatting and enum labels shared by every screen. Keeping them here
/// means svg_core stays language-agnostic.
extension AppLocalizationsFormat on AppLocalizations {
  String issueMessage(SvgIssue issue) {
    final base = switch (issue.code) {
      SvgIssueCode.empty => issueEmpty,
      SvgIssueCode.rootNotSvg => issueRootNotSvg,
      SvgIssueCode.malformedXml =>
        issue.line == null ? issueMalformed : issueMalformedAt(issue.line!, issue.column ?? 0),
      SvgIssueCode.malformedCss => issue.line == null ? issueCss : issueCssAt(issue.line!),
    };
    return issue.detail == null ? base : '$base — ${issue.detail}';
  }

  String bytes(int bytes) {
    final number = NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1);
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${number.format(kb)} KB';
    return '${number.format(kb / 1024)} MB';
  }

  /// A number with one decimal in the current locale (`2,4` / `2.4`).
  String decimal(double value) =>
      NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1).format(value);

  String dateTime(DateTime value) => DateFormat.yMMMd(localeName).add_Hm().format(value);

  String dimensions(SvgMetadata metadata) {
    final width = metadata.displayWidth;
    final height = metadata.displayHeight;
    if (width == null || height == null) return sizeVector;
    final number = NumberFormat.decimalPattern(localeName);
    return '${number.format(width)} × ${number.format(height)}';
  }

  String animationSummary(SvgMetadata metadata) {
    if (!metadata.isAnimated) return animationsNone;
    final kinds = [
      if (metadata.animationKinds.contains(SvgAnimationKind.css)) 'CSS',
      if (metadata.animationKinds.contains(SvgAnimationKind.smil)) 'SMIL',
    ].join('/');
    return animationsYes(kinds);
  }

  String themeSummary(SvgThemeSupport support) {
    if (!support.isAdaptive) return themeFixed;
    return themeAdaptive(support.mechanisms.map(mechanism).join(', '));
  }

  String mechanism(SvgThemeMechanism mechanism) => switch (mechanism) {
    SvgThemeMechanism.mediaQuery => mechanismMediaQuery,
    SvgThemeMechanism.lightDarkFunction => mechanismLightDark,
    SvgThemeMechanism.currentColor => mechanismCurrentColor,
    SvgThemeMechanism.themeSelector => mechanismSelector,
  };

  String preset(SvgAnimationPreset preset) => switch (preset) {
    SvgAnimationPreset.spin => presetSpin,
    SvgAnimationPreset.pulse => presetPulse,
    SvgAnimationPreset.float => presetFloat,
    SvgAnimationPreset.sway => presetSway,
    SvgAnimationPreset.fade => presetFade,
  };

  String shape(SvgShapeKind kind) => switch (kind) {
    SvgShapeKind.rectangle => shapeRectangle,
    SvgShapeKind.circle => shapeCircle,
    SvgShapeKind.ellipse => shapeEllipse,
    SvgShapeKind.line => shapeLine,
    SvgShapeKind.star => shapeStar,
    SvgShapeKind.text => shapeText,
  };

  String backgroundName(StageBackground background) => switch (background) {
    StageBackground.current => backgroundCurrent,
    StageBackground.light => backgroundLight,
    StageBackground.dark => backgroundDark,
    StageBackground.checkerboard => backgroundChecker,
  };

  /// Labels for a whole layer list: [layer] names, with a number added to
  /// layers that share a name among their siblings, nested like the tree
  /// (`Grupo 1` → `Círculo 1.1`, `Círculo 1.2`; `Grupo 2` → `Círculo 2.1`).
  /// Editor wrappers are transparent: what they wrap counts as their sibling.
  /// Only for display; nothing here is written to the file.
  Map<ElementPath, String> layerLabels(List<SvgLayer> layers) {
    final byPath = {for (final l in layers) l.path: l};

    /// Nearest ancestor that is not an editor wrapper.
    ElementPath ownerOf(SvgLayer layer) {
      var parent = layer.path.parent ?? ElementPath.root;
      while (!parent.isRoot && (byPath[parent]?.isEditorGroup ?? false)) {
        parent = parent.parent ?? ElementPath.root;
      }
      return parent;
    }

    final totals = <ElementPath, Map<String, int>>{};
    for (final l in layers.where((l) => !l.isEditorGroup)) {
      final counts = totals.putIfAbsent(ownerOf(l), () => {});
      counts.update(layer(l), (n) => n + 1, ifAbsent: () => 1);
    }

    final seen = <ElementPath, Map<String, int>>{};
    // The number text of each layer that has one, to prefix its children.
    final numbers = <ElementPath, String>{};
    final labels = <ElementPath, String>{};
    for (final l in layers) {
      final base = layer(l);
      if (l.isEditorGroup) {
        labels[l.path] = base;
        continue;
      }
      final owner = ownerOf(l);
      final total = totals[owner]![base]!;
      if (total < 2) {
        labels[l.path] = base;
        continue;
      }
      final index = seen.putIfAbsent(owner, () => {}).update(base, (n) => n + 1, ifAbsent: () => 1);
      final prefix = numbers[owner];
      final number = prefix == null ? '$index' : '$prefix.$index';
      numbers[l.path] = number;
      labels[l.path] = '$base $number';
    }
    return labels;
  }

  /// The label of [layer] within [all] (see [layerLabels]).
  String layerLabel(SvgLayer layer, List<SvgLayer> all) =>
      layerLabels(all)[layer.path] ?? this.layer(layer);

  /// Human label of a layer: text content, `#id`, or a translated tag name.
  String layer(SvgLayer layer) {
    if (layer.isEditorGroup) return layerEditorGroup;
    if (layer.name != null) return layer.name!;
    final tag = switch (layer.tag) {
      'g' => tagGroup,
      'rect' => shapeRectangle,
      'circle' => shapeCircle,
      'ellipse' => shapeEllipse,
      'line' => shapeLine,
      'polygon' || 'polyline' => tagPolygon,
      'path' => tagPath,
      'text' => shapeText,
      'image' => tagImage,
      'use' => tagUse,
      _ => '<${layer.tag}>',
    };
    final detail = layer.text ?? (layer.id == null ? null : '#${layer.id}');
    return detail == null ? tag : '$tag · $detail';
  }
}
