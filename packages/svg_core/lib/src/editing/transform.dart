import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../metadata.dart';
import '../xml_support.dart';
import 'element_path.dart';

/// Position, rotation, scale and opacity applied by the editor.
class SvgTransformValues {
  const SvgTransformValues({
    this.translateX = 0,
    this.translateY = 0,
    this.rotation = 0,
    this.scale = 1,
    this.widthFactor = 1,
    this.heightFactor = 1,
    this.opacity = 1,
  });

  static const identity = SvgTransformValues();

  /// Offset in user units (viewBox coordinates).
  final double translateX;
  final double translateY;

  /// Degrees, clockwise, around the center of the target.
  final double rotation;

  /// Uniform scale factor around the center of the target (1 = 100 %).
  final double scale;

  /// Extra stretch of the width and of the height alone (1 = none), on top of
  /// [scale]. The element's own axes are stretched, before it is rotated.
  final double widthFactor;
  final double heightFactor;

  /// 0..1.
  final double opacity;

  bool get isIdentity =>
      translateX == 0 &&
      translateY == 0 &&
      rotation == 0 &&
      scale == 1 &&
      widthFactor == 1 &&
      heightFactor == 1 &&
      opacity == 1;

  SvgTransformValues copyWith({
    double? translateX,
    double? translateY,
    double? rotation,
    double? scale,
    double? widthFactor,
    double? heightFactor,
    double? opacity,
  }) => SvgTransformValues(
    translateX: translateX ?? this.translateX,
    translateY: translateY ?? this.translateY,
    rotation: rotation ?? this.rotation,
    scale: scale ?? this.scale,
    widthFactor: widthFactor ?? this.widthFactor,
    heightFactor: heightFactor ?? this.heightFactor,
    opacity: opacity ?? this.opacity,
  );

  String get _scaleArguments => widthFactor == 1 && heightFactor == 1
      ? formatNumber(scale)
      : '${formatNumber(scale * widthFactor)} ${formatNumber(scale * heightFactor)}';

  String get _transformAttribute =>
      'translate(${formatNumber(translateX)} ${formatNumber(translateY)}) '
      'rotate(${formatNumber(rotation)}) scale($_scaleArguments)';

  @override
  bool operator ==(Object other) =>
      other is SvgTransformValues &&
      other.translateX == translateX &&
      other.translateY == translateY &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.widthFactor == widthFactor &&
      other.heightFactor == heightFactor &&
      other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(translateX, translateY, rotation, scale, widthFactor, heightFactor, opacity);
}

/// Applies [SvgTransformValues] through an editor-owned `<g>` wrapper, so the
/// element's own `transform` is never rewritten and edits stay reversible.
/// Rotation and scale pivot on the wrapper's bounding-box center via
/// `transform-box: fill-box; transform-origin: center`.
class SvgTransformEdit {
  const SvgTransformEdit._();

  static const _wrapperStyle = 'transform-box:fill-box;transform-origin:center';

  /// Current values of [target]; null or root means the whole drawing.
  static SvgTransformValues read(String svg, ElementPath? target) {
    final document = tryParseSvg(svg);
    if (document == null) return SvgTransformValues.identity;
    final wrapper = _existingWrapper(document.rootElement, target);
    return wrapper == null ? SvgTransformValues.identity : _parse(wrapper);
  }

  /// Sets [values] on [target] (null or root = whole drawing). Returns the
  /// new document and the path to keep selected.
  static SvgEditResult apply(String svg, ElementPath? target, SvgTransformValues values) {
    final document = tryParseSvg(svg);
    if (document == null) return SvgEditResult(svg, selection: target);
    final root = document.rootElement;
    final isDocument = target == null || target.isRoot || _isRootWrapper(target.resolve(root));
    final element = isDocument ? null : target.resolve(root);
    if (!isDocument && element == null) return SvgEditResult(svg, selection: target);

    var wrapper = _existingWrapper(root, target);
    if (wrapper == null && values.isIdentity) return SvgEditResult(svg, selection: target);
    wrapper ??= isDocument ? _wrapDocument(root) : _wrapElement(element!);
    if (wrapper == null) return SvgEditResult(svg, selection: target);

    if (values.isIdentity) {
      final firstChild = wrapper.childElements.firstOrNull;
      _unwrap(wrapper);
      return SvgEditResult(
        document.toXmlString(),
        selection: isDocument || firstChild == null ? null : ElementPath.of(firstChild),
      );
    }
    wrapper
      ..setAttribute('transform', values._transformAttribute)
      ..setAttribute('opacity', values.opacity == 1 ? null : formatNumber(values.opacity))
      ..setAttribute('style', _wrapperStyle);
    return SvgEditResult(
      document.toXmlString(),
      selection: isDocument ? null : ElementPath.of(wrapper),
    );
  }

  static bool _isRootWrapper(XmlElement? element) =>
      element?.getAttribute(editorAttribute) == 'root';

  static XmlElement? _existingWrapper(XmlElement root, ElementPath? target) {
    if (target == null || target.isRoot) {
      return root.childElements.where(_isRootWrapper).firstOrNull;
    }
    final element = target.resolve(root);
    if (element == null) return null;
    if (element.getAttribute(editorAttribute) != null) return element;
    final parent = element.parentElement;
    if (parent != null &&
        parent.getAttribute(editorAttribute) == 'element' &&
        parent.childElements.where(isVisual).length == 1) {
      return parent;
    }
    return null;
  }

