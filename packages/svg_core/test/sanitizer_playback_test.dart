import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeSvg', () {
    test('removes scripts, handlers and javascript links', () {
      final clean = sanitizeSvg(
        '<svg onload="alert(1)"><script>alert(2)</script>'
        '<a href="javascript:alert(3)"><rect onclick="x()" fill="red"/></a>'
        '<foreignObject><iframe src="https://example.com"/></foreignObject></svg>',
      );
      expect(clean, isNot(contains('alert')));
      expect(clean, isNot(contains('onclick')));
      expect(clean, isNot(contains('iframe')));
      expect(clean, contains('fill="red"'));
    });

    test('strips scripts from invalid markup too', () {
      expect(sanitizeSvg('<svg><script>bad()</script><rect>'), isNot(contains('bad')));
    });
  });

  group('forcePlayOnce', () {
    test('plays SMIL and CSS animations a single time', () {
      final once = forcePlayOnce('<svg><animate dur="1s" repeatCount="indefinite"/></svg>');
      expect(once, contains('repeatCount="1"'));
      expect(once, contains('fill="freeze"'));
      final css = forcePlayOnce('<svg><style>.a{animation:x 1s infinite}</style></svg>');
      expect(css, contains('animation-iteration-count:1 !important'));
      const still = '<svg><rect/></svg>';
      expect(forcePlayOnce(still), same(still));
    });
  });

  group('forceLoop', () {
    test('makes SMIL animations repeat forever', () {
      final looped = forceLoop('<svg><animate dur="1s" repeatCount="2" repeatDur="3s"/></svg>');
      expect(looped, contains('repeatCount="indefinite"'));
      expect(looped, isNot(contains('repeatDur')));
    });

    test('adds an infinite iteration rule for CSS animation', () {
      final looped = forceLoop('<svg><style>.a{animation:x 1s}</style></svg>');
      expect(looped, contains('animation-iteration-count:infinite'));
    });

    test('leaves static documents untouched', () {
      const svg = '<svg><rect/></svg>';
      expect(forceLoop(svg), same(svg));
    });
  });

  group('tokenizeSvg', () {
    test('covers the source completely and classifies parts', () {
      const source = '<!-- c --><svg width="10">&amp;</svg>';
      final tokens = tokenizeSvg(source);
      expect(tokens.map((t) => source.substring(t.start, t.end)).join(), source);
      String textOf(SvgTokenType type) => tokens
          .where((t) => t.type == type)
          .map((t) => source.substring(t.start, t.end))
          .join('|');
      expect(textOf(SvgTokenType.comment), '<!-- c -->');
      expect(textOf(SvgTokenType.tag), 'svg|svg');
      expect(textOf(SvgTokenType.attribute), 'width');
      expect(textOf(SvgTokenType.value), '"10"');
      expect(textOf(SvgTokenType.entity), '&amp;');
    });
  });

  group('EditHistory', () {
    test('undoes, redoes and drops the redo branch on push', () {
      final history = EditHistory('a')
        ..push('b')
        ..push('c');
      expect(history.undo(), 'b');
      expect(history.canRedo, isTrue);
      history.push('d');
      expect(history.canRedo, isFalse);
      expect(history.undo(), 'b');
      expect(history.undo(), 'a');
      expect(history.canUndo, isFalse);
      expect(history.redo(), 'b');
    });

    test('ignores duplicates and respects the limit', () {
      final history = EditHistory(0, limit: 3)
        ..push(0)
        ..push(1)
        ..push(2)
        ..push(3);
      expect(history.current, 3);
      history
        ..undo()
        ..undo();
      expect(history.canUndo, isFalse);
      expect(history.current, 1);
    });
  });
}
