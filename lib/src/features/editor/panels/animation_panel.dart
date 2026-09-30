import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Speed and removal of existing animations, and ready-made motions for the
/// selected layer.
class AnimationPanel extends StatefulWidget {
  const AnimationPanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<AnimationPanel> createState() => _AnimationPanelState();
}

class _AnimationPanelState extends State<AnimationPanel> {
  var _speed = 1.0;
  var _preset = SvgAnimationPreset.spin;
  var _seconds = 2.0;

  EditorController get _editor => widget.editor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = TextStyle(color: GalleryColors.of(context).muted);
    final metadata = _editor.metadata;
    final layer = _editor.selectedLayer;
    final currentPreset = layer == null ? null : SvgAnimationEdit.presetAt(_editor.svg, layer.path);
    final cycle = metadata.cycleDuration;

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
                onChanged: (v) {
                  setState(() => _speed = v);
                  _editor.preview(SvgAnimationEdit.changeSpeed(_editor.svg, v));
                },
                onChangeEnd: (v) {
                  _editor.commit(SvgAnimationEdit.changeSpeed(_editor.svg, v));
                  setState(() => _speed = 1);
                },
              ),
              Text(l10n.speedHint, style: muted),
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
              Text(l10n.presetTarget(l10n.layer(layer)), style: muted),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in SvgAnimationPreset.values)
                    ChoiceChip(
                      label: Text(l10n.preset(preset)),
                      selected: preset == _preset,
                      onSelected: (_) => setState(() => _preset = preset),
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
                onChanged: (v) => setState(() => _seconds = v),
              ),
              Row(
                children: [
                  if (currentPreset != null)
                    TextButton.icon(
                      onPressed: () =>
                          _editor.apply(SvgAnimationEdit.removePreset(_editor.svg, layer.path)),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(l10n.removePreset),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _editor.apply(
                      SvgAnimationEdit.addPreset(
                        _editor.svg,
                        layer.path,
                        _preset,
                        seconds: _seconds,
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(l10n.applyPreset),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}
