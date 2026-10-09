import 'dart:async';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

import '../../../app_scope.dart';
import '../../../l10n/l10n.dart';
import '../editor_controller.dart';
import 'code/code_controller.dart';
import 'code/keep_indent_formatter.dart';

export 'code/code_controller.dart';
export 'code/keep_indent_formatter.dart';

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

  /// What the live check found in the text: an error (the SVG is broken, red)
  /// or hints (it works but a value looks wrong, amber). Re-checked a moment
  /// after typing stops, which is cheap: one read of the text.
  SvgIssue? _error;
  List<SvgIssue> _hints = const [];
  var _hintIndex = 0;
  Timer? _checkTimer;
  static const _checkDelay = Duration(milliseconds: 500);

  /// True from an edit until the next check: what [_error] says is old.
  var _stale = false;

  /// Shows "Applied" in the button for a moment after text is applied.
  var _justApplied = false;
  Timer? _appliedTimer;

  /// What was last reported to the editor, so Save can explain itself.
  bool _reportedPending = false;
  SvgIssue? _reportedError;

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
    if (!pending) {
      _code.text = _view(widget.editor.code);
      _check();
    }
  }

  bool get _auto => AppScope.of(context).settings.value.autoFormatCode;

  @override
  void initState() {
    super.initState();
    _revision = widget.editor.revision;
    widget.editor.flushCode = _flush;
    _check();
  }

  /// Applies the typed text when it is valid (nothing happens when it is
  /// broken: it is never applied). Used before saving and when leaving.
  void _flush() {
    if (!_hasPending) return;
    final text = _code.text;
    if (validateSvg(text).isValid) widget.editor.updateCode(text);
    _check();
    if (mounted) setState(() {});
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
      _check();
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
    if (editor.flushCode == _flush) editor.flushCode = null;
    if (_hasPending) Future.microtask(() => editor.updateCode(pending));
    _code.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    _query.dispose();
    _checkTimer?.cancel();
    _appliedTimer?.cancel();
    Future.microtask(() => editor.setCodeState(pending: false));
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

  /// Tells the editor whether typed text is waiting and what is wrong with it,
  /// so the Save button can say why it will not save. Done after the frame:
  /// the editor must not notify while this panel is building.
  void _reportToEditor() {
    final pending = _hasPending;
    final error = _stale ? null : _error;
    if (pending == _reportedPending && identical(error, _reportedError)) return;
    _reportedPending = pending;
    _reportedError = error;
    final editor = widget.editor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) editor.setCodeState(pending: pending, error: error);
    });
  }

  /// Checks the text now: parser errors, then values that look wrong.
  void _check() {
    final text = _code.text;
    final validation = validateSvg(text);
    final hints = [?validation.warning, ...lintSvgValues(text)];
    _error = validation.issue;
    _hints = hints;
    _hintIndex = 0;
    _stale = false;
    _underline();
  }

  /// Underlines every problem in the text, errors first when they overlap.
  void _underline() {
    final text = _code.text;
    final found = <CodeProblem>[];
    for (final (issue, error) in [
      if (_error != null) (_error!, true),
      for (final hint in _hints) (hint, false),
    ]) {
      final range = svgIssueRange(text, issue);
      if (range == null || range.$2 <= range.$1) continue;
      found.add(
        CodeProblem(
          TextRange(start: range.$1, end: range.$2.clamp(0, text.length)),
          error: error,
        ),
      );
    }
    found.sort((a, b) => a.range.start.compareTo(b.range.start));
    final clean = <CodeProblem>[];
    for (final problem in found) {
      if (clean.isEmpty || problem.range.start >= clean.last.range.end) clean.add(problem);
    }
    _code.problems = clean;
  }

  /// Called on every edit: the old underlines no longer sit where the
  /// problems are, so they go at once; the check runs when typing pauses.
  void _typed() {
    _code.problems = const [];
    _stale = true;
    _justApplied = false;
    _checkTimer?.cancel();
    _checkTimer = Timer(_checkDelay, () {
      if (mounted) setState(_check);
    });
  }

  /// "Applied" in the button for a moment.
  void _flashApplied() {
    _appliedTimer?.cancel();
    setState(() => _justApplied = true);
    _appliedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justApplied = false);
    });
  }

  /// The issue the bar under the code talks about: the error, else a hint.
  SvgIssue? get _shown => _error ?? (_hints.isEmpty ? null : _hints[_hintIndex % _hints.length]);

  /// Jumps to the problem in the bar; for hints, each tap goes to the next.
  void _goToProblem() {
    final issue = _shown;
    if (issue == null) return;
    final range = svgIssueRange(_code.text, issue);
    if (range != null) _scrollToOffset(range.$1);
    if (_error == null && _hints.length > 1) {
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    }
  }

  /// Rewrites the color in the bar from `#AARRGGBB` to the SVG `#RRGGBBAA`.
  void _convertColor() {
    final issue = _shown;
    final range = issue == null ? null : svgIssueRange(_code.text, issue);
    if (range == null) return;
    final text = _code.text;
    final converted = svgArgbToRgba(text.substring(range.$1, range.$2));
    if (converted == null) return;
    _code.text = text.replaceRange(range.$1, range.$2, converted);
    _typed();
    setState(_check);
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

  /// Brings the current match into view.
  void _scrollToMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final found = _findMatches();
      if (found.isEmpty) return;
      _scrollToOffset(found[_matchIndex.clamp(0, found.length - 1)].start);
    });
  }

  /// Scrolls the code so the character at [offset] sits a third of the way
  /// down the box (and a third across, when lines are not wrapped).
  void _scrollToOffset(int offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_vertical.hasClients) return;
      final before = _code.text.substring(0, offset.clamp(0, _code.text.length));
      final line = '\n'.allMatches(before).length;
      final column = before.length - (before.lastIndexOf('\n') + 1);
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
    _checkTimer?.cancel();
    setState(_check);
    // Problems are told under the code; a clean apply shows in the button.
    if (widget.editor.validation.isValid) _flashApplied();
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
    _reportToEditor();
    final found = _findMatches();
    if (_matchIndex >= found.length) _matchIndex = 0;
    _code
      ..matches = found
      ..current = found.isEmpty ? -1 : _matchIndex;

    final field = TextField(
      key: const Key('code-field'),
      controller: _code,
      inputFormatters: const [KeepIndentFormatter()],
      onChanged: (_) {
        setState(() {});
        _typed();
      },
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

  /// Apply: waiting (a dot), applied (a check), or, with an error, a button
  /// that takes you to it.
  Widget _applyButton(AppLocalizations l10n) {
    final pending = _hasPending;
    final error = _error != null && !_stale;
    final success = GalleryColors.of(context).success;
    final button = error
        ? FilledButton.icon(
            key: const Key('apply-code'),
            style: _compact.merge(FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444))),
            onPressed: _goToProblem,
            icon: const Icon(Icons.error_outline_rounded, size: 18),
            label: Text(l10n.codeShowError),
          )
        : FilledButton.icon(
            key: const Key('apply-code'),
            style: _compact.merge(
              _justApplied && !pending
                  ? FilledButton.styleFrom(
                      disabledBackgroundColor: success.withValues(alpha: .22),
                      disabledForegroundColor: success,
                    )
                  : null,
            ),
            onPressed: pending ? _apply : null,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(_justApplied && !pending ? l10n.codeApplied : l10n.applyCode),
          );
    if (!pending || error) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            key: const Key('code-pending-dot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFFFA000),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
            ),
          ),
        ),
      ],
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

  /// The message under the code: red for an error, amber for a hint, with a
  /// button that scrolls to the problem. Several hints: "+N" and each tap of
  /// the button goes to the next.
  Widget _problemBar(AppLocalizations l10n) {
    final issue = _shown!;
    final error = _error != null;
    // Both are red: a wrong value is as much a mistake as broken XML, the
    // difference is only that it does not stop Apply.
    const color = Color(0xFFEF4444);
    final more = error ? 0 : _hints.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        key: Key(error ? 'code-error' : 'code-hint'),
        padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.issueMessage(issue),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (more > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  l10n.codeMoreProblems(more),
                  style: const TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            if (issue.code == SvgIssueCode.argbColor)
              TextButton(
                key: const Key('code-convert-argb'),
                style: _compact,
                onPressed: _convertColor,
                child: Text(l10n.codeConvertArgb),
              ),
            IconButton(
              key: const Key('code-problem-go'),
              tooltip: l10n.codeProblemGo,
              visualDensity: VisualDensity.compact,
              onPressed: _goToProblem,
              icon: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ],
        ),
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
              _applyButton(l10n),
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
          if (_shown != null) _problemBar(l10n),
        ],
      ),
    );
  }
}
