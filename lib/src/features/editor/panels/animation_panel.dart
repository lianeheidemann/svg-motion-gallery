import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/svg_view.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Speed and removal of existing animations, and ready-made motions for the
/// selected layer.
class AnimationPanel extends StatefulWidget {
  const AnimationPanel({super.key, required this.editor, this.playback});

  final EditorController editor;

  /// Stage playback; paused while the speed bar is dragged so the moving
  /// animation does not compete with the slider for frames.
  final SvgPlaybackController? playback;

  @override
  State<AnimationPanel> createState() => _AnimationPanelState();
}

class _AnimationPanelState extends State<AnimationPanel> {
  /// Speed shown by the bar, relative to [_base].
  var _speed = 1.0;
  var _resumeAfterDrag = false;

  /// The document at speed 1. Every speed is computed from it, so changing
  /// the speed twice never compounds (and rounding never drifts to zero).
  String? _base;

  /// What the last speed change produced. When the document is anything else
  /// (undo, another edit) the bar starts over from that document.
  String? _applied;

  var _seconds = 2.0;

  EditorController get _editor => widget.editor;

  /// Puts [preset] on the layer at [path] (replacing its motion), lasting
  /// [seconds] (the bar's value when not given).
  void _setPreset(ElementPath path, SvgAnimationPreset preset, [double? seconds]) {
    setState(() => _seconds = seconds ?? _seconds);
    _editor.apply(SvgAnimationEdit.addPreset(_editor.svg, path, preset, seconds: _seconds));
  }

  void _syncBase() {
    if (_editor.svg == (_applied ?? _base)) return;
    _base = _editor.svg;
    _applied = null;
    _speed = 1;
  }

  @override
  Widget build(BuildContext context) {
    _syncBase();
    final l10n = context.l10n;
    final muted = TextStyle(color: GalleryColors.of(context).muted);
    final metadata = _editor.metadata;
    final layer = _editor.selectedLayer;
    final currentPreset = layer == null ? null : SvgAnimationEdit.presetAt(_editor.svg, layer.path);
    final cycle = metadata.cycleDuration;
    // The chips show what the layer has; tapping one applies it right away.
    final chosen = currentPreset;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          icon: Icons.animation_rounded,
          title: l10n.animationsTitle,
          spacing: 8,
          children: [
            Text(
              metadata.isAnimated
                  ? '${l10n.animationSummary(metadata)}'
                        '${cycle == null ? '' : ' · ${l10n.cycleSeconds(l10n.decimal(cycle.inMilliseconds / 1000))}'}'
                  : l10n.animationsNone,
            ),
            if (metadata.isAnimated) ...[
              SliderField(
                label: l10n.speed,
                value: _speed,
                min: .25,
                max: 4,
                fractionDigits: 2,
                unit: '×',
                onChangeStart: (_) {
                  final playback = widget.playback;
                  _resumeAfterDrag = playback?.isPlaying ?? false;
                  playback?.pause();
                },
                onChanged: (v) => setState(() => _speed = v),
                onChangeEnd: (v) {
                  final result = SvgAnimationEdit.changeSpeed(_base ?? _editor.svg, v);
                  _applied = result;
                  if (result != _editor.svg) _editor.commit(result);
                  setState(() => _speed = v);
                  if (_resumeAfterDrag) widget.playback?.play();
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _editor.commit(SvgAnimationEdit.removeAll(_editor.svg)),
                  icon: const Icon(Icons.motion_photos_off_outlined),
                  label: Text(l10n.removeAnimations),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          icon: Icons.auto_awesome_motion_outlined,
          title: l10n.presetsTitle,
          spacing: 8,
          children: [
            if (layer == null)
              Text(l10n.selectLayerHint, style: muted)
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('preset-none'),
                    label: Text(l10n.presetNone),
                    selected: chosen == null,
                    // "None" takes the motion off the layer.
                    onSelected: (_) {
                      if (currentPreset != null) {
                        _editor.apply(SvgAnimationEdit.removePreset(_editor.svg, layer.path));
                      }
                    },
                  ),
                  for (final preset in SvgAnimationPreset.values)
                    ChoiceChip(
                      label: Text(l10n.preset(preset)),
                      selected: preset == chosen,
                      onSelected: (_) => _setPreset(layer.path, preset),
                    ),
                ],
              ),
              SliderField(
                label: l10n.duration,
                value: _seconds,
                min: .5,
                max: 10,
                fractionDigits: 1,
                unit: 's',
                // Nothing to time while "None" is picked.
                onChanged: chosen == null ? null : (v) => setState(() => _seconds = v),
                onChangeEnd: chosen == null ? null : (v) => _setPreset(layer.path, chosen, v),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
