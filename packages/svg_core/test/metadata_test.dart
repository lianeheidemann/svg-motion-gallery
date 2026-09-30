import 'package:svg_core/svg_core.dart';
import 'package:test/test.dart';

void main() {
  test('reads size, viewBox and drawable element count', () {
    final metadata = SvgMetadata.parse(
      '<svg width="800px" height="600" viewBox="0 0 400 300">'
      '<defs><linearGradient id="g"><stop/></linearGradient></defs>'
      '<g><rect/><circle/></g></svg>',
    );
    expect(metadata.width, 800);
    expect(metadata.height, 600);
    expect(metadata.viewBox!.width, 400);
    expect(metadata.elementCount, 3);
    expect(metadata.isAnimated, isFalse);
  });

  test('falls back to the viewBox for display size', () {
    final metadata = SvgMetadata.parse('<svg width="100%" viewBox="0 0 24 24"/>');
    expect(metadata.displayWidth, 24);
    expect(metadata.displayHeight, 24);
  });

  test('detects SMIL animation and its longest cycle', () {
    final metadata = SvgMetadata.parse(
      '<svg><circle><animate dur="2s"/></circle><rect><animate dur="3500ms"/></rect></svg>',
    );
    expect(metadata.animationKinds, {SvgAnimationKind.smil});
    expect(metadata.cycleDuration, const Duration(milliseconds: 3500));
  });

  test('detects CSS animation in stylesheets and style attributes', () {
    final metadata = SvgMetadata.parse(
      '<svg><style>.a{animation: spin 4s linear infinite}</style>'
      '<rect style="animation-duration: 6s; animation-name: x"/></svg>',
    );
    expect(metadata.animationKinds, {SvgAnimationKind.css});
    expect(metadata.cycleDuration, const Duration(seconds: 6));
  });

  test('invalid documents yield empty metadata', () {
    expect(SvgMetadata.parse('<svg>').elementCount, 0);
  });
}
