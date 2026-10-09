import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Position, scale, width and height alone, rotation and opacity of the selection (or of the whole
/// drawing). Every value has a slider. The document size has its own tab.
class TransformPanel extends StatefulWidget {
  const TransformPanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<TransformPanel> createState() => _TransformPanelState();
}

class _TransformPanelState extends State<TransformPanel> {
  SvgTransformValues? _live;

  /// Locked (the default): only Scale can be changed, so the object keeps
  /// its proportion. Unlocked: Width and Height are free and Scale is not.
  var _locked = true;

  EditorController get _editor => widget.editor;

  /// What the sliders show: the first ticked layer when several are ticked.
  ElementPath? get _first => _editor.targets.firstOrNull;

  /// Applies [next] to every ticked layer. Each one only takes the values the
  /// user changed ([next] against the first layer's values), so layers keep
  /// their own rotation, scale... When [full] (reset) they take all of [next].
  /// Last layer first, so wrapping one never moves the path of another.
  String _applyToTargets(SvgTransformValues next, {bool full = false}) {
    final svg = _editor.svg;
    final targets = _editor.targets;
    if (targets.isEmpty) return SvgTransformEdit.apply(svg, null, next).svg;
    final base = SvgTransformEdit.read(svg, targets.first);
    var out = svg;
    for (final path in targets.reversed) {
      final own = SvgTransformEdit.read(out, path);
      final merged = full
          ? next
          : SvgTransformValues(
              translateX: next.translateX != base.translateX ? next.translateX : own.translateX,
              translateY: next.translateY != base.translateY ? next.translateY : own.translateY,
              rotation: next.rotation != base.rotation ? next.rotation : own.rotation,
              scale: next.scale != base.scale ? next.scale : own.scale,
              widthFactor: next.widthFactor != base.widthFactor
                  ? next.widthFactor
                  : own.widthFactor,
              heightFactor: next.heightFactor != base.heightFactor
                  ? next.heightFactor
                  : own.heightFactor,
              opacity: next.opacity != base.opacity ? next.opacity : own.opacity,
            );
      out = SvgTransformEdit.apply(out, path, merged).svg;
    }
    return out;
  }

  void _preview(SvgTransformValues values) {
    setState(() => _live = values);
    _editor.preview(
      _editor.multiMode
          ? _applyToTargets(values)
          : SvgTransformEdit.apply(_editor.svg, _editor.selection, values).svg,
    );
  }

  void _commit([SvgTransformValues? values]) {
    final next = values ?? _live;
    _live = null;
    if (next == null) return;
    if (_editor.multiMode) {
      _editor.commit(_applyToTargets(next, full: values != null));
    } else {
      _editor.apply(SvgTransformEdit.apply(_editor.svg, _editor.selection, next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layer = _editor.selectedLayer;
    final values =
        _live ?? SvgTransformEdit.read(_editor.svg, _editor.multiMode ? _first : _editor.selection);
    final metadata = _editor.metadata;
    final canvas = metadata.canvas;
    final range = math.max(canvas.width, canvas.height).roundToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.open_with_rounded,
          title: l10n.tabTransform,
          spacing: 6,
          children: [
            if (layer == null)
              Text(l10n.transformHint, style: TextStyle(color: GalleryColors.of(context).muted)),
            SliderField(
              label: l10n.positionX,
              value: values.translateX.clamp(-range, range),
              min: -range,
              max: range,
              onChanged: (v) => _preview(values.copyWith(translateX: v.roundToDouble())),
              onChangeEnd: (_) => _commit(),
            ),
            SliderField(
              label: l10n.positionY,
              value: values.translateY.clamp(-range, range),
              min: -range,
              max: range,
              onChanged: (v) => _preview(values.copyWith(translateY: v.roundToDouble())),
              onChangeEnd: (_) => _commit(),
            ),
            SliderField(
              key: const Key('transform-scale'),
              label: l10n.scale,
              labelTrailing: IconButton(
                key: const Key('keep-proportion'),
                tooltip: l10n.keepProportion,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: () => setState(() => _locked = !_locked),
                icon: Icon(_locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 18),
              ),
              value: (values.scale * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: _locked
                  ? (v) => _preview(values.copyWith(scale: v.roundToDouble() / 100))
                  : null,
              onChangeEnd: _locked ? (_) => _commit() : null,
            ),
            SliderField(
              key: const Key('transform-width'),
              label: l10n.width,
              value: (values.widthFactor * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: _locked
                  ? null
                  : (v) => _preview(values.copyWith(widthFactor: v.roundToDouble() / 100)),
              onChangeEnd: _locked ? null : (_) => _commit(),
            ),
            SliderField(
              key: const Key('transform-height'),
              label: l10n.height,
              value: (values.heightFactor * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: _locked
                  ? null
                  : (v) => _preview(values.copyWith(heightFactor: v.roundToDouble() / 100)),
              onChangeEnd: _locked ? null : (_) => _commit(),
            ),
            SliderField(
              label: l10n.rotation,
              value: values.rotation.clamp(-180, 180),
              min: -180,
              max: 180,
              unit: '°',
              onChanged: (v) => _preview(values.copyWith(rotation: v.roundToDouble())),
              onChangeEnd: (_) => _commit(),
            ),
            SliderField(
              label: l10n.opacity,
              value: values.opacity * 100,
              min: 0,
              max: 100,
              unit: '%',
              onChanged: (v) => _preview(values.copyWith(opacity: v.roundToDouble() / 100)),
              onChangeEnd: (_) => _commit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: values.isIdentity ? null : () => _commit(SvgTransformValues.identity),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l10n.resetTransform),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
