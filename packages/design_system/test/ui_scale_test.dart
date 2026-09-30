import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _probe = Key('probe');

Future<void> _pump(WidgetTester tester, double scale, {Widget? child, VoidCallback? onTap}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3; // 390 × 844 logical
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, home) => UiScale(scale: scale, child: home!),
      home: Scaffold(
        body:
            child ??
            GestureDetector(
              key: _probe,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox.expand(),
            ),
      ),
    ),
  );
}

void main() {
  testWidgets('lays the child out on the virtual screen and draws it scaled into the real one', (
    tester,
  ) async {
    await _pump(tester, 0.7);

    final laidOut = tester.renderObject<RenderBox>(find.byKey(_probe)).size;
    expect(laidOut.width, closeTo(390 / 0.7, 0.01));
    expect(laidOut.height, closeTo(844 / 0.7, 0.01));

    final drawn = tester.getRect(find.byKey(_probe));
    expect(drawn.left, closeTo(0, 0.01));
    expect(drawn.top, closeTo(0, 0.01));
    expect(drawn.width, closeTo(390, 0.01));
    expect(drawn.height, closeTo(844, 0.01));
  });

  testWidgets('gives MediaQuery the virtual size and insets', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 90, bottom: 60); // 30 and 20 logical
    addTearDown(tester.view.resetPadding);
    late MediaQueryData seen;
    await _pump(
      tester,
      0.5,
      child: Builder(
        builder: (context) {
          seen = MediaQuery.of(context);
          return const SizedBox.expand();
        },
      ),
    );

    expect(seen.size, const Size(780, 1688));
    expect(seen.padding.top, closeTo(60, 0.01));
    expect(seen.padding.bottom, closeTo(40, 0.01));
  });

  testWidgets('touches reach the widget under the finger', (tester) async {
    var taps = 0;
    await _pump(tester, 0.7, onTap: () => taps++);

    await tester.tapAt(const Offset(389, 843)); // the very corner of the real screen
    expect(taps, 1);
  });

  testWidgets('scale 1 is the identity', (tester) async {
    await _pump(tester, 1);

    expect(tester.renderObject<RenderBox>(find.byKey(_probe)).size, const Size(390, 844));
    expect(tester.getRect(find.byKey(_probe)), const Rect.fromLTWH(0, 0, 390, 844));
  });

  testWidgets('keeps the navigator state when the scale changes', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final scale = ValueNotifier<double>(0.7);
    addTearDown(scale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: scale,
        builder: (context, value, _) => MaterialApp(
          builder: (context, home) => UiScale(scale: value, child: home!),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second page'))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsOneWidget);

    scale.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsOneWidget);
    scale.value = 0.5;
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsOneWidget);
  });
}
