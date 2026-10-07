import 'dart:io';

import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

String _svg(String css) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">\n'
    '<style>\n$css\n</style>\n<rect width="10" height="10"/>\n</svg>';

void main() {
  group('CSS warning', () {
    test('typed nonsense inside a style block is a warning, not an error', () {
      final result = validateSvg(
        _svg(
          '@media (prefers-color-scheme: dark) {\n :root {\n --a: #fff;\n'
          'yjmmcdrjnm: \$#":()!;2&5\n --b: #000;\n }\n}',
        ),
      );
      expect(result.isValid, isTrue, reason: 'it is still a usable SVG');
      expect(result.warning?.code, SvgIssueCode.malformedCss);
      expect(result.warning?.line, isNotNull);
    });

    test('flags a declaration without a colon, and unbalanced braces', () {
      expect(validateSvg(_svg('.a { fill red; }')).warning, isNotNull);
      expect(validateSvg(_svg('.a { fill: red; ')).warning, isNotNull);
      expect(validateSvg(_svg('.a { fill: red; } }')).warning, isNotNull);
      expect(validateSvg(_svg('.a { fill: url(#g; }')).warning, isNotNull);
    });

    test('accepts ordinary CSS', () {
      const css = '''
/* comment { not css */
:root { --edge-mid: #58l8ff; --face: #fff }
.a { fill: var(--face); stroke: url(#g); animation: spin 2s linear infinite; }
@keyframes spin { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }
@media (prefers-color-scheme: dark) { :root { --face: #000; } }
.b { background: url("data:image/png;base64,AAAA"); content: ";"; -webkit-filter: blur(2px); }
''';
      expect(validateSvg(_svg(css)).warning, isNull);
    });

    test('the bundled demos have no warning', () {
      for (final file in Directory('../../assets/svgs').listSync().whereType<File>()) {
        final result = validateSvg(file.readAsStringSync());
        expect(result.isValid, isTrue, reason: file.path);
        expect(result.warning, isNull, reason: file.path);
      }
    });

    test('invalid XML is still an error', () {
      expect(validateSvg('<svg><g></svg>').isValid, isFalse);
    });
  });
}
