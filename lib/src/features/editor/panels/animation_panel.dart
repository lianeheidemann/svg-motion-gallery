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

  /// Strength of the motion, 1 = the original (shown as 100 %). Kept for the
  /// next motion picked; a layer that already has one shows its own.
  var _intensity = 1.0;
  double? _liveIntensity;

  /// The cycle of [_base] (at speed 1), kept so the text under the title can
  /// follow the speed bar without reading the document on every move.
  Duration? _baseCycle;
  String? _baseCycleOf;

  EditorController get _editor => widget.editor;

  /// Puts [preset] on the layer at [path] (replacing its motion), lasting
  /// [seconds] with strength [intensity] (the bars' values when not given).
  /// With [preview] it only shows the result, without recording it.
  void _setPreset(
    ElementPath path,
    SvgAnimationPreset preset, {
    double? seconds,
    double? intensity,
    bool preview = false,
  }) {
    setState(() {
      _seconds = seconds ?? _seconds;
      _intensity = intensity ?? _intensity;
    });
    String edit(String svg, ElementPath target) => SvgAnimationEdit.addPreset(
      svg,
      target,
      preset,
      seconds: _seconds,
      intensity: _intensity,
    ).svg;
    // Several layers ticked, or nothing selected ("Todas"): every one of them.
    if (_editor.multiMode || _editor.selection == null) {
      if (preview) {
        var out = _editor.svg;
        for (final target in _motionTargets().reversed) {
          out = edit(out, target);
        }
        _editor.preview(out);
      } else {
        _editor.applyToTargets(edit, paths: _motionTargets());
      }
    } else if (preview) {
      _editor.preview(edit(_editor.svg, path));
    } else {
      _editor.apply(
        SvgAnimationEdit.addPreset(
          _editor.svg,
          path,
          preset,
          seconds: _seconds,
          intensity: _intensity,
        ),
      );
    }
  }

  /// The strength to show: the layer's own when it has a motion, else the one
  /// the next motion will get.
  double _shownIntensity(ElementPath? path, SvgAnimationPreset? chosen) =>
      path == null || chosen == null ? _intensity : SvgAnimationEdit.intensityAt(_editor.svg, path);

  /// The layers the speed bar applied to; a new selection starts it over.
  List<ElementPath> _baseTargets = const [];

  /// The layers a motion goes on: the edit targets (a layer's motion is
  /// replaced where it is, never wrapped again).
  List<ElementPath> _motionTargets() => _editor.editTargets;

  void _syncBase() {
    final targets = _editor.targets;
    final sameTargets =
        targets.length == _baseTargets.length &&
        [for (var i = 0; i < targets.length; i++) targets[i] == _baseTargets[i]].every((e) => e);
    if (sameTargets && _editor.svg == (_applied ?? _base)) return;
    _baseTargets = targets;
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
    // With several layers ticked the chips show the first one's motion.
    final presetPath = _editor.multiMode || layer == null
        ? _motionTargets().firstOrNull
        : layer.path;
    final currentPreset = presetPath == null
        ? null
        : SvgAnimationEdit.presetAt(_editor.svg, presetPath);
    // The cycle at the speed on the bar: the document at speed 1 divided by it.
    final baseText = _base ?? _editor.svg;
    if (_baseCycleOf != baseText) {
      _baseCycleOf = baseText;
      _baseCycle = SvgMetadata.parse(baseText).cycleDuration;
    }
    final baseCycle = _baseCycle;
    final seconds = baseCycle == null ? null : baseCycle.inMilliseconds / 1000 / _speed;
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
            // Only the duration, which follows the speed bar while it moves.
            if (!metadata.isAnimated)
              Text(l10n.animationsNone)
            else if (seconds != null)
              Text(l10n.durationSeconds(l10n.decimal(seconds))),
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
                  final result = SvgAnimationEdit.changeSpeed(
                    _base ?? _editor.svg,
                    v,
                    only: _editor.targets,
                  );
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
            if (presetPath == null)
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
                      if (_editor.multiMode || layer == null) {
                        _editor.applyToTargets(
                          (svg, target) => SvgAnimationEdit.removePreset(svg, target).svg,
                          paths: _motionTargets(),
                        );
                      } else if (currentPreset != null) {
                        _editor.apply(SvgAnimationEdit.removePreset(_editor.svg, layer.path));
                      }
                    },
                  ),
                  for (final preset in SvgAnimationPreset.values)
                    ChoiceChip(
                      label: Text(l10n.preset(preset)),
                      selected: preset == chosen,
                      onSelected: (_) => _setPreset(presetPath, preset),
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
                onChangeEnd: chosen == null
                    ? null
                    : (v) => _setPreset(presetPath, chosen, seconds: v),
              ),
              // How strong the chosen motion is. A spin is always a full turn.
              SliderField(
                key: const Key('preset-intensity'),
                label: l10n.intensity,
                value: ((_liveIntensity ?? _shownIntensity(presetPath, chosen)) * 100).clamp(
                  10,
                  200,
                ),
                min: 10,
                max: 200,
                unit: '%',
                onChanged: chosen == null || chosen == SvgAnimationPreset.spin
                    ? null
                    : (v) {
                        setState(() => _liveIntensity = v.roundToDouble() / 100);
                        _setPreset(
                          presetPath,
                          chosen,
                          intensity: v.roundToDouble() / 100,
                          preview: true,
                        );
                      },
                onChangeEnd: chosen == null || chosen == SvgAnimationPreset.spin
                    ? null
                    : (v) {
                        _liveIntensity = null;
                        _setPreset(presetPath, chosen, intensity: v.roundToDouble() / 100);
                      },
              ),
            ],
          ],
        ),
      ],
    );
  }
}
