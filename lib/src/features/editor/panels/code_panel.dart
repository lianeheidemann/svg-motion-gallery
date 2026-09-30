import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

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

/// Source editor with highlighting, line numbers, optional wrapping, a font
/// size slider and formatting. Valid edits reach the preview after a short
/// pause in typing.
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
  Timer? _debounce;
  var _wrap = false;
  var _fontSize = 11.0;

  @override
  void didUpdateWidget(covariant CodePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editor.revision != _revision) {
      _revision = widget.editor.revision;
      _debounce?.cancel();
      _code.text = widget.editor.code;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Keep typing that has not reached the editor yet (e.g. when switching
    // tabs). Deferred because listeners must not rebuild during disposal.
    final pending = _code.text;
    final editor = widget.editor;
    if (pending != editor.code) Future.microtask(() => editor.updateCode(pending));
    _code.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => widget.editor.updateCode(text));
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
      onChanged: _onChanged,
      maxLines: null,
      style: style,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration.collapsed(hintText: null),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: widget.editor.validation.isValid ? widget.editor.formatCode : null,
                icon: const Icon(Icons.format_align_left_rounded, size: 18),
                label: Text(l10n.formatCode),
              ),
              FilterChip(
                avatar: Icon(Icons.wrap_text_rounded, size: 18, color: _wrap ? Colors.white : null),
                label: Text(l10n.wrapLines, style: TextStyle(color: _wrap ? Colors.white : null)),
                selected: _wrap,
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                onSelected: (value) => setState(() => _wrap = value),
              ),
            ],
          ),
          SliderField(
            label: l10n.fontSize,
            value: _fontSize,
            min: 9,
            max: 24,
            unit: 'pt',
            onChanged: (v) => setState(() => _fontSize = v.roundToDouble()),
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
