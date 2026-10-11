import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../color_adjust.dart';

/// Photo-editor style adjustments of the painted color: pick what to change
/// (hue, saturation, brightness...) and slide the ruler. Each adjustment keeps
/// the value where it was let go (the parent works every result out from the
/// color before the first adjustment); tapping its icon twice puts it back to 0.
class ColorAdjuster extends StatefulWidget {
  const ColorAdjuster({
    super.key,
    required this.amounts,
    required this.onPreview,
    required this.onCommit,
    this.onReset,
    this.onResetKind,
  });

  /// The value each adjustment has now (missing means 0).
  final Map<ColorAdjustment, double> amounts;

  /// Called while the ruler moves, with the adjustment and its amount.
  final void Function(ColorAdjustment kind, double amount) onPreview;

  /// Called when the finger lifts.
  final void Function(ColorAdjustment kind, double amount) onCommit;

  /// Puts back what these adjustments changed; null (greyed out) when there
  /// is nothing to put back.
  final VoidCallback? onReset;

  /// Called when an adjustment's icon is tapped twice: puts back only what that
  /// adjustment changed.
  final ValueChanged<ColorAdjustment>? onResetKind;

  @override
  State<ColorAdjuster> createState() => _ColorAdjusterState();
}

class _ColorAdjusterState extends State<ColorAdjuster> {
  var _kind = ColorAdjustment.hue;
  var _amount = 0.0;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    _amount = widget.amounts[_kind] ?? 0;
  }

  @override
  void didUpdateWidget(ColorAdjuster old) {
    super.didUpdateWidget(old);
    // Undo, reset or a new selection changed the values: the ruler follows.
    if (!_dragging) _amount = widget.amounts[_kind] ?? 0;
  }

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
            _amount = widget.amounts[kind] ?? 0;
          }),
          onDoubleTapped: widget.onResetKind,
        ),
        const SizedBox(height: 2),
        RulerSlider(
          value: _amount,
          min: -_kind.limit,
          max: _kind.limit,
          unit: _kind == ColorAdjustment.hue ? '°' : '',
          semanticLabel: l10n.colorAdjustment(_kind),
          onChanged: (v) {
            _dragging = true;
            setState(() => _amount = v);
            widget.onPreview(_kind, v);
          },
          onChangeEnd: (v) {
            _dragging = false;
            setState(() => _amount = v);
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
        width: 68,
        child: Column(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton.filled(
                key: const Key('adjust-reset'),
                tooltip: label,
                onPressed: onPressed,
                style: IconButton.styleFrom(
                  fixedSize: const Size(30, 30),
                  minimumSize: Size.zero,
                  iconSize: 17,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: on ? scheme.tertiary : scheme.surfaceContainerHighest,
                  foregroundColor: on ? scheme.onTertiary : scheme.outline,
                ),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
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