  static XmlElement? _wrapDocument(XmlElement root) {
    final visual = root.childElements.where(isVisual).toList();
    if (visual.isEmpty) return null;
    final wrapper = buildElement('g', attributes: {editorAttribute: 'root'});
    root.children.insert(root.children.indexOf(visual.first), wrapper);
    wrapper.children.addAll(visual);
    return wrapper;
  }

  static XmlElement _wrapElement(XmlElement element) {
    final wrapper = buildElement('g', attributes: {editorAttribute: 'element'});
    final siblings = element.parent!.children;
    siblings.insert(siblings.indexOf(element), wrapper);
    wrapper.children.add(element);
    return wrapper;
  }

  static void _unwrap(XmlElement wrapper) {
    final nodes = wrapper.parent!.children;
    final index = nodes.indexOf(wrapper);
    final children = wrapper.children.toList();
    wrapper.remove();
    nodes.insertAll(index, children);
  }

  static final _function = RegExp(r'(translate|rotate|scale)\(([^)]*)\)');

  static SvgTransformValues _parse(XmlElement wrapper) {
    var values = SvgTransformValues(
      opacity: double.tryParse(wrapper.getAttribute('opacity') ?? '') ?? 1,
    );
    for (final match in _function.allMatches(wrapper.getAttribute('transform') ?? '')) {
      final numbers = match
          .group(2)!
          .trim()
          .split(RegExp(r'[\s,]+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      if (numbers.isEmpty) continue;
      values = switch (match.group(1)) {
        'translate' => values.copyWith(
          translateX: numbers[0],
          translateY: numbers.length > 1 ? numbers[1] : 0,
        ),
        'rotate' => values.copyWith(rotation: numbers[0]),
        _ => values.copyWith(
          scale: numbers[0],
          // scale(sx sy): the height is stretched relative to the width.
          heightFactor: numbers.length > 1 && numbers[0] != 0 ? numbers[1] / numbers[0] : 1,
        ),
      };
    }
    return values;
  }
}

/// Document-level edits.
class SvgDocumentEdit {
  const SvgDocumentEdit._();

  /// Adds `viewBox="0 0 width height"` when the root has a numeric size but
  /// no viewBox, so the drawing scales to any container instead of being
  /// cropped. Returns [svg] unchanged otherwise.
  static String ensureViewBox(String svg) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    if (root.getAttribute('viewBox') != null) return svg;
    final width = parseLength(root.getAttribute('width'));
    final height = parseLength(root.getAttribute('height'));
    if (width == null || height == null || width <= 0 || height <= 0) return svg;
    root.setAttribute('viewBox', '0 0 ${formatNumber(width)} ${formatNumber(height)}');
    return document.toXmlString();
  }

  /// Sets the window of the drawing: the part of the canvas that is shown
  /// (the `viewBox`). Anything outside it is cropped. A numeric root
  /// `width`/`height` is scaled with the window, so one unit keeps the same
  /// size on screen and the file's pixel size follows the crop.
  static String setViewBox(
    String svg, {
    required double minX,
    required double minY,
    required double width,
    required double height,
  }) {
    if (!(width > 0) || !(height > 0)) return svg;
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    final oldWidth = parseLength(root.getAttribute('width'));
    final oldHeight = parseLength(root.getAttribute('height'));
    final old =
        SvgViewBox.tryParse(root.getAttribute('viewBox')) ??
        (oldWidth != null && oldHeight != null && oldWidth > 0 && oldHeight > 0
            ? SvgViewBox(0, 0, oldWidth, oldHeight)
            : null);
    root.setAttribute(
      'viewBox',
      '${formatNumber(minX)} ${formatNumber(minY)} ${formatNumber(width)} ${formatNumber(height)}',
    );
    if (old != null) {
      if (oldWidth != null) root.setAttribute('width', formatNumber(oldWidth * width / old.width));
      if (oldHeight != null) {
        root.setAttribute('height', formatNumber(oldHeight * height / old.height));
      }
    }
    return document.toXmlString();
  }

  /// Crops the window to the box ([x], [y], [width], [height]) of the content,
  /// grown by [margin] (a fraction of the box's larger side) on every side.
  static String fitWindow(
    String svg, {
    required double x,
    required double y,
    required double width,
    required double height,
    double margin = 0,
  }) {
    final pad = math.max(width, height) * margin;
    return setViewBox(
      svg,
      minX: x - pad,
      minY: y - pad,
      width: math.max(width + 2 * pad, 0.001),
      height: math.max(height + 2 * pad, 0.001),
    );
  }

  /// Sets the root `width`/`height`. A `viewBox` matching the previous size
  /// is added first when missing, so the drawing scales instead of cropping.
  static String setSize(String svg, {required double width, required double height}) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    if (root.getAttribute('viewBox') == null) {
      final oldWidth = parseLength(root.getAttribute('width')) ?? width;
      final oldHeight = parseLength(root.getAttribute('height')) ?? height;
      root.setAttribute('viewBox', '0 0 ${formatNumber(oldWidth)} ${formatNumber(oldHeight)}');
    }
    root
      ..setAttribute('width', formatNumber(width))
      ..setAttribute('height', formatNumber(height));
    return document.toXmlString();
  }
}
