import 'package:flutter/services.dart';

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
