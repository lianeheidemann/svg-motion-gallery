import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Size of the document (its width and height in pixels), with a lock to keep
/// the proportion. Every value has a slider.
class SizePanel extends StatefulWidget {
  const SizePanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<SizePanel> createState() => _SizePanelState();
}

class _SizePanelState extends State<SizePanel> {
  ({double width, double height})? _liveSize;
  var _lockAspect = true;

  EditorController get _editor => widget.editor;

  void _previewSize(double width, double height) {
    setState(() => _liveSize = (width: width, height: height));
    _editor.preview(SvgDocumentEdit.setSize(_editor.svg, width: width, height: height));
  }

  void _commitSize() {
    final size = _liveSize;
    _liveSize = null;
    if (size == null) return;
    _editor.commit(SvgDocumentEdit.setSize(_editor.svg, width: size.width, height: size.height));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = _editor.metadata;
    final canvas = metadata.canvas;
    final width = _liveSize?.width ?? metadata.displayWidth ?? canvas.width;
    final height = _liveSize?.height ?? metadata.displayHeight ?? canvas.height;
    final ratio = height == 0 ? 1.0 : width / height;
    final sizeMax = math.max(2048.0, math.max(width, height) * 2).roundToDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.aspect_ratio_rounded,
          title: l10n.documentSize,
          spacing: 6,
          trailing: IconButton(
            tooltip: _lockAspect ? l10n.unlockAspect : l10n.lockAspect,
            isSelected: _lockAspect,
            onPressed: () => setState(() => _lockAspect = !_lockAspect),
            icon: const Icon(Icons.link_off_rounded),
            selectedIcon: const Icon(Icons.link_rounded),
          ),
          children: [
            SliderField(
              label: l10n.width,
              value: width.clamp(1, sizeMax),
              min: 1,
              max: sizeMax,
              unit: 'px',
              onChanged: (v) => _previewSize(
                v.roundToDouble(),
                _lockAspect ? (v / ratio).roundToDouble() : height,
              ),
              onChangeEnd: (_) => _commitSize(),
            ),
            SliderField(
              label: l10n.height,
              value: height.clamp(1, sizeMax),
              min: 1,
              max: sizeMax,
              unit: 'px',
              onChanged: (v) => _previewSize(
                _lockAspect ? (v * ratio).roundToDouble() : width,
                v.roundToDouble(),
              ),
              onChangeEnd: (_) => _commitSize(),
            ),
          ],
        ),
      ],
    );
  }
}
