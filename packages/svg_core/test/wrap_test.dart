import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  const svg =
      '<svg width="36" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">\n'
      '  <rect class="a b" x="1" y="1" width="7.33" height="7.33" fill="#ffffff" rx="2"/>\n'
      '  <style>.a{animation:x 2s linear infinite,y 2s linear infinite;animation-delay:.2s}</style>\n'
      '</svg>';

  test('broken lines keep the indent of the line they come from', () {
    final wrapped = wrapSvgLines(svg, 40).split('\n');
    expect(
      wrapped.where((l) => l.contains('rect') || l.contains('height')).every((l) => l.length <= 40),
      isTrue,
    );
    final rectAt = wrapped.indexWhere((l) => l.startsWith('  <rect'));
    expect(wrapped[rectAt + 1], startsWith('  '));
    expect(wrapped[rectAt + 1], isNot(startsWith('   ')));
  });

  test(
    'a long style value is broken too, with the same indent, and wrapping twice changes nothing',
    () {
      const long =
          '<svg xmlns="http://www.w3.org/2000/svg">\n'
          '  <g>\n'
          '    <rect style="fill:#93C5FD;animation:spinner_5QiW 2.602s linear infinite,spinner_tDji 2.602s linear infinite;animation-delay:0.434s"/>\n'
          '  </g>\n'
          '</svg>';
      final once = wrapSvgLines(long, 50);
      for (final line in once.split('\n')) {
        expect(line.length, lessThanOrEqualTo(50), reason: line);
      }
      final rect = once.split('\n').indexWhere((l) => l.contains('<rect'));
      expect(once.split('\n')[rect + 1], startsWith('    '), reason: 'indent of the rect line');
      expect(validateSvg(once).isValid, isTrue);
      expect(wrapSvgLines(once, 50), once, reason: 'idempotent');
      expect(wrapSvgLines(wrapSvgLines(svg, 40), 40), wrapSvgLines(svg, 40));
    },
  );

  test('wrapping only changes whitespace and the result is still valid', () {
    final wrapped = wrapSvgLines(svg, 40);
    expect(validateSvg(wrapped).isValid, isTrue);
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
    expect(squash(wrapped), squash(svg));
  });

  test('values with spaces are never split', () {
    final wrapped = wrapSvgLines(svg, 40);
    expect(wrapped, contains('class="a b"'));
  });

  test('short lines are untouched', () {
    expect(wrapSvgLines(svg, 400), svg);
  });

  test('the text of title and desc is broken too, with the indent of its line', () {
    const doc =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">\n'
        '  <title id="t">Logo de robo com giro horizontal em tres dimensoes</title>\n'
        '  <desc id="d">Balao de conversa em forma de robo girando horizontalmente</desc>\n'
        '</svg>';
    final once = wrapSvgLines(doc, 40);
    for (final line in once.split('\n')) {
      expect(line.length, lessThanOrEqualTo(40), reason: line);
    }
    final lines = once.split('\n');
    final at = lines.indexWhere((l) => l.contains('<title'));
    expect(lines[at + 1], startsWith('  '));
    expect(lines[at + 1], isNot(startsWith('   ')));
    expect(validateSvg(once).isValid, isTrue);
    expect(wrapSvgLines(once, 40), once, reason: 'idempotent');
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
    expect(squash(once), squash(doc));
  });
}
