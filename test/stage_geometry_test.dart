import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_motion_gallery/src/features/editor/selection_highlight.dart';
import 'package:svg_motion_gallery/src/features/editor/stage_geometry.dart';
import 'package:svg_view/svg_view.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"><rect/></svg>';

void main() {
  test('the canvas is fitted and centered inside the stage padding', () {
    final geometry = StageGeometry.of(_svg, const Size(200, 200), const EdgeInsets.all(16));
    expect(geometry.scale, closeTo(1.68, 1e-9));
    final rect = geometry.canvasRect;
    expect(rect.left, closeTo(16, 1e-9));
    expect(rect.width, closeTo(168, 1e-9));
    expect(rect.height, closeTo(84, 1e-9));
    expect(rect.center.dy, closeTo(100, 1e-9), reason: 'centered vertically');
  });

  testWidgets('CanvasFrame draws without taking touches', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              GestureDetector(onTap: () => taps++, behavior: HitTestBehavior.opaque),
              const Positioned.fill(
                child: CanvasFrame(svg: _svg, padding: EdgeInsets.all(16)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1, reason: 'the frame lets touches through');
  });

  testWidgets('SelectionHighlight follows what the renderer reports, without taking touches', (
    tester,
  ) async {
    final controller = SvgPlaybackController(cycle: const Duration(seconds: 1));
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              GestureDetector(onTap: () => taps++, behavior: HitTestBehavior.opaque),
              Positioned.fill(
                child: SelectionHighlight(
                  controller: controller,
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The renderer is what reports the box; stand in for it.
    controller.selectElement([1]);
    // ignore: invalid_use_of_internal_member
    controller.report(seconds: 0, paused: false, box: [0.25, 0.25, 0.75, 0.75]);
    await tester.pump();
    expect(controller.selectionBounds, const Rect.fromLTRB(0.25, 0.25, 0.75, 0.75));
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1, reason: 'the highlight lets touches through');
  });
}
