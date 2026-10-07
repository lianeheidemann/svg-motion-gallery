import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:svg_core/svg_core.dart';

import '../../../app_scope.dart';
import '../../../l10n/l10n.dart';
import '../editor_controller.dart';

/// Text controller that paints SVG source with syntax colors.
class SvgCodeController extends TextEditingController {
  SvgCodeController({super.text});

  GalleryColors? colors;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final palette = colors;
    if (palette == null || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    Color colorOf(SvgTokenType type) => switch (type) {
      SvgTokenType.text => palette.codeText,
      SvgTokenType.comment => palette.codeComment,
      SvgTokenType.tag => palette.codeTag,
      SvgTokenType.punctuation => palette.codePunctuation,
      SvgTokenType.attribute => palette.codeAttribute,
      SvgTokenType.value => palette.codeValue,
      SvgTokenType.entity => palette.codeValue,
    };
    return TextSpan(
      style: style,
      children: [
        for (final token in tokenizeSvg(text))
          TextSpan(
            text: text.substring(token.start, token.end),
            style: TextStyle(color: colorOf(token.type)),
          ),
      ],
    );
  }
}

/// Pressing Enter starts the new line with the indent of the line above.
class KeepIndentFormatter extends TextInputFormatter {
  const KeepIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cursor = newValue.selection.baseOffset;
    final typedOne =
        newValue.selection.isCollapsed &&
        newValue.text.length == oldValue.text.length + 1 &&
        cursor > 0 &&
        newValue.text[cursor - 1] == '\n' &&
        newValue.text.replaceRange(cursor - 1, cursor, '') == oldValue.text;
    if (!typedOne) return newValue;
    final lineStart = newValue.text.lastIndexOf('\n', cursor - 2) + 1;
    final line = newValue.text.substring(lineStart, cursor - 1);
    final indent = line.substring(0, line.length - line.trimLeft().length);
    if (indent.isEmpty) return newValue;
    return TextEditingValue(
      text: newValue.text.replaceRange(cursor, cursor, indent),
      selection: TextSelection.collapsed(offset: cursor + indent.length),
    );
  }
}

/// Source editor with highlighting, line numbers, optional wrapping, a font
/// size slider and formatting. Typing is only validated and applied to the
/// preview when the user taps Apply (or Format).
class CodePanel extends StatefulWidget {
  const CodePanel({super.key, required this.editor});

  final EditorController editor;

