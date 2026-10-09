import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/gallery_colors.dart';

/// A labeled adjustment with a slider bar and a numeric field kept in sync.
///
/// Dragging calls [onChanged] continuously (for live previews) and
/// [onChangeEnd] once when released (for committing, e.g. to undo history).
/// Typing a number and submitting calls both.
class SliderField extends StatefulWidget {
  const SliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.onChangeStart,
    this.divisions,
    this.fractionDigits = 0,
    this.unit = '',
    this.labelWidth = 92,
    this.labelTrailing,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final int fractionDigits;

  /// Suffix shown after the number, e.g. `%`, `°`, `s`, `px`.
  final String unit;
  final double labelWidth;

  /// A small widget right after the label (e.g. a lock icon).
  final Widget? labelTrailing;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Called once when a drag on the bar begins.
  final ValueChanged<double>? onChangeStart;

  @override
  State<SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<SliderField> {
  late final TextEditingController _text = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();

  bool get _enabled => widget.onChanged != null || widget.onChangeEnd != null;

  String _format(double value) => value.toStringAsFixed(widget.fractionDigits);

  double _clamp(double value) => value.clamp(widget.min, widget.max).toDouble();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit(_text.text);
    });
  }

  @override
  void didUpdateWidget(covariant SliderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _format(widget.value) != _text.text) {
      _text.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.').replaceAll(widget.unit, '').trim());
    if (parsed == null) {
      _text.text = _format(widget.value);
      return;
    }
    final value = _clamp(parsed);
    _text.text = _format(value);
    if (value == widget.value) return;
    widget.onChanged?.call(value);
    widget.onChangeEnd?.call(value);
  }

  /// Width the slider itself needs to stay usable next to the label and field.
  static const _fieldWidth = 76.0;
  static const _minSliderWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _clamp(widget.value);
    final text = Text(
      widget.label,
      style: theme.textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final label = widget.labelTrailing == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: text),
              widget.labelTrailing!,
            ],
          );
    final field = SizedBox(
      width: _fieldWidth,
      child: TextField(
        controller: _text,
        focusNode: _focus,
        enabled: _enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(
          signed: widget.min < 0,
          decimal: widget.fractionDigits > 0,
        ),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
        decoration: InputDecoration(
          suffixText: widget.unit,
          suffixStyle: TextStyle(color: GalleryColors.of(context).muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onSubmitted: _submit,
      ),
    );
    final slider = Expanded(
      child: Slider(
        value: value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: '${_format(value)}${widget.unit}',
        semanticFormatterCallback: (v) => '${widget.label} ${_format(v)}${widget.unit}',
        onChanged: _enabled
            ? (v) {
                _text.text = _format(v);
                widget.onChanged?.call(v);
              }
            : null,
        onChangeStart: widget.onChangeStart,
        onChangeEnd: widget.onChangeEnd,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow widths (small phones, a large interface size) the label
        // moves above the row so the slider keeps its length.
        final stacked = constraints.maxWidth - widget.labelWidth - _fieldWidth < _minSliderWidth;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              Row(children: [field, slider]),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: widget.labelWidth, child: label),
            field,
            slider,
          ],
        );
      },
    );
  }
}
