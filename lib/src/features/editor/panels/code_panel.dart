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

  /// Where the search found its text (sorted, not overlapping), and which of
  /// them is the current one (-1 for none). They get a colored background.
  List<TextRange> matches = const [];
  int current = -1;

  static const _matchColor = Color(0x55FFC107);
  static const _currentColor = Color(0xAAFFA000);

  /// [text] from [start] to [end] in [color], with the matches marked.
  List<InlineSpan> _segments(int start, int end, Color color) {
    final spans = <InlineSpan>[];
    var at = start;
    TextSpan plain(int from, int to) => TextSpan(
      text: text.substring(from, to),
      style: TextStyle(color: color),
    );
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match.end <= at) continue;
      if (match.start >= end) break;
      final from = math.max(match.start, at);
      final to = math.min(match.end, end);
      if (from > at) spans.add(plain(at, from));
      spans.add(
        TextSpan(
          text: text.substring(from, to),
          style: TextStyle(
            color: color,
            backgroundColor: i == current ? _currentColor : _matchColor,
          ),
        ),
      );
      at = to;
    }
    if (at < end) spans.add(plain(at, end));
    return spans;
  }

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
          ..._segments(token.start, token.end, colorOf(token.type)),
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
  late int _revision;
  var _wrap = false;
  var _fontSize = 11.0;
  var _checkedAuto = false;

  /// The search bar under the buttons, its text and the match being shown.
  var _searching = false;
  final _query = TextEditingController();
  var _matchIndex = 0;

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
  void initState() {
    super.initState();
    _revision = widget.editor.revision;
  }

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
    _query.dispose();
    super.dispose();
  }

  /// Tight buttons so Format, Wrap and Apply share one row when they fit.
  static const _compact = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  bool get _hasPending => _code.text != _view(widget.editor.code);

  /// Every place the search text appears in the code (any letter case).
  List<TextRange> _findMatches() {
    final needle = _query.text.toLowerCase();
    if (!_searching || needle.isEmpty) return const [];
    final haystack = _code.text.toLowerCase();
    final found = <TextRange>[];
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      found.add(TextRange(start: at, end: at + needle.length));
      from = at + needle.length;
    }
    return found;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      _matchIndex = 0;
    });
    if (_searching) _scrollToMatch();
  }

  void _go(int step) {
    final count = _findMatches().length;
    if (count == 0) return;
    setState(() => _matchIndex = (_matchIndex + step) % count);
    _scrollToMatch();
  }

  /// Brings the current match into view (a third of the way down the box).
  void _scrollToMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final found = _findMatches();
      if (found.isEmpty || !_vertical.hasClients) return;
      final match = found[_matchIndex.clamp(0, found.length - 1)];
      final before = _code.text.substring(0, match.start);
      final line = '\n'.allMatches(before).length;
      final column = match.start - (before.lastIndexOf('\n') + 1);
      final lineHeight = _fontSize * 1.45;
      final top = 10 + line * lineHeight - _vertical.position.viewportDimension / 3;
      _vertical.animateTo(
        top.clamp(0, _vertical.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!_wrap && _horizontal.hasClients) {
        final x = column * _fontSize * 0.6 - _horizontal.position.viewportDimension / 3;
        _horizontal.animateTo(
          x.clamp(0, _horizontal.position.maxScrollExtent),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
    final found = _findMatches();
    if (_matchIndex >= found.length) _matchIndex = 0;
    _code
      ..matches = found
      ..current = found.isEmpty ? -1 : _matchIndex;

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
        return _body(context, l10n, colors, style, lines, field, found);
      },
    );
  }

  /// Search field with the match count and previous / next / close buttons.
  Widget _searchBar(AppLocalizations l10n, List<TextRange> found) {
    final hasQuery = _query.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('code-search-field'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                setState(() => _matchIndex = 0);
                _scrollToMatch();
              },
              onSubmitted: (_) => _go(1),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.searchCode,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          if (hasQuery)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                key: const Key('code-search-count'),
                found.isEmpty ? '0' : '${_matchIndex + 1}/${found.length}',
              ),
            ),
          IconButton(
            key: const Key('code-search-previous'),
            tooltip: l10n.searchPrevious,
            visualDensity: VisualDensity.compact,
            onPressed: found.isEmpty ? null : () => _go(-1 + found.length),
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            key: const Key('code-search-next'),
            tooltip: l10n.searchNext,
            visualDensity: VisualDensity.compact,
            onPressed: found.isEmpty ? null : () => _go(1),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            key: const Key('code-search-close'),
            tooltip: l10n.searchClose,
            visualDensity: VisualDensity.compact,
            onPressed: _toggleSearch,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    GalleryColors colors,
    TextStyle style,
    int lines,
    Widget field,
    List<TextRange> found,
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
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      style: _compact,
                      onPressed: _format,
                      child: Text(l10n.formatCode),
                    ),
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      labelPadding: const EdgeInsets.only(right: 4),
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
                    IconButton(
                      key: const Key('code-search'),
                      tooltip: l10n.searchCode,
                      visualDensity: VisualDensity.compact,
                      isSelected: _searching,
                      onPressed: _toggleSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                key: const Key('apply-code'),
                style: _compact,
                onPressed: _hasPending ? _apply : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.applyCode),
              ),
            ],
          ),
          if (_searching) _searchBar(l10n, found),
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
