import 'package:flutter/material.dart';

/// App-specific colors that Material's [ColorScheme] does not cover.
@immutable
class GalleryColors extends ThemeExtension<GalleryColors> {
  const GalleryColors({
    required this.stage,
    required this.stageGrid,
    required this.muted,
    required this.success,
    required this.danger,
    required this.favorite,
    required this.sun,
    required this.moon,
    required this.codeBackground,
    required this.codeGutter,
    required this.codeText,
    required this.codeTag,
    required this.codeAttribute,
    required this.codeValue,
    required this.codeComment,
    required this.codePunctuation,
  });

  final Color stage;
  final Color stageGrid;
  final Color muted;
  final Color success;
  final Color danger;
  final Color favorite;

  /// Marks for what belongs to the light (sun) and the dark (moon) version of
  /// a drawing. Fixed, so they never clash with the accent color.
  final Color sun;
  final Color moon;
  final Color codeBackground;
  final Color codeGutter;
  final Color codeText;
  final Color codeTag;
  final Color codeAttribute;
  final Color codeValue;
  final Color codeComment;
  final Color codePunctuation;

  static GalleryColors of(BuildContext context) => Theme.of(context).extension<GalleryColors>()!;

  @override
  GalleryColors copyWith({Color? stage, Color? muted}) => GalleryColors(
    stage: stage ?? this.stage,
    stageGrid: stageGrid,
    muted: muted ?? this.muted,
    success: success,
    danger: danger,
    favorite: favorite,
    sun: sun,
    moon: moon,
    codeBackground: codeBackground,
    codeGutter: codeGutter,
    codeText: codeText,
    codeTag: codeTag,
    codeAttribute: codeAttribute,
    codeValue: codeValue,
    codeComment: codeComment,
    codePunctuation: codePunctuation,
  );

  @override
  GalleryColors lerp(covariant GalleryColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GalleryColors(
      stage: mix(stage, other.stage),
      stageGrid: mix(stageGrid, other.stageGrid),
      muted: mix(muted, other.muted),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
      favorite: mix(favorite, other.favorite),
      sun: mix(sun, other.sun),
      moon: mix(moon, other.moon),
      codeBackground: mix(codeBackground, other.codeBackground),
      codeGutter: mix(codeGutter, other.codeGutter),
      codeText: mix(codeText, other.codeText),
      codeTag: mix(codeTag, other.codeTag),
      codeAttribute: mix(codeAttribute, other.codeAttribute),
      codeValue: mix(codeValue, other.codeValue),
      codeComment: mix(codeComment, other.codeComment),
      codePunctuation: mix(codePunctuation, other.codePunctuation),
    );
  }
}