  @override
  State<CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<CodePanel> {
  late final _code = SvgCodeController(text: widget.editor.code);
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late int _revision = widget.editor.revision;
  var _wrap = false;
  var _fontSize = 11.0;
  var _checkedAuto = false;

  /// Width of the text area, in characters, used to break long lines.
  var _columns = 0;

  /// [code] as the field shows it: with wrapping on, long lines are really
  /// broken (continuing with a deeper indent), so the indent survives.
  String _view(String code) => _wrap && _columns > 0 ? wrapSvgLines(code, _columns) : code;

  /// Changes [change] and re-lays out the text, unless the user has typed
  /// something that was not applied yet.
  void _relayout(VoidCallback change) {
    final pending = _hasPending;
    setState(change);
    if (!pending) _code.text = _view(widget.editor.code);
  }

  bool get _auto => AppScope.of(context).settings.value.autoFormatCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedAuto) {
      _checkedAuto = true;
      _autoFormat();
    }
  }

  @override
  void didUpdateWidget(covariant CodePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editor.revision != _revision) {
      _revision = widget.editor.revision;
      _code.text = _view(widget.editor.code);
      _autoFormat();
    }
  }

  /// With automatic formatting on, brings the document to one tag per line.
  /// Never touches text the user is still typing, and is a no-op once the
  /// document is already formatted. Deferred: the editor notifies listeners.
  void _autoFormat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_auto || _hasPending) return;
      final formatted = formatSvg(widget.editor.code);
      if (formatted != null && formatted != widget.editor.code) widget.editor.formatCode();
    });
  }

  void _toggleAuto(bool value) {
    AppScope.of(context).settings.setAutoFormatCode(value);
    if (value) _autoFormat();
  }

  @override
  void dispose() {
    // Keep typing that has not reached the editor yet (e.g. when switching
    // tabs). Deferred because listeners must not rebuild during disposal.
    final pending = _code.text;
    final editor = widget.editor;
    if (_hasPending) Future.microtask(() => editor.updateCode(pending));
    _code.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  bool get _hasPending => _code.text != _view(widget.editor.code);

  void _apply() {
    if (_auto) {
      // The typed text is formatted as it is applied.
      final formatted = formatSvg(_code.text);
      if (formatted != null) _code.text = _view(formatted);
    }
    widget.editor.updateCode(_code.text);
    final validation = widget.editor.validation;
    // Errors and warnings have their own banner; confirm only a clean apply.
    if (validation.isValid && validation.warning == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.codeApplied)));
    }
  }

  void _format() {
    _apply();
    if (widget.editor.validation.isValid) widget.editor.formatCode();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = GalleryColors.of(context);
    _code.colors = colors;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['RobotoMono', 'Menlo', 'Courier New', 'Courier'],
      fontSize: _fontSize,
      height: 1.45,
      color: colors.codeText,
    );
    final lines = '\n'.allMatches(_code.text).length + 1;

    final field = TextField(
      key: const Key('code-field'),
      controller: _code,
      inputFormatters: const [KeepIndentFormatter()],
      onChanged: (_) => setState(() {}),
      maxLines: null,
      style: style,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration.collapsed(hintText: null),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Side padding 16 + 16, text padding 10 + 10, border 2; monospace
        // glyphs are about 0.6 em wide.
        _columns = math.max(((constraints.maxWidth - 54) / (_fontSize * 0.62)).floor(), 0);
        return _body(context, l10n, colors, style, lines, field);
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    GalleryColors colors,
    TextStyle style,
    int lines,
    Widget field,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _format,
                      icon: const Icon(Icons.format_align_left_rounded, size: 18),
                      label: Text(l10n.formatCode),
                    ),
                    FilterChip(
                      key: const Key('auto-format'),
                      avatar: Icon(
                        Icons.auto_fix_high_rounded,
                        size: 18,
                        color: _auto ? Colors.white : null,
                      ),
                      label: Text(
                        l10n.autoFormat,
                        style: TextStyle(color: _auto ? Colors.white : null),
                      ),
                      selected: _auto,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      onSelected: _toggleAuto,
                    ),
                    FilterChip(
                      avatar: Icon(
                        Icons.wrap_text_rounded,
                        size: 18,
                        color: _wrap ? Colors.white : null,
                      ),
                      label: Text(
                        l10n.wrapLines,
                        style: TextStyle(color: _wrap ? Colors.white : null),
                      ),
                      selected: _wrap,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      onSelected: (value) => _relayout(() => _wrap = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('apply-code'),
                onPressed: _hasPending ? _apply : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.applyCode),
              ),
            ],
          ),
          SliderField(
            label: l10n.fontSize,
            value: _fontSize,
            min: 7,
            max: 24,
            unit: 'pt',
            onChanged: (v) => _relayout(() => _fontSize = v.roundToDouble()),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.codeBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: SingleChildScrollView(
                  controller: _vertical,
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_wrap)
                        Container(
                          padding: const EdgeInsets.only(left: 8, right: 10),
                          child: Text(
                            List.generate(lines, (i) => '${i + 1}').join('\n'),
                            textAlign: TextAlign.right,
                            style: style.copyWith(color: colors.codeGutter),
                          ),
                        ),
                      Expanded(
                        child: _wrap
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: field,
                              )
                            // The app scroll behavior adds the draggable scrollbar.
                            : LayoutBuilder(
                                builder: (context, constraints) => SingleChildScrollView(
                                  controller: _horizontal,
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth - 16,
                                    ),
                                    child: IntrinsicWidth(child: field),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
