import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

String _svg(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">$body</svg>';

void main() {
  group('lintSvgValues', () {
    test('flags a color that is not one and says where', () {
      final source = _svg('\n<circle r="4" fill="#FFC----@83D"/>');
      final issues = lintSvgValues(source);
      expect(issues, hasLength(1));
      final issue = issues.single;
      expect(issue.code, SvgIssueCode.invalidValue);
      expect(issue.attribute, 'fill');
      expect(issue.detail, '#FFC----@83D');
      expect(issue.line, 2);
      expect(source.substring(issue.start!, issue.end!), '#FFC----@83D');
    });

    test('flags bad hex lengths, unknown names and bad numbers', () {
      final issues = lintSvgValues(
        _svg('<rect width="abc" height="10" fill="#12"/><circle r="4" stroke="reed"/>'),
      );
      expect(issues.map((i) => i.attribute), ['width', 'fill', 'stroke']);
    });

    test('trusts what browsers accept', () {
      final issues = lintSvgValues(
        _svg(
          '<g fill="none" stroke="currentColor">'
          '<rect x="-10%" y=".5" width="1e3" height="auto" fill="#abc" stroke="#AABBCCDD"/>'
          '<circle r="4px" fill="rgb(1 2 3)" stroke="url(#g)" opacity="50%"/>'
          '<text x="1 2 3" y="1,2,3" fill="var(--c)">hi</text>'
          '<path fill="Crimson" stroke="RebeccaPurple" stroke-width="2.5"/>'
          '</g>',
        ),
      );
      expect(issues, isEmpty);
    });

    test('ignores text and comments, and unfinished values', () {
      expect(lintSvgValues(_svg('<style>.a{fill:#12}</style><!-- fill="#12" -->')), isEmpty);
      expect(lintSvgValues('<svg><circle fill="#12'), isEmpty);
    });

    test('stops at the limit', () {
      final many = List.generate(30, (_) => '<circle r="x"/>').join();
      expect(lintSvgValues(_svg(many), limit: 5), hasLength(5));
    });
  });

  group('svgIssueRange', () {
    test('uses the exact range when the linter gave one', () {
      final source = _svg('<circle fill="#12"/>');
      final issue = lintSvgValues(source).single;
      expect(svgIssueRange(source, issue), (issue.start, issue.end));
    });

    test('turns a parser line and column into the word there', () {
      const source = '<svg>\n  <rect width="1" height=">\n</svg>';
      final validation = validateSvg(source);
      final range = svgIssueRange(source, validation.issue!);
      expect(range, isNotNull);
      expect(range!.$2, greaterThan(range.$1));
    });

    test('has nothing to underline without a line', () {
      expect(svgIssueRange('', const SvgIssue(SvgIssueCode.empty)), isNull);
    });
  });
}
