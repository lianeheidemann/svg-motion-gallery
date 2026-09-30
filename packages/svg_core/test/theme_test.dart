import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const mediaSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
  <style>
    .bg { fill: #040D19 }
    /* { not a block } */
    @media (prefers-color-scheme: light) { .bg { fill: #F4F7FF } }
    @media screen and (prefers-color-scheme: dark) { .star { opacity: 1 } }
    @media (min-width: 10px) { .x { fill: light-dark(red, blue) } }
  </style>
  <rect class="bg" width="10" height="10"/>
</svg>''';

void main() {
  group('SvgThemeSupport.detect', () {
    test('finds prefers-color-scheme media queries', () {
      expect(SvgThemeSupport.detect(mediaSvg).mechanisms, contains(SvgThemeMechanism.mediaQuery));
    });

    test('finds light-dark(), currentColor and theme selectors', () {
      expect(
        SvgThemeSupport.detect('<svg><rect style="fill: light-dark(#fff, #000)"/></svg>')
            .mechanisms,
        {SvgThemeMechanism.lightDarkFunction},
      );
      expect(SvgThemeSupport.detect('<svg><path fill="currentColor"/></svg>').mechanisms, {
        SvgThemeMechanism.currentColor,
      });
      expect(
        SvgThemeSupport.detect('<svg><style>[data-theme="dark"] rect{fill:#fff}</style></svg>')
            .mechanisms,
        {SvgThemeMechanism.themeSelector},
      );
      expect(
        SvgThemeSupport.detect('<svg><style>svg.dark rect{fill:#fff}</style></svg>').mechanisms,
        {SvgThemeMechanism.themeSelector},
      );
    });

    test('plain svgs are not adaptive', () {
      expect(SvgThemeSupport.detect('<svg><rect fill="#000"/></svg>').isAdaptive, isFalse);
      expect(
        SvgThemeSupport.detect('<svg><style>.darker{fill:red}</style></svg>').isAdaptive,
        isFalse,
      );
      expect(SvgThemeSupport.detect('<svg>').isAdaptive, isFalse);
    });
  });

  group('SvgThemeResolver', () {
    test('unwraps the matching media block and drops the other', () {
      final light = SvgThemeResolver.resolve(mediaSvg, SvgColorScheme.light);
      expect(light, contains('.bg { fill: #F4F7FF }'));
      expect(light, isNot(contains('prefers-color-scheme')));
      expect(light, isNot(contains('.star')));

      final dark = SvgThemeResolver.resolve(mediaSvg, SvgColorScheme.dark);
      expect(dark, contains('.star { opacity: 1 }'));
      expect(dark, isNot(contains('#F4F7FF')));
    });

    test('keeps unrelated media queries and resolves light-dark() inside them', () {
      final dark = SvgThemeResolver.resolve(mediaSvg, SvgColorScheme.dark);
      expect(dark, contains('@media (min-width: 10px) { .x { fill: blue } }'));
    });

    test('ignores braces inside comments', () {
      final light = SvgThemeResolver.resolve(mediaSvg, SvgColorScheme.light);
      expect(light, contains('/* { not a block } */'));
    });

    test('handles negated queries', () {
      const svg =
          '<svg><style>@media not all and (prefers-color-scheme: dark){rect{fill:red}}</style>'
          '<rect/></svg>';
      expect(SvgThemeResolver.resolve(svg, SvgColorScheme.light), contains('rect{fill:red}'));
      expect(SvgThemeResolver.resolve(svg, SvgColorScheme.dark), isNot(contains('fill:red')));
    });

    test('picks light-dark() arguments with nested parentheses', () {
      const svg = '<svg><rect style="fill: light-dark(rgb(1, 2, 3), #fff)"/></svg>';
      expect(SvgThemeResolver.resolve(svg, SvgColorScheme.light), contains('fill: rgb(1, 2, 3)'));
      expect(SvgThemeResolver.resolve(svg, SvgColorScheme.dark), contains('fill: #fff'));
    });

    test('sets the root color for currentColor', () {
      const svg = '<svg><path fill="currentColor"/></svg>';
      expect(
        SvgThemeResolver.resolve(svg, SvgColorScheme.dark),
        contains('color="${SvgThemeResolver.defaultCurrentColor[SvgColorScheme.dark]}"'),
      );
      expect(
        SvgThemeResolver.resolve(svg, SvgColorScheme.light, currentColor: '#123456'),
        contains('color="#123456"'),
      );
      const colored = '<svg color="red"><path fill="currentColor"/></svg>';
      expect(SvgThemeResolver.resolve(colored, SvgColorScheme.dark), contains('color="red"'));
    });

    test('marks the root for theme selectors', () {
      const svg = '<svg class="icon light"><style>.dark rect{fill:#fff}</style><rect/></svg>';
      final dark = SvgThemeResolver.resolve(svg, SvgColorScheme.dark);
      expect(dark, contains('data-theme="dark"'));
      expect(dark, contains('class="icon dark"'));
    });

    test('returns non-adaptive and invalid documents unchanged', () {
      const plain = '<svg><rect fill="#000"/></svg>';
      expect(SvgThemeResolver.resolve(plain, SvgColorScheme.light), same(plain));
      expect(SvgThemeResolver.resolve('<svg>', SvgColorScheme.light), '<svg>');
    });
  });
}
