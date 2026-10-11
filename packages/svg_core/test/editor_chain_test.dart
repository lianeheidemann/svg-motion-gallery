import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

const _base =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<rect width="10" height="10"/><circle r="5"/></svg>';

const _rect = ElementPath([0]);

int _count(String svg, String pattern) => RegExp(pattern).allMatches(svg).length;

/// Moves, animates, moves again and changes the motion of the rect, each
/// time on the selection the edit before left, like the editor does.
({String svg, ElementPath selection}) _editInTurns() {
  var result = SvgTransformEdit.apply(_base, _rect, const SvgTransformValues(translateX: 20));
  result = SvgAnimationEdit.addPreset(result.svg, result.selection!, SvgAnimationPreset.spin);
  result = SvgTransformEdit.apply(
    result.svg,
    result.selection!,
    SvgTransformEdit.read(result.svg, result.selection).copyWith(translateX: 30),
  );
  result = SvgAnimationEdit.addPreset(result.svg, result.selection!, SvgAnimationPreset.pulse);
  return (svg: result.svg, selection: result.selection!);
}

void main() {
  group('editor groups around a layer', () {
    test('moving and animating in turns keeps one transform and one motion', () {
      final (:svg, :selection) = _editInTurns();
      expect(selection, _rect, reason: 'the layer, not one of its groups');
      expect(_count(svg, 'data-sm-edit="element"'), 1);
      expect(_count(svg, '<g[^>]*data-sm-anim='), 1, reason: 'pulse replaced spin');
      expect(SvgTransformEdit.read(svg, selection).translateX, 30);
      expect(SvgAnimationEdit.presetAt(svg, selection), SvgAnimationPreset.pulse);
      expect(svg, isNot(contains('sm-spin 2s')));
    });

    test('the transform is outside and the motion inside, around the drawn element', () {
      final (:svg, selection: _) = _editInTurns();
      final layers = SvgLayers.list(svg);
      expect(layers.map((l) => l.tag), ['rect', 'circle'], reason: 'no rows for the groups');
      expect(layers.first.path, _rect);
      expect(layers.first.depth, 0);
      expect(layers.first.isAnimated, isTrue);
      expect(svg, matches(RegExp('data-sm-edit="element"[^>]*>\\s*<g[^>]*data-sm-anim')));
    });

    test('the values are found from the layer, a group or the element itself', () {
      final (:svg, selection: _) = _editInTurns();
      for (final path in const [
        ElementPath([0]),
        ElementPath([0, 0]),
        ElementPath([0, 0, 0]),
      ]) {
        expect(SvgTransformEdit.read(svg, path).translateX, 30, reason: '$path');
        expect(SvgAnimationEdit.presetAt(svg, path), SvgAnimationPreset.pulse, reason: '$path');
      }
    });

    test('taking the motion out keeps the move, and the other way round', () {
      final (:svg, :selection) = _editInTurns();
      final still = SvgAnimationEdit.removePreset(svg, selection);
      expect(still.selection, _rect);
      expect(_count(still.svg, '<g[^>]*data-sm-anim='), 0);
      expect(SvgTransformEdit.read(still.svg, _rect).translateX, 30);

      final back = SvgTransformEdit.apply(svg, selection, SvgTransformValues.identity);
      expect(back.selection, _rect);
      expect(back.svg, isNot(contains('data-sm-edit')));
      expect(SvgAnimationEdit.presetAt(back.svg, _rect), SvgAnimationPreset.pulse);

      final plain = SvgTransformEdit.apply(still.svg, _rect, SvgTransformValues.identity);
      expect(SvgLayers.list(plain.svg).first.path, _rect);
      expect(plain.svg, isNot(contains('<g')));
    });

    test('ordering, copying, hiding and deleting take the groups along', () {
      final (:svg, selection: _) = _editInTurns();
      final forward = SvgLayers.bringForward(svg, const ElementPath([0, 0, 0]));
      expect(forward.selection, const ElementPath([1]));
      expect(SvgLayers.list(forward.svg).map((l) => l.tag), ['circle', 'rect']);
      expect(SvgTransformEdit.read(forward.svg, forward.selection).translateX, 30);

      final copy = SvgLayers.duplicate(svg, _rect);
      expect(_count(copy.svg, 'data-sm-edit="element"'), 2);
      expect(SvgLayers.list(copy.svg).map((l) => l.tag), ['rect', 'rect', 'circle']);

      final hidden = SvgLayers.toggleVisibility(svg, _rect);
      expect(SvgLayers.list(hidden).first.visible, isFalse);
      final shown = SvgLayers.toggleVisibility(hidden, _rect);
      expect(SvgLayers.list(shown).first.visible, isTrue);

      final removed = SvgLayers.remove(svg, _rect).svg;
      expect(SvgLayers.list(removed).map((l) => l.tag), ['circle']);
      expect(removed, isNot(contains('data-sm-edit')));
    });

    test('a name and a text go on what the user drew, inside the groups', () {
      var svg = SvgTransformEdit.apply(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><text>Oi</text></svg>',
        const ElementPath([0]),
        const SvgTransformValues(rotation: 10),
      ).svg;
      svg = SvgLayers.rename(svg, const ElementPath([0]), 'Título');
      svg = SvgLayers.setText(svg, const ElementPath([0]), 'Olá');
      final layer = SvgLayers.list(svg).single;
      expect((layer.tag, layer.name, layer.text), ('text', 'Título', 'Olá'));
      expect(SvgTransformEdit.read(svg, layer.path).rotation, 10, reason: 'the turn is kept');
    });

    test('the group around the whole drawing is not a layer either', () {
      final svg = SvgTransformEdit.apply(_base, null, const SvgTransformValues(scale: .9)).svg;
      final layers = SvgLayers.list(svg);
      expect(layers.map((l) => (l.tag, l.depth)), [('rect', 0), ('circle', 0)]);
      expect(layers.first.path, const ElementPath([0, 0]));
    });

    test('groups an older version stacked are one layer, cleaned when edited', () {
      // Spin around the move, a second move around it, a pulse around that.
      const stacked =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
          '<g data-sm-anim="pulse" style="animation:sm-pulse 2s ease-in-out infinite">'
          '<g data-sm-edit="element" transform="translate(30 0)">'
          '<g data-sm-anim="spin" style="animation:sm-spin 2s linear infinite">'
          '<g data-sm-edit="element" transform="translate(20 0)"><rect width="10" height="10"/>'
          '</g></g></g></g><circle r="5"/></svg>';
      final layers = SvgLayers.list(stacked);
      expect(layers.map((l) => l.tag), ['rect', 'circle']);
      expect(SvgAnimationEdit.presetAt(stacked, _rect), SvgAnimationPreset.spin);

      final fade = SvgAnimationEdit.addPreset(stacked, _rect, SvgAnimationPreset.fade);
      expect(_count(fade.svg, '<g[^>]*data-sm-anim='), 1, reason: 'one motion left');
      expect(SvgAnimationEdit.presetAt(fade.svg, fade.selection!), SvgAnimationPreset.fade);
      expect(SvgTransformEdit.read(fade.svg, fade.selection).translateX, 30, reason: 'outer move');
    });

    test('theme marks are given by layer', () {
      const themed =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<style>@media (prefers-color-scheme: light){.a{fill:#EEEEEE}}</style>'
          '<g class="a"><circle r="2"/></g></svg>';
      final moved = SvgTransformEdit.apply(
        themed,
        const ElementPath([1]),
        const SvgTransformValues(translateX: 2),
      ).svg;
      final marks = SvgThemeMarks.list(moved);
      final group = marks[const ElementPath([1])]!;
      expect(group.originIn(SvgColorScheme.light), SvgThemeOrigin.own);
      final circle = marks[const ElementPath([1, 0, 0])]!;
      expect(circle.sourceIn(SvgColorScheme.light), const ElementPath([1]), reason: 'the layer');
      expect(SvgThemeEdit.isShown(moved, const ElementPath([1]), SvgColorScheme.light), isTrue);
    });
  });
}
