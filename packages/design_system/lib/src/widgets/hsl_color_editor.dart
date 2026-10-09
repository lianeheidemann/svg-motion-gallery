import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'color_swatch_picker.dart';
import 'slider_field.dart';

/// Translated labels for [HslColorEditor].
class HslLabels {
  const HslLabels({
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.hex,
    this.ok = 'OK',
  });

  final String hue;
  final String saturation;
  final String lightness;
  final String hex;

  /// Label of the button that applies the typed hex color.
  final String ok;
}

/// Color editor made of hue/saturation/lightness sliders plus a hex field,
/// so every adjustment can be done by dragging a bar.
class HslColorEditor extends StatefulWidget {
  const HslColorEditor({
    super.key,
    required this.color,
    required this.labels,
    this.onChanged,
    this.onChangeEnd,
    this.showSliders = true,
  });

  final Color color;
  final HslLabels labels;
  final ValueChanged<Color>? onChanged;
  final ValueChanged<Color>? onChangeEnd;

  /// False: only the swatch and the hex field (the caller adjusts otherwise).
  final bool showSliders;

  @override
  State<HslColorEditor> createState() => _HslColorEditorState();
}

class _HslColorEditorState extends State<HslColorEditor> {
  late HSLColor _hsl = HSLColor.fromColor(widget.color);
  late final TextEditingController _hex = TextEditingController(text: colorToHex(widget.color));

  @override
  void didUpdateWidget(covariant HslColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() != widget.color.toARGB32() &&
        _hsl.toColor().toARGB32() != widget.color.toARGB32()) {
      _hsl = HSLColor.fromColor(widget.color);
      _hex.text = colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _update(HSLColor hsl, {bool end = false}) {
    setState(() => _hsl = hsl);
    final color = hsl.toColor();
    _hex.text = colorToHex(color);
    widget.onChanged?.call(color);
    if (end) widget.onChangeEnd?.call(color);
  }

  void _commit() => widget.onChangeEnd?.call(_hsl.toColor());

  /// Applies the typed hex color (the OK button and the keyboard's Done).
  void _applyHex(String value) {
    FocusManager.instance.primaryFocus?.unfocus();
    final parsed = colorFromHex(value);
    if (parsed == null) {
      _hex.text = colorToHex(_hsl.toColor());
    } else {
      _update(HSLColor.fromColor(parsed), end: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsl.toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _hex,
                decoration: InputDecoration(labelText: widget.labels.hex),
                onSubmitted: _applyHex,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              key: const Key('hex-ok'),
              onPressed: () => _applyHex(_hex.text),
              child: Text(widget.labels.ok),
            ),
          ],
        ),
        if (widget.showSliders) ...[
          const SizedBox(height: AppSpacing.sm),
          SliderField(
            label: widget.labels.hue,
            value: _hsl.hue,
            min: 0,
            max: 360,
            unit: '°',
            onChanged: (v) => _update(_hsl.withHue(v)),
            onChangeEnd: (_) => _commit(),
          ),
          SliderField(
            label: widget.labels.saturation,
            value: _hsl.saturation * 100,
            min: 0,
            max: 100,
            unit: '%',
            onChanged: (v) => _update(_hsl.withSaturation(v / 100)),
            onChangeEnd: (_) => _commit(),
          ),
          SliderField(
            label: widget.labels.lightness,
            value: _hsl.lightness * 100,
            min: 0,
            max: 100,
            unit: '%',
            onChanged: (v) => _update(_hsl.withLightness(v / 100)),
            onChangeEnd: (_) => _commit(),
          ),
        ],
      ],
    );
  }
}
