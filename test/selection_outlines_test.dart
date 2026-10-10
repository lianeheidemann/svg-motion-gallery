import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/features/editor/selection_outlines.dart';
import 'package:svg_motion_gallery/src/features/editor/stage_geometry.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<rect x="1" y="1" width="2" height="2" fill="#f00"/>'
    '<rect x="5" y="1" width="2" height="2" fill="#0f0"/>'
    '<g><rect x="1" y="6" width="2" height="2" fill="#00f"/></g>'
    '</svg>';

void main() {
  test('only shapes drawn on the canvas get an outline from the document', () {
    final shapes = movablesAmong(_svg, [
      const ElementPath([0]),
      const ElementPath([1]),
      const ElementPath([2]), // a group: left to the renderer
    ]);
    expect(shapes.map((s) => s.path), [
      const ElementPath([0]),
      const ElementPath([1]),
    ]);
    expect(movablesAmong(_svg, const []), isEmpty);
  });

  test('the outline turns and resizes with the shape', () {
    // Both shapes are scaled and turned, the way Transformar does it.
    var svg = _svg;
    for (final index in [1, 0]) {
      svg = SvgTransformEdit.apply(
        svg,
        ElementPath([index]),
        const SvgTransformValues(scale: 0.5, rotation: -29),
      ).svg;
    }
    final map = StageGeometry.of(svg, const Size(100, 100), EdgeInsets.zero);
    final shapes = movablesAmong(svg, [
      const ElementPath([0]),
      const ElementPath([1]),
    ]);
    expect(shapes, hasLength(2));
    for (final shape in shapes) {
      final outline = outlineOf(shape, map);
      // 2 units at scale 0.5 on a 10-unit canvas drawn at 10 px per unit,
      // plus the 4 px of room on each side.
      expect(outline.rect.width, closeTo(2 * 0.5 * map.scale + 8, 1e-6));
      expect(outline.rect.height, closeTo(2 * 0.5 * map.scale + 8, 1e-6));
      expect(outline.turn, closeTo(-29 * math.pi / 180, 1e-9));
    }
  });

  test('an unchanged shape has an unturned outline of its own size', () {
    final map = StageGeometry.of(_svg, const Size(100, 100), EdgeInsets.zero);
    final shape = movablesAmong(_svg, [
      const ElementPath([0]),
    ]).single;
    final outline = outlineOf(shape, map);
    expect(outline.turn, 0);
    expect(outline.rect.width, closeTo(2 * map.scale + 8, 1e-6));
  });
}
