import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const light = SvgColorScheme.light;
const dark = SvgColorScheme.dark;

/// Like the bundled butterfly: dark by default, light overrides two classes.
const _butterfly =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<style>.bg{fill:#040D19}.spark{fill:#37D9FF}'
    '@media (prefers-color-scheme: light){.bg{fill:#EEF3FF}.spark{fill:#7B4DFF}}</style>'
    '<rect class="bg" width="10" height="10"/>'
    '<g id="wing"><path d="M0 0L5 5" fill="#FF0000"/></g>'
    '<g class="spark"><circle r="1"/><circle r="2" fill="#00FF00"/></g></svg>';

/// Like the bundled sun-moon: a group for each version.
const _sunMoon =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<style>.sun{display:none}.night{display:inline}'
    '@media (prefers-color-scheme: light){.sun{display:inline}.night{display:none}}</style>'
    '<g class="night"><g><circle r="1"/></g></g>'
    '<g class="sun"><circle r="2"/></g></svg>';

void main() {
  group('SvgThemeMarks', () {
    test('a layer with a rule of its own for light is marked own in light only', () {
      final marks = SvgThemeMarks.list(_butterfly);
      final rect = marks[const ElementPath([1])]!;
      expect(rect.originIn(light), SvgThemeOrigin.own);
      expect(rect.ownIn(light), {'fill'});
      expect(rect.originIn(dark), isNull, reason: 'dark shows the shared value');
    });

    test('layers without anything for either theme carry no mark', () {
      final marks = SvgThemeMarks.list(_butterfly);
      expect(marks[const ElementPath([2])]!.isEmpty, isTrue);
      expect(marks[const ElementPath([2, 0])]!.isEmpty, isTrue);
    });

    test('a shape follows its group, unless it has its own color', () {
      final marks = SvgThemeMarks.list(_butterfly);
      final group = marks[const ElementPath([3])]!;
      expect(group.originIn(light), SvgThemeOrigin.own);
      final follows = marks[const ElementPath([3, 0])]!;
      expect(follows.originIn(light), SvgThemeOrigin.inherited);
      expect(follows.sourceIn(light), const ElementPath([3]));
      expect(follows.inheritedIn(light), {
        'fill': const ElementPath([3]),
      });
      final ownColor = marks[const ElementPath([3, 1])]!;
      expect(ownColor.isEmpty, isTrue, reason: 'its own fill hides the group one');
    });

    test('visibility: groups shown in one version, and what is inside them', () {
      final marks = SvgThemeMarks.list(_sunMoon);
      final night = marks[const ElementPath([1])]!;
      expect(night.ownIn(light), {'display'});
      expect(night.originIn(dark), isNull);
      expect(night.shownIn, {dark});
      final star = marks[const ElementPath([1, 0, 0])]!;
      expect(star.originIn(light), SvgThemeOrigin.inherited);
      expect(star.sourceIn(light), const ElementPath([1]));
      expect(star.shownIn, {dark});
      final sun = marks[const ElementPath([2])]!;
      expect(sun.shownIn, {light});
      expect(marks[const ElementPath([2, 0])]!.shownIn, {light});
    });

    test('a color set by the editor for one theme marks only that theme', () {
      const circle = ElementPath([3, 0]);
      final out = SvgThemeEdit.setFill(_butterfly, circle, '#123456', light);
      final mark = SvgThemeMarks.list(out)[circle]!;
      expect(mark.originIn(light), SvgThemeOrigin.own);
      // The dark entry the edit keeps is the value dark already showed.
      expect(mark.originIn(dark), isNull);
      final both = SvgThemeEdit.setFill(out, circle, '#654321', dark);
      final again = SvgThemeMarks.list(both)[circle]!;
      expect(again.originIn(light), SvgThemeOrigin.own);
      expect(again.originIn(dark), SvgThemeOrigin.own);
    });

    test('light-dark() in an attribute gives a mark in both themes', () {
      const doc =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: dark){.x{fill:red}}</style>'
          '<rect width="1" height="1" fill="light-dark(#FFFFFF, #000000)"/></svg>';
      final mark = SvgThemeMarks.list(doc)[const ElementPath([1])]!;
      expect(mark.originIn(light), SvgThemeOrigin.own);
      expect(mark.originIn(dark), SvgThemeOrigin.own);
    });

    test('files without light and dark versions have no marks', () {
      expect(SvgThemeMarks.list('<svg><rect fill="red"/></svg>'), isEmpty);
      expect(SvgThemeMarks.list('not svg'), isEmpty);
    });

    test('the shared value is what shows with no theme, through groups', () {
      expect(SvgThemeMarks.sharedValue(_butterfly, const ElementPath([1]), 'fill'), '#040D19');
      expect(SvgThemeMarks.sharedValue(_butterfly, const ElementPath([3, 0]), 'fill'), '#37D9FF');
      expect(SvgThemeMarks.sharedValue(_sunMoon, const ElementPath([2]), 'display'), 'none');
    });
  });
}
