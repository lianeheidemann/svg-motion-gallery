import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Lines the selected layer up with the sides or the middle of the canvas.
/// The renderer measures where the layer is drawn (groups and animated
/// layers included), so any layer can be aligned.
class AlignPanel extends StatefulWidget {
  const AlignPanel({super.key, required this.editor, this.playback});

  final EditorController editor;
  final SvgPlaybackController? playback;

  @override
  State<AlignPanel> createState() => _AlignPanelState();
}

class _AlignPanelState extends State<AlignPanel> {
  var _busy = false;
  var _failed = false;

  EditorController get _editor => widget.editor;

  Future<void> _align(String horizontal, String vertical) async {
    final targets = _editor.targets;
    final playback = widget.playback;
    if (targets.isEmpty || playback == null || _busy) return;
    final several = targets.length > 1;
    setState(() {
      _busy = true;
      _failed = false;
    });
    // The renderer measures one element at a time, so each ticked layer is
    // pointed at in turn; every offset is measured against the same drawing.
    final offsets = <ElementPath, Offset>{};
    for (final path in targets) {
      if (several) playback.selectElement(path.indices);
      final offset = await playback.alignmentOffset(horizontal: horizontal, vertical: vertical);
      if (offset == null) break;
      offsets[path] = offset;
    }
    if (several) {
      playback.selectElement(
        _editor.selection?.indices,
        also: [
          for (final path in _editor.targets)
            if (path != _editor.selection) path.indices,
        ],
      );
    }
    if (!mounted) return;
    final measured = offsets.length == targets.length;
    setState(() {
      _busy = false;
      _failed = !measured;
    });
    // The selection may have changed while the renderer was measuring.
    if (!measured || !listEquals(_editor.targets, targets)) return;
    var svg = _editor.svg;
    SvgEditResult? single;
    // Last layer first, so wrapping one never moves the path of another.
    for (final path in targets.reversed) {
      final offset = offsets[path]!;
      if (offset.dx.abs() < 1e-6 && offset.dy.abs() < 1e-6) continue;
      final now = SvgTransformEdit.read(svg, path);
      single = SvgTransformEdit.apply(
        svg,
        path,
        now.copyWith(
          translateX: now.translateX + offset.dx,
          translateY: now.translateY + offset.dy,
        ),
      );
      svg = single.svg;
    }
    if (single == null) return;
    if (several) {
      _editor.commit(svg);
    } else {
      _editor.apply(single);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = _editor.targets.isNotEmpty && widget.playback != null && !_busy;

    Widget button(Key key, IconData icon, String tooltip, String h, String v) =>
        IconButton.outlined(
          key: key,
          tooltip: tooltip,
          onPressed: enabled ? () => _align(h, v) : null,
          icon: Icon(icon),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.align_horizontal_center_rounded,
          title: l10n.alignTitle,
          children: [
            if (_editor.selection == null)
              Text(l10n.selectLayerHint, style: TextStyle(color: GalleryColors.of(context).muted)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                button(
                  const Key('align-left'),
                  Icons.align_horizontal_left_rounded,
                  l10n.alignLeft,
                  'start',
                  '',
                ),
                button(
                  const Key('align-center-h'),
                  Icons.align_horizontal_center_rounded,
                  l10n.alignCenterH,
                  'center',
                  '',
                ),
                button(
                  const Key('align-right'),
                  Icons.align_horizontal_right_rounded,
                  l10n.alignRight,
                  'end',
                  '',
                ),
                button(
                  const Key('align-top'),
                  Icons.align_vertical_top_rounded,
                  l10n.alignTop,
                  '',
                  'start',
                ),
                button(
                  const Key('align-center-v'),
                  Icons.align_vertical_center_rounded,
                  l10n.alignCenterV,
                  '',
                  'center',
                ),
                button(
                  const Key('align-bottom'),
                  Icons.align_vertical_bottom_rounded,
                  l10n.alignBottom,
                  '',
                  'end',
                ),
                button(
                  const Key('align-center'),
                  Icons.filter_center_focus_rounded,
                  l10n.alignCenter,
                  'center',
                  'center',
                ),
              ],
            ),
            if (_failed) Text(l10n.alignFailed, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ],
    );
  }
}
