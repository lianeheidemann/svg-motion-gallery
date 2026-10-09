import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../color_adjust.dart';

/// Photo-editor style adjustments of the painted color: pick what to change
/// (hue, saturation, brightness...) and slide the ruler. Every adjustment
/// starts at 0 from the color as it is, so letting go makes the result the
/// new color and the ruler returns to 0.
class ColorAdjuster extends StatefulWidget {
  const ColorAdjuster({super.key, required this.onPreview, required this.onCommit});

  /// Called while the ruler moves, with the adjustment and its amount.
  final void Function(ColorAdjustment kind, double amount) onPreview;

  /// Called when the finger lifts.
  final void Function(ColorAdjustment kind, double amount) onCommit;

  @override
  State<ColorAdjuster> createState() => _ColorAdjusterState();
}

class _ColorAdjusterState extends State<ColorAdjuster> {
  var _kind = ColorAdjustment.hue;
  var _amount = 0.0;

  static const _icons = {
    ColorAdjustment.hue: Icons.palette_outlined,
    ColorAdjustment.saturation: Icons.water_drop_outlined,
    ColorAdjustment.lightness: Icons.exposure_rounded,
    ColorAdjustment.brightness: Icons.brightness_5_rounded,
    ColorAdjustment.contrast: Icons.contrast_rounded,
    ColorAdjustment.temperature: Icons.thermostat_rounded,
    ColorAdjustment.highlights: Icons.wb_sunny_outlined,
    ColorAdjustment.shadows: Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdjustTabs<ColorAdjustment>(
          tabs: [
            for (final kind in ColorAdjustment.values)
              AdjustTab(id: kind, icon: _icons[kind]!, label: l10n.colorAdjustment(kind)),
          ],
          selected: _kind,
          onSelected: (kind) => setState(() {
            _kind = kind;
            _amount = 0;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        RulerSlider(
          value: _amount,
          min: -_kind.limit,
          max: _kind.limit,
          unit: _kind == ColorAdjustment.hue ? '°' : '',
          semanticLabel: l10n.colorAdjustment(_kind),
          onChanged: (v) {
            setState(() => _amount = v);
            widget.onPreview(_kind, v);
          },
          onChangeEnd: (v) {
            setState(() => _amount = 0);
            widget.onCommit(_kind, v);
          },
        ),
      ],
    );
  }
}
