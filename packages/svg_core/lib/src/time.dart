/// Parses an SMIL clock value (`2s`, `.75s`, `500ms`, `1.5`, `0:02`,
/// `00:01:30.5`, `1min`, `1h`) into seconds. Returns null for `indefinite`,
/// event-based values and anything else that is not a plain duration.
double? parseClockValue(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  final timed = RegExp(r'^(\d*\.?\d+)\s*(h|min|s|ms)?$').firstMatch(value);
  if (timed != null) {
    final number = double.parse(timed.group(1)!);
    return switch (timed.group(2)) {
      'h' => number * 3600,
      'min' => number * 60,
      'ms' => number / 1000,
      _ => number,
    };
  }
  final clock = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2}(?:\.\d+)?)$').firstMatch(value);
  if (clock != null) {
    final hours = int.parse(clock.group(1) ?? '0');
    final minutes = int.parse(clock.group(2)!);
    final seconds = double.parse(clock.group(3)!);
    return hours * 3600 + minutes * 60 + seconds;
  }
  return null;
}

/// Formats seconds as a compact SMIL clock value, e.g. `1.5s`.
String formatClockValue(double seconds) {
  var text = seconds.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${text}s';
}
