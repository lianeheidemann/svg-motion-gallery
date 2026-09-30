import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  test('turns class, id, type and descendant rules into attributes', () {
    final inlined = SvgCssInliner.inline(
      '<svg><style>'
      'rect{stroke:blue} .bg{fill:#111} #hero{fill:#222} g > .leaf{fill:#333} '
      'svg circle{stroke-width:4} a:hover{fill:red} @keyframes x{to{fill:#999}}'
      '</style>'
      '<rect class="bg" fill="#000"/><rect id="hero" class="bg"/>'
      '<g><path class="leaf"/></g><circle/></svg>',
    );
    expect(inlined, isNot(contains('<style')));
    expect(inlined, contains('<rect class="bg" fill="#111" stroke="blue"/>'));
    expect(inlined, contains('<rect id="hero" class="bg" stroke="blue" fill="#222"/>'));
    expect(inlined, contains('<path class="leaf" fill="#333"/>'));
    expect(inlined, contains('<circle stroke-width="4"/>'));
    expect(inlined, isNot(contains('#999')));
    expect(inlined, isNot(contains('red')));
  });

  test('style attributes win over stylesheet rules', () {
    final inlined = SvgCssInliner.inline(
      '<svg><style>.a{fill:#111;opacity:.5 !important}</style><rect class="a" style="fill:#fff"/></svg>',
    );
    expect(inlined, contains('fill="#fff"'));
    expect(inlined, contains('opacity=".5"'));
  });

  test('works on a theme-resolved document', () {
    const svg =
        '<svg><style>.bg{fill:#000}@media (prefers-color-scheme: light){.bg{fill:#fff}}</style>'
        '<rect class="bg"/></svg>';
    final light = SvgCssInliner.inline(SvgThemeResolver.resolve(svg, SvgColorScheme.light));
    expect(light, contains('<rect class="bg" fill="#fff"/>'));
    final dark = SvgCssInliner.inline(SvgThemeResolver.resolve(svg, SvgColorScheme.dark));
    expect(dark, contains('<rect class="bg" fill="#000"/>'));
  });

  test('returns documents without CSS unchanged', () {
    const svg = '<svg><rect fill="red"/></svg>';
    expect(SvgCssInliner.inline(svg), same(svg));
  });
}
