import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/panels/code_panel.dart';

TextEditingValue _enter(String before, int at) {
  const formatter = KeepIndentFormatter();
  final old = TextEditingValue(
    text: before,
    selection: TextSelection.collapsed(offset: at),
  );
  final text = before.replaceRange(at, at, '\n');
  return formatter.formatEditUpdate(
    old,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + 1),
    ),
  );
}

void main() {
  test('Enter keeps the indent of the line above', () {
    final result = _enter('<svg>\n    <g>', 13);
    expect(result.text, '<svg>\n    <g>\n    ');
    expect(result.selection.baseOffset, result.text.length);
  });

  test('no indent, nothing added; pasted text is left alone', () {
    expect(_enter('<svg>', 5).text, '<svg>\n');
    const formatter = KeepIndentFormatter();
    final pasted = formatter.formatEditUpdate(
      const TextEditingValue(text: '  a', selection: TextSelection.collapsed(offset: 3)),
      const TextEditingValue(text: '  a\nb\n', selection: TextSelection.collapsed(offset: 6)),
    );
    expect(pasted.text, '  a\nb\n');
  });
}
