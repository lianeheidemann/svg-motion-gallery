import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const base =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">'
    '<defs><linearGradient id="g"><stop stop-color="#0f0"/></linearGradient></defs>'
    '<rect id="bg" width="100" height="50" fill="#040D19"/>'
    '<g id="group" transform="translate(10 10)"><circle r="5" fill="red"/><path d="M0 0" stroke="#FF0000"/></g>'
    '<text x="5" y="5">Hi</text>'
    '</svg>';

void main() {
  group('SvgLayers', () {
    test('lists drawable elements with depth and paths', () {
      final layers = SvgLayers.list(base);
      expect(layers.map((l) => l.tag), ['rect', 'g', 'circle', 'path', 'text']);
      expect(layers.map((l) => l.depth), [0, 0, 1, 1, 0]);
      expect(layers[2].path, const ElementPath([2, 0]));
      expect(layers.first.id, 'bg');
      expect(layers.last.text, 'Hi');
    });

    test('toggles visibility', () {
      final hidden = SvgLayers.toggleVisibility(base, const ElementPath([1]));
      expect(SvgLayers.list(hidden).first.visible, isFalse);
      final shown = SvgLayers.toggleVisibility(hidden, const ElementPath([1]));
      expect(SvgLayers.list(shown).first.visible, isTrue);
    });

    test('renames a layer without touching its id, and clears the name', () {
      final named = SvgLayers.rename(base, const ElementPath([1]), '  Fundo  ');
      expect(named, contains('data-name="Fundo"'));
      expect(named, contains('id="bg"'));
      expect(SvgLayers.list(named).firstWhere((l) => l.id == 'bg').name, 'Fundo');
      final cleared = SvgLayers.rename(named, const ElementPath([1]), '   ');
      expect(cleared, isNot(contains('data-name')));
      expect(SvgLayers.list(cleared).firstWhere((l) => l.id == 'bg').name, isNull);
    });

    test('removes, duplicates and reorders', () {
      final removed = SvgLayers.remove(base, const ElementPath([1]));
      expect(removed.selection, isNull);
      expect(SvgLayers.list(removed.svg).first.tag, 'g');

      final duplicated = SvgLayers.duplicate(base, const ElementPath([1]));
      expect(duplicated.selection, const ElementPath([2]));
      expect(duplicated.svg, contains('id="bg-copy"'));

      final forward = SvgLayers.bringForward(base, const ElementPath([1]));
      expect(forward.selection, const ElementPath([2]));
      expect(SvgLayers.list(forward.svg).first.tag, 'g');

      final backward = SvgLayers.sendBackward(forward.svg, forward.selection!);
      expect(SvgLayers.list(backward.svg).first.tag, 'rect');
      expect(SvgLayers.sendBackward(base, const ElementPath([1])).svg, base);
    });

    test('edits text', () {
      final edited = SvgLayers.setText(base, const ElementPath([3]), 'Olá');
      expect(edited, contains('>Olá</text>'));
    });
  });

  group('SvgTransformEdit', () {
    test('stretches only the width or only the height, and reads it back', () {
      const values = SvgTransformValues(scale: 2, widthFactor: 0.5, heightFactor: 1.5);
      final result = SvgTransformEdit.apply(base, const ElementPath([2]), values);
      expect(result.svg, contains('scale(1 3)'), reason: 'scale 2 x (0.5, 1.5)');
      final read = SvgTransformEdit.read(result.svg, result.selection);
      expect(read.scale, closeTo(1, 1e-9));
      expect(read.heightFactor, closeTo(3, 1e-9));
      // Same drawing either way: the factors are only a different way to write it.
      expect(read.scale * read.widthFactor, closeTo(1, 1e-9));
      expect(read.scale * read.heightFactor, closeTo(3, 1e-9));
      expect(const SvgTransformValues(widthFactor: 2).isIdentity, isFalse);
      expect(
        SvgTransformEdit.apply(base, const ElementPath([2]), const SvgTransformValues()).svg,
        base,
      );
    });

    const values = SvgTransformValues(
      translateX: 5,
      translateY: -2.5,
      rotation: 30,
      scale: 1.5,
      opacity: .5,
    );

    test('wraps the whole drawing and reads the values back', () {
      final result = SvgTransformEdit.apply(base, null, values);
      expect(result.selection, isNull);
      expect(result.svg, contains('data-sm-edit="root"'));
      expect(result.svg, contains('translate(5 -2.5) rotate(30) scale(1.5)'));
      expect(result.svg, contains('<defs>'), reason: 'defs stay outside the wrapper');
      expect(SvgTransformEdit.read(result.svg, null), values);

      final again = SvgTransformEdit.apply(result.svg, null, values.copyWith(rotation: 45));
      expect(RegExp('data-sm-edit').allMatches(again.svg).length, 1);
      expect(SvgTransformEdit.read(again.svg, null).rotation, 45);
    });

    test('identity removes the wrapper again', () {
      final wrapped = SvgTransformEdit.apply(base, null, values).svg;
      final restored = SvgTransformEdit.apply(wrapped, null, SvgTransformValues.identity).svg;
      expect(restored, isNot(contains('data-sm-edit')));
      expect(SvgLayers.list(restored).map((l) => l.tag), SvgLayers.list(base).map((l) => l.tag));
    });

    test('wraps one element, keeps its own transform and selects the wrapper', () {
      final result = SvgTransformEdit.apply(base, const ElementPath([2]), values);
      expect(result.svg, contains('transform="translate(10 10)"'));
      expect(result.selection, const ElementPath([2]));
      expect(SvgTransformEdit.read(result.svg, result.selection), values);
      expect(
        SvgTransformEdit.read(result.svg, const ElementPath([2, 0])),
        values,
        reason: 'selecting the wrapped element finds its wrapper',
      );

      final undone = SvgTransformEdit.apply(
        result.svg,
        result.selection,
        SvgTransformValues.identity,
      );
      expect(undone.svg, isNot(contains('data-sm-edit')));
      expect(undone.selection, const ElementPath([2]));
    });
  });

  group('SvgDocumentEdit.ensureViewBox', () {
    test('adds a viewBox from the declared size only when missing', () {
      expect(
        SvgDocumentEdit.ensureViewBox('<svg width="40" height="20"/>'),
        contains('viewBox="0 0 40 20"'),
      );
      const withBox = '<svg width="40" height="20" viewBox="0 0 4 2"/>';
      expect(SvgDocumentEdit.ensureViewBox(withBox), same(withBox));
      const relative = '<svg width="100%" height="20"/>';
      expect(SvgDocumentEdit.ensureViewBox(relative), same(relative));
    });
  });

  group('SvgDocumentEdit.setSize', () {
    test('adds a viewBox before resizing when missing', () {
      final resized = SvgDocumentEdit.setSize(
        '<svg width="10" height="20"/>',
        width: 30,
        height: 60,
      );
      expect(resized, contains('viewBox="0 0 10 20"'));
      expect(resized, contains('width="30"'));
      expect(SvgMetadata.parse(resized).height, 60);
    });
  });

  group('SvgColors', () {
    test('extracts a normalized palette in order', () {
      expect(SvgColors.palette(base), ['#00FF00', '#040D19', '#FF0000']);
    });

    test('replaces a color in every notation, ignoring url() references', () {
      const svg =
          '<svg><style>.a{fill:rgb(255,0,0)} .b{fill:url(#fade)}</style>'
          '<rect fill="red" stroke="#F00"/><circle style="fill:#ff000080"/>'
          '<animate attributeName="fill" values="#f00;#00f"/></svg>';
      final replaced = SvgColors.replace(svg, '#FF0000', '#00AAFF');
      expect(replaced, isNot(contains('red')));
      expect(replaced, contains('fill="#00AAFF" stroke="#00AAFF"'));
      expect(replaced, contains('fill:#00AAFF80'));
      expect(replaced, contains('values="#00AAFF;#00f"'));
      expect(replaced, contains('url(#fade)'));
      expect(replaced, contains('.a{fill:#00AAFF}'));
    });

    test('normalizes notations', () {
      expect(SvgColorValue.normalize('#abc'), '#AABBCC');
      expect(SvgColorValue.normalize('rgb(100%, 0%, 0%)'), '#FF0000');
      expect(SvgColorValue.normalize('rgba(0 128 255 / .5)'), '#0080FF');
      expect(SvgColorValue.normalize('White'), '#FFFFFF');
      expect(SvgColorValue.normalize('none'), isNull);
      expect(SvgColorValue.normalize('url(#a)'), isNull);
    });
  });

  group('SvgPaintEdit', () {
    test('reads and writes fill, stroke and stroke width', () {
      const circle = ElementPath([2, 0]);
      expect(SvgPaintEdit.read(base, circle).fillColor, '#FF0000');
      var svg = SvgPaintEdit.setFill(base, circle, '#123456');
      svg = SvgPaintEdit.setStroke(svg, circle, '#ABCDEF');
      svg = SvgPaintEdit.setStrokeWidth(svg, circle, 3);
      final paint = SvgPaintEdit.read(svg, circle);
      expect(paint.fillColor, '#123456');
      expect(paint.strokeColor, '#ABCDEF');
      expect(paint.strokeWidth, 3);
      expect(SvgPaintEdit.read(SvgPaintEdit.setFill(svg, circle, null), circle).fill, 'none');
    });

    test('style declarations are replaced by the new attribute', () {
      const svg = '<svg><rect style="fill:red;opacity:.5"/></svg>';
      final edited = SvgPaintEdit.setFill(svg, const ElementPath([0]), '#000000');
      expect(edited, contains('fill="#000000"'));
      expect(edited, contains('style="opacity:.5"'));
    });

    test('paints through editor wrappers', () {
      final wrapped = SvgTransformEdit.apply(
        base,
        const ElementPath([1]),
        const SvgTransformValues(rotation: 10),
      );
      final painted = SvgPaintEdit.setFill(wrapped.svg, wrapped.selection!, '#111111');
      expect(painted, contains('<rect id="bg" width="100" height="50" fill="#111111"/>'));
    });
  });

  group('SvgAnimationEdit', () {
    const animated =
        '<svg><style>.a{animation: spin 2s linear infinite; animation-delay: 500ms}</style>'
        '<circle><animate attributeName="r" dur="4s" begin="1s;x.end" repeatCount="indefinite"/></circle>'
        '<rect style="animation: pulse 1.5s"/></svg>';

    test('changes speed of SMIL and CSS animation', () {
      final faster = SvgAnimationEdit.changeSpeed(animated, 2);
      expect(faster, contains('dur="2s"'));
      expect(faster, contains('begin="0.5s;x.end"'));
      expect(faster, contains('animation: spin 1s linear infinite'));
      expect(faster, contains('animation-delay: 250ms'));
      expect(faster, contains('animation: pulse 0.75s'));
      expect(SvgMetadata.parse(faster).cycleDuration, const Duration(seconds: 2));
    });

    test('removes every animation', () {
      final still = SvgAnimationEdit.removeAll(
        animated.replaceFirst('</style>', '@keyframes spin{to{transform:rotate(1turn)}}</style>'),
      );
      expect(SvgMetadata.parse(still).isAnimated, isFalse);
      expect(still, isNot(contains('keyframes')));
      expect(still, isNot(contains('<animate')));
    });

    test('adds, replaces and removes presets through a wrapper', () {
      final spun = SvgAnimationEdit.addPreset(
        base,
        const ElementPath([1]),
        SvgAnimationPreset.spin,
        seconds: 3,
      );
      expect(spun.svg, contains('animation:sm-spin 3s linear infinite'));
      expect(spun.svg, contains('@keyframes sm-spin'));
      expect(SvgAnimationEdit.presetAt(spun.svg, spun.selection!), SvgAnimationPreset.spin);
      expect(SvgMetadata.parse(spun.svg).isAnimated, isTrue);

      final pulsed = SvgAnimationEdit.addPreset(
        spun.svg,
        spun.selection!,
        SvgAnimationPreset.pulse,
      );
      expect(
        RegExp('data-sm-anim="').allMatches(pulsed.svg).length,
        2,
        reason: 'one keyframes style + one wrapper',
      );
      expect(SvgAnimationEdit.presetAt(pulsed.svg, pulsed.selection!), SvgAnimationPreset.pulse);

      final removed = SvgAnimationEdit.removePreset(pulsed.svg, pulsed.selection!);
      expect(removed.svg, isNot(contains('animation:sm-')));
      expect(SvgLayers.list(removed.svg).first.id, 'bg');
    });

    test('keyframes come back after removing all animation', () {
      final spun = SvgAnimationEdit.addPreset(
        base,
        const ElementPath([1]),
        SvgAnimationPreset.spin,
      );
      final still = SvgAnimationEdit.removeAll(spun.svg);
      final path = SvgLayers.list(still).first.path;
      final again = SvgAnimationEdit.addPreset(still, path, SvgAnimationPreset.fade);
      expect(again.svg, contains('@keyframes sm-fade'));
    });
  });

  group('SvgDocumentEdit window', () {
    const sized =
        '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600">'
        '<rect x="100" y="50" width="200" height="100"/></svg>';

    test('crops the viewBox and keeps one unit the same size on screen', () {
      final cropped = SvgDocumentEdit.setViewBox(
        sized,
        minX: 100,
        minY: 50,
        width: 400,
        height: 300,
      );
      expect(cropped, contains('viewBox="100 50 400 300"'));
      expect(cropped, contains('width="400"'));
      expect(cropped, contains('height="300"'));
      final meta = SvgMetadata.parse(cropped);
      expect(meta.canvas.minX, 100);
      expect(meta.canvas.width, 400);
    });

    test('works without width/height and rejects empty windows', () {
      const bare = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>';
      final cropped = SvgDocumentEdit.setViewBox(bare, minX: 1, minY: 2, width: 5, height: 6);
      expect(cropped, contains('viewBox="1 2 5 6"'));
      expect(cropped, isNot(contains('width=')));
      expect(SvgDocumentEdit.setViewBox(bare, minX: 0, minY: 0, width: 0, height: 5), bare);
    });

    test('uses width/height as the old window when there is no viewBox', () {
      const noBox = '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"/>';
      final cropped = SvgDocumentEdit.setViewBox(noBox, minX: 0, minY: 0, width: 100, height: 100);
      expect(cropped, contains('width="100"'));
      expect(cropped, contains('height="100"'));
    });

    test('fits the window to a content box with a margin', () {
      final fitted = SvgDocumentEdit.fitWindow(
        sized,
        x: 100,
        y: 50,
        width: 200,
        height: 100,
        margin: 0.1,
      );
      // 10 % of the larger side (200) = 20 on every side.
      expect(fitted, contains('viewBox="80 30 240 140"'));
    });
  });

  group('SvgInsertEdit', () {
    test('inserts centered shapes on top and selects them', () {
      for (final kind in SvgShapeKind.values) {
        final result = SvgInsertEdit.insert(base, kind, color: '#FF00AA');
        expect(validateSvg(result.svg).isValid, isTrue, reason: kind.name);
        expect(SvgLayers.list(result.svg).last.path, result.selection, reason: kind.name);
        expect(SvgColors.palette(result.svg), contains('#FF00AA'), reason: kind.name);
      }
      final circle = SvgInsertEdit.insert(base, SvgShapeKind.circle, color: '#FFFFFF', size: .5);
      expect(circle.svg, contains('<circle cx="50" cy="25" r="12.5" fill="#FFFFFF"/>'));
      final text = SvgInsertEdit.insert(base, SvgShapeKind.text, color: '#FFFFFF', text: 'Oi');
      expect(text.svg, contains('>Oi</text>'));
    });
  });
}
