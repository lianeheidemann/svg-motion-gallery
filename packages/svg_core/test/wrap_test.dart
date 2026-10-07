import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  const svg =
      '<svg width="36" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">\n'
      '  <rect class="a b" x="1" y="1" width="7.33" height="7.33" fill="#ffffff" rx="2"/>\n'
      '  <style>.a{animation:x 2s linear infinite,y 2s linear infinite;animation-delay:.2s}</style>\n'
      '</svg>';

  test('broken lines continue two spaces deeper than their line', () {
    final wrapped = wrapSvgLines(svg, 40).split('\n');
    expect(
      wrapped.where((l) => l.contains('rect') || l.contains('height')).every((l) => l.length <= 40),
      isTrue,
    );
    final rectAt = wrapped.indexWhere((l) => l.startsWith('  <rect'));
    expect(wrapped[rectAt + 1], startsWith('    '));
    expect(wrapped[rectAt + 1], isNot(startsWith('     ')));
  });

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
}
