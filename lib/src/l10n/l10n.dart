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

  /// Human label of a layer: text content, `#id`, or a translated tag name.
  String layer(SvgLayer layer) {
    if (layer.isEditorGroup) return layerEditorGroup;
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
