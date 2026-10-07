import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.dark}) => MaterialApp(
  theme: buildAppTheme(brightness: brightness),
  scrollBehavior: const AppScrollBehavior(),
  home: Scaffold(body: child),
);

void _ignore(double _) {}

void _ignoreIndex(int _) {}

void main() {
  group('buildAppTheme', () {
    test('uses the accent and exposes GalleryColors in both brightnesses', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness: brightness, accent: AccentColor.pink.color);
        expect(theme.colorScheme.primary, AccentColor.pink.color);
        expect(theme.brightness, brightness);
        expect(theme.extension<GalleryColors>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, AppPalette.of(brightness).background);
      }
    });
  });

  group('hex helpers', () {
    test('round-trip colors', () {
      expect(colorToHex(const Color(0xFF1E7BFF)), '#1E7BFF');
      expect(colorFromHex('#1e7bff'), const Color(0xFF1E7BFF));
      expect(colorFromHex('abc'), const Color(0xFFAABBCC));
      expect(colorFromHex('#12'), isNull);
    });
  });

  testWidgets('AppScrollBehavior adds a scrollbar to every scroll view', (tester) async {
    await tester.pumpWidget(
      _app(ListView(children: [for (var i = 0; i < 50; i++) Text('row $i')])),
    );
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('SliderField syncs the slider and the numeric field', (tester) async {
    var value = 50.0;
    double? committed;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => SliderField(
            label: 'Opacity',
            value: value,
            min: 0,
            max: 100,
            unit: '%',
            onChanged: (v) => setState(() => value = v),
            onChangeEnd: (v) => committed = v,
          ),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, '50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 100, reason: 'typed values are clamped to the range');
    expect(committed, 100);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 100);

    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pump();
    expect(value, 0);
    expect(committed, 0);
    expect(find.widgetWithText(TextField, '0'), findsOneWidget);
  });

  testWidgets('SliderField keeps a usable slider on narrow widths by stacking the label', (
    tester,
  ) async {
    Future<(Rect, Rect)> pumpAt(double width) async {
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const SliderField(
                label: 'Slideshow interval',
                labelWidth: 120,
                value: 5,
                min: 2,
                max: 30,
                unit: 's',
                onChanged: _ignore,
              ),
            ),
          ),
        ),
      );
      return (tester.getRect(find.text('Slideshow interval')), tester.getRect(find.byType(Slider)));
    }

    final (wideLabel, wideSlider) = await pumpAt(330);
    expect(wideSlider.width, greaterThanOrEqualTo(110));
    expect(
      wideLabel.center.dy,
      closeTo(wideSlider.center.dy, 20),
      reason: 'label beside the slider',
    );

    final (narrowLabel, narrowSlider) = await pumpAt(260);
    expect(narrowSlider.width, greaterThanOrEqualTo(110));
    expect(narrowLabel.bottom, lessThanOrEqualTo(narrowSlider.top + 1), reason: 'label above it');
  });

  testWidgets('ColorPaletteGrid wraps every color and reports the tapped one', (tester) async {
    const colors = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)];
    Color? picked;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 100, // narrower than three swatches in one row
          child: ColorPaletteGrid(
            colors: colors,
            selected: colors[1],
            size: 32,
            onSelected: (color) => picked = color,
          ),
        ),
      ),
    );
    expect(find.byType(ColorDot), findsNWidgets(3));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'only the selected one');
    final tops = {
      for (final dot in find.byType(ColorDot).evaluate())
        tester.getTopLeft(find.byWidget(dot.widget)).dy,
    };
    expect(tops.length, 2, reason: 'wrapped onto a second row');

    await tester.tap(find.byType(ColorDot).last);
    expect(picked, colors.last);
  });

  testWidgets('ScrollableChipBar reports the tapped option', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        ScrollableChipBar<String>(
          options: const [ChipOption('all', 'All'), ChipOption('fav', 'Favorites')],
          selected: 'all',
          onSelected: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.text('Favorites'));
    expect(selected, 'fav');
  });

  testWidgets('HslColorEditor accepts a typed hex color', (tester) async {
    Color? result;
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: HslColorEditor(
            color: const Color(0xFF000000),
            labels: const HslLabels(hue: 'H', saturation: 'S', lightness: 'L', hex: 'Hex'),
            onChangeEnd: (color) => result = color,
          ),
        ),
        brightness: Brightness.light,
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, '#000000'), '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(colorToHex(result!), '#FF0000');
  });

  testWidgets('an emphasized PillTab keeps its label and uses its own accent', (tester) async {
    const accent = Color(0xFF22C55E);
    await tester.pumpWidget(
      _app(
        const PillTabs(
          labelSelectedOnly: true,
          selectedIndex: 1,
          onChanged: _ignoreIndex,
          tabs: [
            PillTab('Layers', icon: Icons.layers_outlined, emphasized: true, accent: accent),
            PillTab('Transform', icon: Icons.open_with_rounded),
          ],
        ),
      ),
    );
    expect(find.text('Layers'), findsOneWidget, reason: 'label stays while not selected');
    expect(find.text('Transform'), findsOneWidget);
    final material = tester.widget<Material>(
      find.ancestor(of: find.text('Layers'), matching: find.byType(Material)).first,
    );
    expect(material.color, accent.withValues(alpha: .16));
  });
}
