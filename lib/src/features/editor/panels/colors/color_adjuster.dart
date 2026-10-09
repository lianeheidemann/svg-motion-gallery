import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../color_adjust.dart';

/// Photo-editor style adjustments of the painted color: pick what to change
/// (hue, saturation, brightness...) and slide the ruler. Every adjustment
/// starts at 0 from the color as it is, so letting go makes the result the
/// new color and the ruler returns to 0.
class ColorAdjuster extends StatefulWidget {
  const ColorAdjuster({super.key, required this.onPreview, required this.onCommit, this.onReset});

  /// Called while the ruler moves, with the adjustment and its amount.
  final void Function(ColorAdjustment kind, double amount) onPreview;

  /// Called when the finger lifts.
  final void Function(ColorAdjustment kind, double amount) onCommit;

  /// Puts back what these adjustments changed; null (greyed out) when there
  /// is nothing to put back.
  final VoidCallback? onReset;

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
          trailing: _ResetButton(label: l10n.adjustReset, onPressed: widget.onReset),
          onSelected: (kind) => setState(() {
            _kind = kind;
            _amount = 0;
          }),
        ),
        const SizedBox(height: 2),
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

/// The highlighted round button at the end of the row: undoes what the
/// adjustments changed.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            IconButton.filled(
              key: const Key('adjust-reset'),
              tooltip: label,
              onPressed: onPressed,
              style: IconButton.styleFrom(
                fixedSize: const Size(38, 38),
                iconSize: 20,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: on ? scheme.tertiary : scheme.surfaceContainerHighest,
                foregroundColor: on ? scheme.onTertiary : scheme.outline,
              ),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: on ? scheme.tertiary : scheme.outline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
