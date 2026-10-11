/// Pure Dart toolkit to inspect, validate, theme and edit SVG documents.
///
/// Every operation takes SVG text and returns new SVG text, which keeps the
/// API immutable and makes undo/redo trivial.
library;

export 'src/colors.dart' show SvgColorValue, SvgColors;
export 'src/css_inliner.dart' show SvgCssInliner;
export 'src/editing/animation.dart' show SvgAnimationEdit, SvgAnimationPreset;
export 'src/editing/element_path.dart' show ElementPath, SvgEditResult;
export 'src/editing/hit_test.dart' show SvgBounds, SvgHitTest, SvgMovable;
export 'src/editing/insert.dart' show SvgInsertEdit, SvgShapeKind;
export 'src/editing/layers.dart' show SvgLayer, SvgLayers;
export 'src/editing/paint.dart' show ElementPaint, SvgPaintEdit;
export 'src/editing/shape_size.dart' show SvgShapeFactors, SvgShapeSize;
export 'src/editing/theme_edit.dart' show SvgThemeEdit;
export 'src/editing/theme_marks.dart' show SvgThemeMark, SvgThemeMarks, SvgThemeOrigin;
export 'src/editing/transform.dart' show SvgDocumentEdit, SvgTransformEdit, SvgTransformValues;
export 'src/formatting.dart' show formatSvg, wrapSvgLines;
export 'src/highlighter.dart' show SvgToken, SvgTokenType, maxHighlightLength, tokenizeSvg;
export 'src/history.dart' show EditHistory;
export 'src/lint.dart' show lintSvgValues, svgArgbToRgba, svgIssueRange;
export 'src/metadata.dart' show SvgAnimationKind, SvgMetadata, SvgViewBox;
export 'src/playback.dart' show forceLoop, forcePlayOnce;
export 'src/sanitizer.dart' show sanitizeSvg;
export 'src/theme/color_scheme.dart' show SvgColorScheme;
export 'src/theme/theme_resolver.dart' show SvgThemeResolver;
export 'src/theme/theme_support.dart' show SvgThemeMechanism, SvgThemeSupport;
export 'src/time.dart' show formatClockValue, parseClockValue;
export 'src/validation.dart' show SvgIssue, SvgIssueCode, SvgValidation, validateSvg;
