import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<style>.bg{fill:#000011}@media (prefers-color-scheme: light){.bg{fill:#EEEEFF}}</style>'
    '<rect class="bg" width="10" height="10"/><circle r="2" fill="#FF0000"/></svg>';

void main() {
  group('SvgThemeEdit', () {
    test('only files with a light/dark media query can be edited by variant', () {
      expect(SvgThemeEdit.canEdit(_svg), isTrue);
      expect(SvgThemeEdit.canEdit('<svg><rect fill="red"/></svg>'), isFalse);
    });

    test('reads the color a variant shows, through the stylesheet', () {
      const rect = ElementPath([1]);
      expect(SvgThemeEdit.fillFor(_svg, rect, SvgColorScheme.dark), '#000011');
      expect(SvgThemeEdit.fillFor(_svg, rect, SvgColorScheme.light), '#EEEEFF');
    });

    test('editing one variant leaves the other as it was', () {
      const rect = ElementPath([1]);
      final out = SvgThemeEdit.setFill(_svg, rect, '#123456', SvgColorScheme.light);
      expect(SvgThemeEdit.fillFor(out, rect, SvgColorScheme.light), '#123456');
      expect(SvgThemeEdit.fillFor(out, rect, SvgColorScheme.dark), '#000011');
      // The result is still an adaptive file, and a second edit keeps working.
      expect(SvgThemeEdit.canEdit(out), isTrue);
      final again = SvgThemeEdit.setFill(out, rect, '#654321', SvgColorScheme.dark);
      expect(SvgThemeEdit.fillFor(again, rect, SvgColorScheme.dark), '#654321');
      expect(SvgThemeEdit.fillFor(again, rect, SvgColorScheme.light), '#123456');
    });

    test('a shape with its own fill keeps that color in the other variant', () {
      const circle = ElementPath([2]);
      final out = SvgThemeEdit.setFill(_svg, circle, '#00FF00', SvgColorScheme.dark);
      expect(SvgThemeEdit.fillFor(out, circle, SvgColorScheme.dark), '#00FF00');
      expect(SvgThemeEdit.fillFor(out, circle, SvgColorScheme.light), '#FF0000');
    });
  });
}
