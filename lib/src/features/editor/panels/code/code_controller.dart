import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:svg_core/svg_core.dart';

/// A range of code with something wrong, to underline.
class CodeProblem {
  const CodeProblem(this.range, {required this.error});

  final TextRange range;

  /// Red when true (the SVG is broken), amber when false (only a hint).
  final bool error;
}

/// How far the matches and problems have been read while building one span.
class _Walk {
  var match = 0;
  var problem = 0;
}

/// Text controller that paints SVG source with syntax colors.
class SvgCodeController extends TextEditingController {
  SvgCodeController({super.text});

  GalleryColors? colors;

  /// Where the search found its text (sorted, not overlapping), and which of
  /// them is the current one (-1 for none). They get a colored background.
  List<TextRange> matches = const [];
  int current = -1;

  /// Places with a problem (sorted, not overlapping), underlined with a wavy
  /// line: red for errors, amber for hints.
  List<CodeProblem> problems = const [];

  static const _matchColor = Color(0x55FFC107);
  static const _currentColor = Color(0xAAFFA000);
  static const _errorColor = Color(0xFFEF4444);
  static const _hintColor = _errorColor;

  /// [text] from [start] to [end] in [color], with the matches marked and the
  /// problems underlined. [walk] remembers how far the lists have been read,
  /// since the tokens come in order.
  List<InlineSpan> _segments(int start, int end, Color color, _Walk walk) {
    while (walk.match < matches.length && matches[walk.match].end <= start) {
      walk.match++;
    }
    while (walk.problem < problems.length && problems[walk.problem].range.end <= start) {
      walk.problem++;
    }
    final cuts = <int>{start, end};
    for (var i = walk.match; i < matches.length && matches[i].start < end; i++) {
      cuts
        ..add(math.max(matches[i].start, start))
        ..add(math.min(matches[i].end, end));
    }
    for (var i = walk.problem; i < problems.length && problems[i].range.start < end; i++) {
      cuts
        ..add(math.max(problems[i].range.start, start))
        ..add(math.min(problems[i].range.end, end));
    }
    final points = cuts.toList()..sort();

    final spans = <InlineSpan>[];
    var m = walk.match;
    var p = walk.problem;
    for (var k = 0; k + 1 < points.length; k++) {
      final from = points[k];
      final to = points[k + 1];
      while (m < matches.length && matches[m].end <= from) {
        m++;
      }
      while (p < problems.length && problems[p].range.end <= from) {
        p++;
      }
      final inMatch = m < matches.length && matches[m].start <= from;
      final problem = p < problems.length && problems[p].range.start <= from ? problems[p] : null;
      spans.add(
        TextSpan(
          text: text.substring(from, to),
          style: TextStyle(
            color: color,
            backgroundColor: inMatch ? (m == current ? _currentColor : _matchColor) : null,
            decoration: problem == null ? null : TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: problem == null ? null : (problem.error ? _errorColor : _hintColor),
            decorationThickness: 1.6,
          ),
        ),
      );
    }
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
    final walk = _Walk();
    return TextSpan(
      style: style,
      children: [
        for (final token in tokenizeSvg(text))
          ..._segments(token.start, token.end, colorOf(token.type), walk),
      ],
    );
  }
}
