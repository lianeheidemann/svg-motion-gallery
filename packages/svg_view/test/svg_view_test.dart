import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_view/src/playback_controller.dart' show SvgPlaybackTarget;
import 'package:svg_view/svg_view.dart';

const adaptive = '''
<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
  <style>.bg{fill:#000}@media (prefers-color-scheme: light){.bg{fill:#fff}}</style>
  <rect class="bg" width="10" height="10" onclick="evil()"/>
  <script>evil()</script>
</svg>''';

void main() {
  group('prepareSvgForDisplay', () {
    test('sanitizes, resolves the scheme and adds a viewBox', () {
      final light = prepareSvgForDisplay(adaptive, scheme: SvgColorScheme.light);
      expect(light, isNot(contains('evil')));
      expect(light, contains('.bg{fill:#fff}'));
      expect(light, contains('viewBox="0 0 10 10"'));
      final dark = prepareSvgForDisplay(adaptive, scheme: SvgColorScheme.dark);
      expect(dark, isNot(contains('#fff')));
    });

    test('inlines CSS for renderers without stylesheet support', () {
      final still = prepareSvgForDisplay(adaptive, scheme: SvgColorScheme.light, inlineCss: true);
      expect(still, contains('fill="#fff"'));
      expect(still, isNot(contains('<style')));
    });

    test('loops only when asked', () {
      const animated = '<svg><animate dur="1s" repeatCount="1"/></svg>';
      expect(
        prepareSvgForDisplay(animated, scheme: SvgColorScheme.dark),
        contains('repeatCount="1"'),
      );
      expect(
        prepareSvgForDisplay(animated, scheme: SvgColorScheme.dark, loop: true),
        contains('repeatCount="indefinite"'),
      );
    });
  });

  group('buildHostHtml', () {
    test('embeds the svg and the color scheme', () {
      final html = buildHostHtml(svg: '<svg id="x"/>', scheme: SvgColorScheme.light);
      expect(html, contains('<div id="stage"><svg id="x"/></div>'));
      expect(html, contains('<meta name="color-scheme" content="light">'));
      expect(html, contains('color-scheme:light!important'));
      expect(html, contains('pointer-events:none'));
      expect(html, isNot(contains('<script>')));
    });

    test('adds the playback bridge only when requested', () {
      final html = buildHostHtml(
        svg: '<svg/>',
        scheme: SvgColorScheme.dark,
        bridge: true,
        autoplay: false,
        interactive: true,
        viewId: 'v1',
      );
      expect(html, contains('window.__sm = api'));
      expect(html, contains('var paused = true'));
      expect(html, contains("smId: 'v1'"));
      expect(html, isNot(contains('pointer-events:none')));
    });
  });

  group('SvgPlaybackController', () {
    test('computes progress within the cycle and tracks play state', () {
      final controller = SvgPlaybackController(cycle: const Duration(seconds: 2));
      expect(controller.isPlaying, isTrue);
      controller.report(seconds: 5, paused: false);
      expect(controller.progress, closeTo(0.5, 1e-9));
      controller.pause();
      expect(controller.isPlaying, isFalse);
      controller.seekFraction(0.25);
      expect(controller.seconds, 0.5);
      controller.restart();
      expect(controller.isPlaying, isTrue);
      expect(controller.progress, 0);
    });

    test('tracks the box of the selected element reported by the renderer', () {
      final controller = SvgPlaybackController(cycle: const Duration(seconds: 2));
      controller.report(seconds: 0, paused: false, box: [0.1, 0.2, 0.5, 0.6]);
      expect(controller.selectionBounds, isNull, reason: 'nothing selected, nothing to outline');

      controller.selectElement([3, 0]);
      expect(controller.selectionBounds, isNull, reason: 'waits for the renderer to answer');
      controller.report(seconds: 0, paused: false, box: [0.1, 0.2, 0.5, 0.6]);
      expect(controller.selectionBounds, const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6));

      controller.report(seconds: 0.2, paused: false); // element is hidden now
      expect(controller.selectionBounds, isNull);

      controller.report(seconds: 0.4, paused: false, box: [0, 0, 1, 1]);
      controller.selectElement(null);
      expect(controller.selectionBounds, isNull);
    });

    test('the host page can select an element and report its box', () {
      final html = buildHostHtml(svg: '<svg/>', scheme: SvgColorScheme.dark, bridge: true);
      expect(html, contains('select: function(path)'));
      expect(html, contains('b: boxOf()'));
      expect(html, contains('measure: function(cycle, steps)'));
    });

    test('measures the content through the renderer and reports null when it cannot', () async {
      final controller = SvgPlaybackController(cycle: const Duration(seconds: 2));
      expect(await controller.measureContent(), isNull, reason: 'no renderer attached');

      final target = _FakeTarget();
      controller.attach(target);
      final pending = controller.measureContent(cycle: const Duration(seconds: 2), samples: 10);
      expect(target.calls.last.$1, 'measure');
      expect(target.calls.last.$2, [2.0, 10]);
      controller.reportMeasure([1, 2, 30, 40]);
      expect(await pending, const Rect.fromLTWH(1, 2, 30, 40));

      final empty = controller.measureContent();
      controller.reportMeasure(null);
      expect(await empty, isNull, reason: 'nothing is drawn');
    });

    test('asks the renderer how far the selection must move to align', () async {
      final controller = SvgPlaybackController();
      expect(await controller.alignmentOffset(horizontal: 'start'), isNull, reason: 'no renderer');
      final target = _FakeTarget();
      controller.attach(target);
      expect(
        await controller.alignmentOffset(horizontal: 'start'),
        isNull,
        reason: 'nothing selected',
      );
      controller.selectElement([0]);
      final pending = controller.alignmentOffset(horizontal: 'center', vertical: 'end');
      expect(target.calls.last.$1, 'alignSelection');
      expect(target.calls.last.$2, ['center', 'end']);
      controller.reportMeasure([-3.5, 12, 0, 0]);
      expect(await pending, const Offset(-3.5, 12));
    });

    test('ignores the renderer report that arrives right after a seek', () {
      final controller = SvgPlaybackController(cycle: const Duration(seconds: 2));
      controller.seekFraction(0.5);
      controller.report(seconds: 0.1, paused: false);
      expect(controller.seconds, 1, reason: 'the stale time must not pull the slider back');
    });
  });

  testWidgets('SvgView renders with flutter_svg where no live renderer exists', (tester) async {
    expect(SvgView.supportsLiveRendering, isFalse, reason: 'tests run on the host VM');
    await tester.pumpWidget(
      const MaterialApp(
        home: SvgView(svg: adaptive, scheme: SvgColorScheme.dark, semanticLabel: 'Preview'),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Preview'), findsOneWidget);
  });
}

class _FakeTarget implements SvgPlaybackTarget {
  final calls = <(String, List<Object?>)>[];

  @override
  void invoke(String method, [List<Object?> arguments = const []]) =>
      calls.add((method, arguments));
}
