import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/code_panel.dart';

const _source = '<svg>\n<circle fill="#12"/>\n</svg>';

/// All the styled spans of [controller] in a real build context.
Future<List<TextSpan>> _spans(WidgetTester tester, SvgCodeController controller) async {
  late TextSpan root;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.dark),
      home: Builder(
        builder: (context) {
          controller.colors = GalleryColors.of(context);
          root = controller.buildTextSpan(context: context, withComposing: false);
          return const SizedBox();
        },
      ),
    ),
  );
  return [for (final child in root.children!) child as TextSpan];
}

void main() {
  testWidgets('problems are underlined with a wavy line, red or amber', (tester) async {
    final controller = SvgCodeController(text: _source);
    addTearDown(controller.dispose);
    final bad = _source.indexOf('#12');
    controller.problems = [
      CodeProblem(TextRange(start: bad, end: bad + 3), error: false),
      const CodeProblem(TextRange(start: 1, end: 4), error: true),
    ]..sort((a, b) => a.range.start.compareTo(b.range.start));

    final spans = await _spans(tester, controller);
    expect(spans.map((s) => s.text).join(), _source, reason: 'the text is unchanged');

    final underlined = spans.where((s) => s.style?.decoration == TextDecoration.underline);
    expect(underlined.map((s) => s.text), ['svg', '#12']);
    expect(underlined.first.style!.decorationStyle, TextDecorationStyle.wavy);
    expect(underlined.first.style!.decorationColor, isNot(underlined.last.style!.decorationColor));
  });

  testWidgets('search matches and problems can share the same text', (tester) async {
    final controller = SvgCodeController(text: _source);
    addTearDown(controller.dispose);
    final bad = _source.indexOf('#12');
    controller
      ..matches = [TextRange(start: bad - 2, end: bad + 3)]
      ..current = 0
      ..problems = [CodeProblem(TextRange(start: bad, end: bad + 3), error: false)];

    final spans = await _spans(tester, controller);
    expect(spans.map((s) => s.text).join(), _source);
    final both = spans.where(
      (s) => s.style?.backgroundColor != null && s.style?.decoration == TextDecoration.underline,
    );
    expect(both.map((s) => s.text), ['#12']);
  });
}
