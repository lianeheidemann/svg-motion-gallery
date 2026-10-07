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

  EditorController get _editor => widget.editor;

  void _preview(SvgTransformValues values) {
    setState(() => _live = values);
    _editor.preview(SvgTransformEdit.apply(_editor.svg, _editor.selection, values).svg);
  }

  void _commit([SvgTransformValues? values]) {
    final next = values ?? _live;
    _live = null;
    if (next == null) return;
    _editor.apply(SvgTransformEdit.apply(_editor.svg, _editor.selection, next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layer = _editor.selectedLayer;
    final values = _live ?? SvgTransformEdit.read(_editor.svg, _editor.selection);
    final metadata = _editor.metadata;
    final canvas = metadata.canvas;
    final range = math.max(canvas.width, canvas.height).roundToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.open_with_rounded,
          title: layer == null
              ? l10n.transformDocument
              : l10n.transformLayer(l10n.layerLabel(layer, _editor.layers)),
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
              label: l10n.scale,
              value: (values.scale * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: (v) => _preview(values.copyWith(scale: v.roundToDouble() / 100)),
              onChangeEnd: (_) => _commit(),
            ),
            SliderField(
              label: l10n.width,
              value: (values.widthFactor * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: (v) => _preview(values.copyWith(widthFactor: v.roundToDouble() / 100)),
              onChangeEnd: (_) => _commit(),
            ),
            SliderField(
              label: l10n.height,
              value: (values.heightFactor * 100).clamp(10, 400),
              min: 10,
              max: 400,
              unit: '%',
              onChanged: (v) => _preview(values.copyWith(heightFactor: v.roundToDouble() / 100)),
              onChangeEnd: (_) => _commit(),
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
