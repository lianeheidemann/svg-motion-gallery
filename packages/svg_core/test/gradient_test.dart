import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const _butterfly =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<defs>'
    '<linearGradient id="wing" x1="0" y1="0" x2="1" y2="1">'
    '<stop stop-color="#3B82F6"/><stop offset=".5" stop-color="#8B5CF6" stop-opacity=".5"/>'
    '<stop offset="1" stop-color="#EC4899"/></linearGradient>'
    '<linearGradient id="alias" href="#wing" x2="0" y2="1"/>'
    '</defs>'
    '<path d="M0 0" fill="url(#wing)"/>'
    '<path d="M1 1" fill="url(#wing)"/>'
    '<g stroke="url(#wing)"><path d="M2 2" fill="none"/></g>'
    '<rect width="5" height="5" fill="#FF0000"/>'
    '</svg>';

const _first = ElementPath([1]);
const _second = ElementPath([2]);
const _inGroup = ElementPath([3, 0]);
const _rect = ElementPath([4]);

void main() {
  group('reading', () {
    test('parses stops, defaults and opacity', () {
      final gradient = SvgGradientEdit.read(_butterfly, 'wing')!;
      expect(gradient.kind, SvgGradientKind.linear);
      expect(gradient.stops, const [
        GradientStop(offset: 0, color: '#3B82F6'),
        GradientStop(offset: .5, color: '#8B5CF6', opacity: .5),
        GradientStop(offset: 1, color: '#EC4899'),
      ]);
      expect(gradient.angle, closeTo(45, 1e-9));
    });

    test('follows href for stops and keeps its own geometry', () {
      final alias = SvgGradientEdit.read(_butterfly, 'alias')!;
      expect(alias.stops, hasLength(3));
      expect(alias.angle, closeTo(90, 1e-9));
    });

    test('finds the gradient of a fill, and of a stroke inherited from a group', () {
      expect(SvgGradientEdit.of(_butterfly, _first, 'fill')!.id, 'wing');
      expect(SvgGradientEdit.of(_butterfly, _inGroup, 'stroke')!.id, 'wing');
      expect(SvgGradientEdit.of(_butterfly, _rect, 'fill'), isNull);
      expect(SvgGradientEdit.read(_butterfly, 'nope'), isNull);
    });
  });

  group('model', () {
    final base = SvgGradient.fromColor('#336699');

    test('fromColor makes two stops', () {
      expect(base.stops.map((s) => s.offset), [0, 1]);
      expect(base.stops.first.color, '#336699');
      expect(base.stops.last.color, isNot('#336699'));
    });

    test('a stop never crosses its neighbours, and at least two stay', () {
      final three = base.withStopAt(.5);
      expect(three.stops, hasLength(3));
      final moved = three.withStop(1, three.stops[1].copyWith(offset: 2));
      expect(moved.stops[1].offset, 1);
      expect(three.withoutStop(1).stops, hasLength(2));
      expect(base.withoutStop(0).stops, hasLength(2));
    });

    test('a new stop shows the color the gradient had there', () {
      final mid = SvgGradient.fromColor('#000000').withStopAt(.5).stops[1];
      expect(mid.color, SvgGradient.fromColor('#000000').colorAt(.5).$1);
    });

    test('reversed flips colors and offsets', () {
      final reversed = base.reversed;
      expect(reversed.stops.first.color, base.stops.last.color);
      expect(reversed.stops.first.offset, 0);
    });

    test('angle round-trips and the kind switches', () {
      for (final degrees in [0.0, 45.0, 90.0, 135.0, 180.0, 270.0]) {
        expect(base.withAngle(degrees).angle, closeTo(degrees, 1e-2));
      }
      final radial = base.withKind(SvgGradientKind.radial);
      expect(radial.radius, .5);
      expect(radial.withKind(SvgGradientKind.linear).angle, 0);
    });
  });

  group('writing', () {
    test('changing a gradient only some shapes use copies it', () {
      final gradient = SvgGradientEdit.of(_butterfly, _first, 'fill')!;
      final changed = gradient.withStop(0, gradient.stops[0].copyWith(color: '#FF0000'));
      final out = SvgGradientEdit.apply(_butterfly, const [_first], 'fill', changed);
      expect(SvgGradientEdit.of(out, _first, 'fill')!.stops.first.color, '#FF0000');
      expect(SvgGradientEdit.of(out, _first, 'fill')!.id, startsWith('sm-grad-'));
      // The second shape and the original are untouched.
      expect(SvgGradientEdit.of(out, _second, 'fill')!.id, 'wing');
      expect(SvgGradientEdit.read(out, 'wing')!.stops.first.color, '#3B82F6');
    });

    test('a gradient used by the whole selection is updated where it is', () {
      final both = _butterfly.replaceAll('<g stroke="url(#wing)">', '<g>');
      final gradient = SvgGradientEdit.read(both, 'wing')!;
      // The alias points at it with href, so it is still copied.
      final out = SvgGradientEdit.apply(both, const [_first, _second], 'fill', gradient.reversed);
      expect(
        SvgGradientEdit.of(out, _first, 'fill')!.id,
        SvgGradientEdit.of(out, _second, 'fill')!.id,
      );

      const solo =
          '<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g">'
          '<stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#FFF"/>'
          '</linearGradient></defs><rect fill="url(#g)"/></svg>';
      final updated = SvgGradientEdit.apply(
        solo,
        const [
          ElementPath([1]),
        ],
        'fill',
        SvgGradientEdit.read(solo, 'g')!.reversed,
      );
      expect(SvgGradientEdit.read(updated, 'g')!.stops.first.color, '#FFFFFF');
      expect(updated, isNot(contains('sm-grad-')));
    });

    test('a solid shape gets a gradient in a new defs at the end', () {
      const plain = '<svg xmlns="http://www.w3.org/2000/svg"><rect id="a" fill="#336699"/></svg>';
      final out = SvgGradientEdit.apply(
        plain,
        const [
          ElementPath([0]),
        ],
        'fill',
        SvgGradient.fromColor('#336699'),
      );
      expect(out, contains('fill="url(#sm-grad-1)"'));
      expect(out.indexOf('<rect'), lessThan(out.indexOf('<defs')));
      expect(SvgLayers.list(out).map((l) => l.path), [
        const ElementPath([0]),
      ]);
    });

    test('stops that carry an animation keep it', () {
      const animated =
          '<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g">'
          '<stop offset="0" stop-color="#000"><animate attributeName="stop-color" values="#000;#FFF" dur="1s"/></stop>'
          '<stop offset="1" stop-color="#FFF"/></linearGradient></defs><rect fill="url(#g)"/></svg>';
      final gradient = SvgGradientEdit.read(animated, 'g')!;
      final out = SvgGradientEdit.apply(
        animated,
        const [
          ElementPath([1]),
        ],
        'fill',
        gradient.withStop(1, gradient.stops[1].copyWith(color: '#123456')),
      );
      expect(out, contains('<animate'));
      expect(out, contains('#123456'));
    });

    test('switching kind rewrites the element in place', () {
      const solo =
          '<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x2="1">'
          '<stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#FFF"/>'
          '</linearGradient></defs><rect fill="url(#g)"/></svg>';
      final gradient = SvgGradientEdit.read(solo, 'g')!;
      final out = SvgGradientEdit.apply(
        solo,
        const [
          ElementPath([1]),
        ],
        'fill',
        gradient.withKind(SvgGradientKind.radial),
      );
      expect(out, contains('<radialGradient id="g"'));
      expect(out, isNot(contains('linearGradient')));
      expect(SvgGradientEdit.read(out, 'g')!.stops, hasLength(2));
    });

    test('back to a solid color drops the gradient the editor made', () {
      const plain = '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#336699"/></svg>';
      final gradient = SvgGradientEdit.apply(
        plain,
        const [
          ElementPath([0]),
        ],
        'fill',
        SvgGradient.fromColor('#336699'),
      );
      final solid = SvgGradientEdit.toSolid(
        gradient,
        const [
          ElementPath([0]),
        ],
        'fill',
        '#00FF00',
      );
      expect(solid, contains('fill="#00FF00"'));
      expect(solid, isNot(contains('Gradient')));
      expect(solid, isNot(contains('defs')));
    });

    test('a gradient from the file is never deleted', () {
      final solid = SvgGradientEdit.toSolid(_butterfly, const [_first], 'fill', '#00FF00');
      expect(SvgGradientEdit.read(solid, 'wing'), isNotNull);
    });
  });

  group('per variant', () {
    const themed =
        '<svg xmlns="http://www.w3.org/2000/svg"><style>.a{fill:#111}'
        '@media (prefers-color-scheme: light){.a{fill:#EEE}}</style>'
        '<rect class="a" width="5" height="5"/></svg>';
    const rect = ElementPath([1]);

    test('a gradient in one variant leaves the other one alone', () {
      final out = SvgGradientEdit.applyScheme(
        themed,
        const [rect],
        'fill',
        SvgColorScheme.dark,
        SvgGradient.fromColor('#336699'),
      );
      expect(
        SvgThemeEdit.paintFor(out, rect, SvgColorScheme.dark, 'fill'),
        startsWith('url(#sm-grad-'),
      );
      expect(SvgThemeEdit.paintFor(out, rect, SvgColorScheme.light, 'fill'), '#EEEEEE');
    });

    test('editing it again updates the same gradient', () {
      final first = SvgGradientEdit.applyScheme(
        themed,
        const [rect],
        'fill',
        SvgColorScheme.dark,
        SvgGradient.fromColor('#336699'),
      );
      final gradient = SvgGradientEdit.ofScheme(first, rect, 'fill', SvgColorScheme.dark)!;
      final second = SvgGradientEdit.applyScheme(
        first,
        const [rect],
        'fill',
        SvgColorScheme.dark,
        gradient.reversed,
      );
      expect(SvgGradientEdit.ofScheme(second, rect, 'fill', SvgColorScheme.dark)!.id, gradient.id);
      expect(RegExp('<linearGradient').allMatches(second), hasLength(1));
    });

    test('both variants can have their own gradient', () {
      var out = SvgGradientEdit.applyScheme(
        themed,
        const [rect],
        'fill',
        SvgColorScheme.dark,
        SvgGradient.fromColor('#336699'),
      );
      out = SvgGradientEdit.applyScheme(
        out,
        const [rect],
        'fill',
        SvgColorScheme.light,
        SvgGradient.fromColor('#CC3300'),
      );
      final dark = SvgGradientEdit.ofScheme(out, rect, 'fill', SvgColorScheme.dark)!;
      final light = SvgGradientEdit.ofScheme(out, rect, 'fill', SvgColorScheme.light)!;
      expect(dark.id, isNot(light.id));
      expect(dark.stops.first.color, '#336699');
      expect(light.stops.first.color, '#CC3300');
    });
  });
}
