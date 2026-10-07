import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/l10n/l10n.dart';

String _svg(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">$body</svg>';

List<String> _labels(String svg) {
  final l10n = lookupAppLocalizations(const Locale('pt'));
  final layers = SvgLayers.list(svg);
  final labels = l10n.layerLabels(layers);
  return [for (final layer in layers) labels[layer.path]!];
}

void main() {
  test('same-named siblings are numbered like the tree', () {
    final labels = _labels(
      _svg('<g><circle r="1"/><circle r="1"/></g><g><circle r="1"/><circle r="1"/></g>'),
    );
    expect(labels, [
      'Grupo 1',
      'Círculo 1.1',
      'Círculo 1.2',
      'Grupo 2',
      'Círculo 2.1',
      'Círculo 2.2',
    ]);
  });

  test('a name that is alone among its siblings gets no number', () {
    expect(_labels(_svg('<g><rect/></g><g><rect/></g>')), [
      'Grupo 1',
      'Retângulo',
      'Grupo 2',
      'Retângulo',
    ]);
    expect(_labels(_svg('<rect/><circle r="1"/>')), ['Retângulo', 'Círculo']);
  });

  test('unnumbered parents do not prefix their children', () {
    expect(_labels(_svg('<g><circle r="1"/><circle r="1"/></g>')), [
      'Grupo',
      'Círculo 1',
      'Círculo 2',
    ]);
  });

  test('editor wrappers are transparent for numbering', () {
    var svg = _svg('<circle r="1"/><circle r="1"/><circle r="1"/>');
    svg = SvgTransformEdit.apply(
      svg,
      const ElementPath([1]),
      const SvgTransformValues(translateX: 2),
    ).svg;
    expect(_labels(svg), ['Círculo 1', 'Ajuste do editor', 'Círculo 2', 'Círculo 3']);
  });

  test('chosen names are used and numbered when they repeat', () {
    var svg = _svg('<rect/><rect/><circle r="1"/>');
    svg = SvgLayers.rename(svg, const ElementPath([0]), 'Estrela');
    svg = SvgLayers.rename(svg, const ElementPath([1]), 'Estrela');
    expect(_labels(svg), ['Estrela 1', 'Estrela 2', 'Círculo']);
    expect(SvgLayers.list(svg).first.name, 'Estrela');
    expect(svg, contains('data-name="Estrela"'));
    expect(svg, isNot(contains(' id=')), reason: 'the id is never touched');
  });
}
