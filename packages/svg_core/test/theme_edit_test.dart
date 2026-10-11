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

    test('a group hidden in the other version is replaced by its twin', () {
      const doc =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>.sun{display:none}.night{display:inline}'
          '@media (prefers-color-scheme: light){.sun{display:inline}.night{display:none}}</style>'
          '<rect width="10" height="10"/>'
          '<g class="night"><circle r="1"/></g><g class="sun"><circle r="2"/></g></svg>';
      const night = ElementPath([2]);
      const sun = ElementPath([3]);
      const dark = SvgColorScheme.dark;
      const light = SvgColorScheme.light;
      expect(SvgThemeEdit.isShown(doc, night, dark), isTrue);
      expect(SvgThemeEdit.isShown(doc, night, light), isFalse);
      expect(SvgThemeEdit.counterpart(doc, night, dark, light), sun);
      expect(SvgThemeEdit.counterpart(doc, sun, light, dark), night);
      // Drawn in both versions: it stays.
      expect(
        SvgThemeEdit.counterpart(doc, const ElementPath([1]), dark, light),
        const ElementPath([1]),
      );
    });

    test('stroke can be edited per version too, leaving the fill alone', () {
      const doc =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: light){.x{fill:#EEE}}</style>'
          '<path d="M0 0L5 5" fill="none" stroke="#FF00FF"/></svg>';
      const path = ElementPath([1]);
      final out = SvgThemeEdit.setPaint(doc, path, '#00FF00', SvgColorScheme.dark, 'stroke');
      expect(SvgThemeEdit.paintFor(out, path, SvgColorScheme.dark, 'stroke'), '#00FF00');
      expect(SvgThemeEdit.paintFor(out, path, SvgColorScheme.light, 'stroke'), '#FF00FF');
      expect(SvgThemeEdit.fillFor(out, path, SvgColorScheme.dark), 'none');
    });
    test('a layer can be hidden in one version only, and shown again', () {
      const circle = ElementPath([2]);
      final hidden = SvgThemeEdit.setShown(_svg, circle, false, SvgColorScheme.light);
      expect(SvgThemeEdit.isShown(hidden, circle, SvgColorScheme.light), isFalse);
      expect(SvgThemeEdit.isShown(hidden, circle, SvgColorScheme.dark), isTrue);
      expect(SvgThemeMarks.list(hidden)[circle]!.ownIn(SvgColorScheme.light), {'display'});
      final shown = SvgThemeEdit.setShown(hidden, circle, true, SvgColorScheme.light);
      expect(SvgThemeEdit.isShown(shown, circle, SvgColorScheme.light), isTrue);
      expect(SvgThemeMarks.list(shown)[circle]!.isEmpty, isTrue, reason: 'nothing left over');
    });

    test('a group hidden in one version hides what is inside, in that one only', () {
      const doc =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: light){.x{fill:#EEE}}</style>'
          '<g><circle r="1"/></g></svg>';
      final out = SvgThemeEdit.setShown(doc, const ElementPath([1]), false, SvgColorScheme.dark);
      const inside = ElementPath([1, 0]);
      expect(SvgThemeEdit.isShown(out, inside, SvgColorScheme.dark), isFalse);
      expect(SvgThemeEdit.isOwnShown(out, inside, SvgColorScheme.dark), isTrue);
      expect(SvgThemeEdit.isShown(out, inside, SvgColorScheme.light), isTrue);
      final mark = SvgThemeMarks.list(out)[inside]!;
      expect(mark.originIn(SvgColorScheme.dark), SvgThemeOrigin.inherited);
    });

    test('clearing a color the editor set brings the shared one back', () {
      const circle = ElementPath([2]);
      final painted = SvgThemeEdit.setFill(_svg, circle, '#00FF00', SvgColorScheme.dark);
      final cleared = SvgThemeEdit.clearOwn(painted, circle, SvgColorScheme.dark, 'fill');
      expect(SvgThemeEdit.fillFor(cleared, circle, SvgColorScheme.dark), '#FF0000');
      expect(SvgThemeMarks.list(cleared)[circle]!.isEmpty, isTrue);
    });

    test("clearing a color that comes from the file's own rule sets the shared one over it", () {
      const rect = ElementPath([1]);
      final cleared = SvgThemeEdit.clearOwn(_svg, rect, SvgColorScheme.light, 'fill');
      expect(SvgThemeEdit.fillFor(cleared, rect, SvgColorScheme.light), '#000011');
      expect(SvgThemeEdit.fillFor(cleared, rect, SvgColorScheme.dark), '#000011');
      expect(SvgThemeMarks.list(cleared)[rect]!.isEmpty, isTrue);
      expect(cleared, contains('#EEEEFF'), reason: "the file's rule is left in place");
    });

    test('colors and visibility live side by side in the editor block', () {
      const circle = ElementPath([2]);
      var out = SvgThemeEdit.setFill(_svg, circle, '#00FF00', SvgColorScheme.dark);
      out = SvgThemeEdit.setShown(out, circle, false, SvgColorScheme.light);
      out = SvgThemeEdit.setPaint(out, circle, '#0000FF', SvgColorScheme.dark, 'stroke');
      expect(SvgThemeEdit.fillFor(out, circle, SvgColorScheme.dark), '#00FF00');
      expect(SvgThemeEdit.paintFor(out, circle, SvgColorScheme.dark, 'stroke'), '#0000FF');
      expect(SvgThemeEdit.isShown(out, circle, SvgColorScheme.light), isFalse);
      expect(SvgThemeEdit.isShown(out, circle, SvgColorScheme.dark), isTrue);
      expect(RegExp('data-sm-theme').allMatches(out), hasLength(1), reason: 'one block');
    });
  });
}
