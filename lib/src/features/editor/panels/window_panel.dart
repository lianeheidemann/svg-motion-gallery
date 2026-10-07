import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// The window: the part of the drawing that is shown. It can be cropped by
/// hand (position, size, proportion) or fitted to the content, ignoring empty
/// borders. When the drawing moves, every position it reaches is counted.
class WindowPanel extends StatefulWidget {
  const WindowPanel({super.key, required this.editor, this.playback});

  final EditorController editor;
  final SvgPlaybackController? playback;

  @override
  State<WindowPanel> createState() => _WindowPanelState();
}

class _WindowPanelState extends State<WindowPanel> {
  static const _ratios = <(String, double)>[
    ('1:1', 1),
    ('4:3', 4 / 3),
    ('3:4', 3 / 4),
    ('16:9', 16 / 9),
    ('9:16', 9 / 16),
  ];

  late final SvgViewBox _base = widget.editor.metadata.canvas;
  SvgViewBox? _live;
  var _margin = 4.0;
  bool? _withMotion;
  var _fitting = false;
  var _failed = false;

  EditorController get _editor => widget.editor;

  SvgViewBox get _window => _live ?? _editor.metadata.canvas;

  String _with(String svg, SvgViewBox w) =>
      SvgDocumentEdit.setViewBox(svg, minX: w.minX, minY: w.minY, width: w.width, height: w.height);

  void _preview(SvgViewBox w) {
    setState(() => _live = w);
    _editor.preview(_with(_editor.svg, w));
  }

  void _commit([SvgViewBox? w]) {
    final target = w ?? _live;
    _live = null;
    if (target != null) _editor.commit(_with(_editor.svg, target));
    setState(() {});
  }

  /// Largest window with [ratio] that fits inside the current one, centered.
  SvgViewBox _withRatio(double ratio) {
    final w = _window;
    var width = w.width;
    var height = width / ratio;
    if (height > w.height) {
      height = w.height;
      width = height * ratio;
    }
    return SvgViewBox(w.centerX - width / 2, w.centerY - height / 2, width, height);
  }

  Future<void> _fit() async {
    final playback = widget.playback;
    if (playback == null) return;
    final metadata = _editor.metadata;
    final moving = (_withMotion ?? metadata.isAnimated) && metadata.isAnimated;
    setState(() {
      _fitting = true;
      _failed = false;
    });
    final box = await playback.measureContent(cycle: moving ? metadata.cycleDuration : null);
    if (!mounted) return;
    setState(() => _fitting = false);
    if (box == null || box.width <= 0 || box.height <= 0) {
      setState(() => _failed = true);
      return;
    }
    _editor.commit(
      SvgDocumentEdit.fitWindow(
        _editor.svg,
        x: box.left,
        y: box.top,
        width: box.width,
        height: box.height,
        margin: _margin / 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = _editor.metadata;
    final w = _window;
    final span = math.max(_base.width, _base.height);
    final animated = metadata.isAnimated;
    final withMotion = _withMotion ?? animated;
    final original = SvgMetadata.parse(_editor.initialSvg).canvas;
    final changed =
        original.minX != w.minX ||
        original.minY != w.minY ||
        original.width != w.width ||
        original.height != w.height;

    Widget slider(
      String label,
      double value,
      double min,
      double max,
      SvgViewBox Function(double) edit,
    ) => SliderField(
      label: label,
      value: value.clamp(min, max),
      min: min,
      max: max,
      fractionDigits: 1,
      onChanged: (v) => _preview(edit(v)),
      onChangeEnd: (_) => _commit(),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.crop_rounded,
          title: l10n.windowTitle,
          spacing: 6,
          trailing: IconButton(
            key: const Key('window-restore'),
            tooltip: l10n.windowRestore,
            onPressed: changed ? () => _commit(original) : null,
            icon: const Icon(Icons.restore_rounded),
          ),
          children: [
            Text(l10n.windowRatio, style: const TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, ratio) in _ratios)
                  ActionChip(
                    key: Key('ratio-$label'),
                    label: Text(label),
                    onPressed: () => _commit(_withRatio(ratio)),
                  ),
              ],
            ),
            slider(
              l10n.windowX,
              w.minX,
              _base.minX - span,
              _base.minX + span,
              (v) => SvgViewBox(v, w.minY, w.width, w.height),
            ),
            slider(
              l10n.windowY,
              w.minY,
              _base.minY - span,
              _base.minY + span,
              (v) => SvgViewBox(w.minX, v, w.width, w.height),
            ),
            slider(
              l10n.windowWidth,
              w.width,
              span * .02,
              span * 3,
              (v) => SvgViewBox(w.minX, w.minY, v, w.height),
            ),
            slider(
              l10n.windowHeight,
              w.height,
              span * .02,
              span * 3,
              (v) => SvgViewBox(w.minX, w.minY, w.width, v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.fit_screen_rounded,
          title: l10n.windowAdjust,
          spacing: 6,
          children: [
            Text(l10n.windowAdjustHint, style: TextStyle(color: GalleryColors.of(context).muted)),
            SliderField(
              key: const Key('window-margin'),
              label: l10n.windowMargin,
              value: _margin,
              min: 0,
              max: 30,
              unit: '%',
              onChanged: (v) => setState(() => _margin = v.roundToDouble()),
            ),
            SwitchListTile(
              key: const Key('window-motion'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.windowMotion),
              subtitle: animated ? null : Text(l10n.windowNoMotion),
              value: withMotion,
              onChanged: animated ? (v) => setState(() => _withMotion = v) : null,
            ),
            if (_failed)
              Text(l10n.windowFitFailed, style: const TextStyle(color: Colors.redAccent)),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('window-fit'),
                onPressed: _fitting || widget.playback == null ? null : _fit,
                icon: const Icon(Icons.fit_screen_rounded, size: 18),
                label: Text(l10n.windowFit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
