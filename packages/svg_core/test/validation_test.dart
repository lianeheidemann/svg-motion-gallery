import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  group('validateSvg', () {
    test('accepts a well-formed svg', () {
      expect(validateSvg('<svg xmlns="http://www.w3.org/2000/svg"/>').isValid, isTrue);
    });

    test('rejects empty text', () {
      expect(validateSvg('  \n').issue?.code, SvgIssueCode.empty);
    });

    test('rejects a different root element', () {
      expect(validateSvg('<html/>').issue?.code, SvgIssueCode.rootNotSvg);
    });

    test('reports malformed xml with its location', () {
      final issue = validateSvg('<svg>\n  <rect>\n</svg>').issue!;
      expect(issue.code, SvgIssueCode.malformedXml);
      expect(issue.line, 3);
      expect(issue.detail, contains('rect'));
    });
  });

  group('formatSvg', () {
    test('indents nested elements', () {
      expect(formatSvg('<svg><g><rect/></g></svg>'), '<svg>\n  <g>\n    <rect/>\n  </g>\n</svg>');
    });

    test('keeps text content verbatim', () {
      final formatted = formatSvg('<svg><text>  a  b </text></svg>')!;
      expect(formatted, contains('<text>  a  b </text>'));
    });

    test('returns null for invalid xml', () {
      expect(formatSvg('<svg>'), isNull);
    });
  });

  group('parseClockValue', () {
    test('parses the SMIL formats', () {
      expect(parseClockValue('2s'), 2);
      expect(parseClockValue('.75s'), .75);
      expect(parseClockValue('500ms'), .5);
      expect(parseClockValue('1.5'), 1.5);
      expect(parseClockValue('1min'), 60);
      expect(parseClockValue('0:02'), 2);
      expect(parseClockValue('01:00:01.5'), 3601.5);
    });

    test('ignores non-durations', () {
      expect(parseClockValue('indefinite'), isNull);
      expect(parseClockValue('a.end'), isNull);
      expect(parseClockValue(null), isNull);
    });
  });
}
