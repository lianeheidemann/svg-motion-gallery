import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int selected = 0,
    ValueChanged<int>? onSelect,
    void Function(int, double)? onMove,
    VoidCallback? onMoveEnd,
    ValueChanged<double>? onAdd,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: GradientBar(
              colors: const [Colors.red, Colors.blue],
              offsets: const [0, 1],
              selected: selected,
              onSelect: onSelect ?? (_) {},
              onMove: onMove ?? (_, _) {},
              onMoveEnd: onMoveEnd ?? () {},
              onAdd: onAdd ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('tapping either end handle selects it, even the half past the strip', (tester) async {
    final picked = <int>[];
    await pump(tester, onSelect: picked.add);
    await tester.tap(find.byKey(const Key('gradient-stop-1')));
    await tester.tap(find.byKey(const Key('gradient-stop-0')));
    expect(picked, [1, 0]);
  });

  testWidgets('tapping an empty spot adds a stop at that position', (tester) async {
    double? added;
    await pump(tester, onAdd: (offset) => added = offset);
    final bar = tester.getRect(find.byKey(const Key('gradient-bar')));
    await tester.tapAt(Offset(bar.center.dx, bar.center.dy));
    expect(added, closeTo(.5, .01));
  });

  testWidgets('dragging a handle reports its new position and the end of the drag', (tester) async {
    final moves = <(int, double)>[];
    var ended = 0;
    await pump(tester, onMove: (i, o) => moves.add((i, o)), onMoveEnd: () => ended++);
    final handle = tester.getCenter(find.byKey(const Key('gradient-stop-0')));
    await tester.dragFrom(handle, const Offset(137, 0));
    expect(moves.last.$1, 0);
    expect(moves.last.$2, closeTo(.5, .02));
    expect(ended, 1);
  });
}
