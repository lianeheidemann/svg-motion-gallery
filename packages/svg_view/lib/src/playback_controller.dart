import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// Implemented by renderers that can execute playback commands.
abstract interface class SvgPlaybackTarget {
  void invoke(String method, [List<Object?> arguments]);
}

/// Controls and observes the animation of an interactive `SvgView`.
///
/// Renderers without scripting (the static fallback) never attach, so
/// [isAttached] stays false and commands are ignored.
class SvgPlaybackController extends ChangeNotifier {
  SvgPlaybackController({this.cycle, bool autoplay = true}) : _playing = autoplay;

  /// Length of one animation cycle (from `SvgMetadata.cycleDuration`).
  Duration? cycle;

  SvgPlaybackTarget? _target;
  bool _playing;
  double _seconds = 0;

  /// Time since the last report or command; the renderer reports only every
  /// 200 ms, so the UI extrapolates from it to move smoothly in between.
  final _sinceReport = Stopwatch()..start();

  /// The renderer's next report after a seek may still carry the time from
  /// before it; reports in this window are ignored so a slider being dragged
  /// is not pulled back by them.
  static const _seekSettle = Duration(milliseconds: 400);
  final _sinceSeek = Stopwatch();

  List<int>? _selection;
  Rect? _selectionBounds;

  /// Where the selected element is drawn, as fractions (0..1) of the rendered
  /// view, or null when nothing is selected or the renderer cannot tell
  /// (renderers without scripting never report it).
  Rect? get selectionBounds => _selectionBounds;

  /// Asks the renderer to track the element at [indices] (child indices from
  /// the `<svg>` root); null clears it.
  void selectElement(List<int>? indices) {
    if (listEquals(indices, _selection)) return;
    _selection = indices == null ? null : List.unmodifiable(indices);
    _selectionBounds = null;
    _target?.invoke('select', [_selection]);
    notifyListeners();
  }

  Completer<Rect?>? _measuring;

  /// Measures what is drawn, in the svg's own units ([Rect] of x, y, width,
  /// height), or null when nothing is drawn or the renderer cannot measure
  /// (no scripting). With a [cycle], every animation is stepped through that
  /// length of time in [samples] steps and the boxes are joined, so what
  /// moves counts everywhere it goes. The playback position is kept.
  Future<Rect?> measureContent({Duration? cycle, int samples = 24}) {
    final target = _target;
    if (target == null) return Future.value();
    _measuring?.complete();
    final done = _measuring = Completer<Rect?>();
    final seconds = cycle == null ? 0 : cycle.inMicroseconds / Duration.microsecondsPerSecond;
    target.invoke('measure', [seconds, samples]);
    return done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        if (identical(_measuring, done)) _measuring = null;
        return null;
      },
    );
  }

  /// Called by renderers with the answer to [measureContent].
  @internal
  void reportMeasure(List<double>? box) {
    final pending = _measuring;
    _measuring = null;
    final valid = box != null && box.length == 4;
    pending?.complete(valid ? Rect.fromLTWH(box[0], box[1], box[2], box[3]) : null);
  }

  bool get isAttached => _target != null;
  bool get isPlaying => _playing;

  /// Seconds reported by the document timeline.
  double get seconds => _seconds;

  /// Position inside the current cycle, 0..1.
  double get progress {
    final length = cycle == null ? 0 : cycle!.inMicroseconds / Duration.microsecondsPerSecond;
    if (length <= 0) return 0;
    return (_seconds % length) / length;
  }

  /// Like [progress] but advanced by the time elapsed since the last report
  /// while playing, so a slider driven by it glides instead of stepping.
  /// Wraps around at the end of the cycle.
  double get smoothProgress {
    final length = cycle == null ? 0 : cycle!.inMicroseconds / Duration.microsecondsPerSecond;
    if (length <= 0) return 0;
    final extra = _playing && isAttached ? _sinceReport.elapsedMicroseconds / 1e6 : 0;
    return ((_seconds + extra) % length) / length;
  }

  void play() {
    _playing = true;
    _target?.invoke('play');
    notifyListeners();
  }

  void pause() {
    _playing = false;
    _target?.invoke('pause');
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  /// Jumps to [fraction] (0..1) of the cycle.
  void seekFraction(double fraction) {
    final length = cycle == null ? 0 : cycle!.inMicroseconds / Duration.microsecondsPerSecond;
    final seconds = fraction.clamp(0, 1) * length;
    _seconds = seconds.toDouble();
    _sinceReport.reset();
    _sinceSeek
      ..reset()
      ..start();
    _target?.invoke('seek', [seconds]);
    notifyListeners();
  }

  void restart() {
    _playing = true;
    _seconds = 0;
    _sinceReport.reset();
    _target?.invoke('restart');
    notifyListeners();
  }

  /// Called by renderers.
  @internal
  void attach(SvgPlaybackTarget target) {
    _target = target;
    target.invoke(_playing ? 'play' : 'pause');
    if (_selection != null) target.invoke('select', [_selection]);
  }

  @internal
  void detach(SvgPlaybackTarget target) {
    if (identical(_target, target)) _target = null;
  }

  /// Called by renderers with the timeline state.
  @internal
  void report({required double seconds, required bool paused, List<double>? box}) {
    final settling = _sinceSeek.isRunning && _sinceSeek.elapsed < _seekSettle;
    final next = settling ? _seconds : seconds;
    final bounds = _selection == null || box == null || box.length != 4
        ? null
        : Rect.fromLTRB(box[0], box[1], box[2], box[3]);
    final boundsChanged = bounds != _selectionBounds;
    _selectionBounds = bounds;
    final changed = (next - _seconds).abs() > 0.001 || paused == _playing || boundsChanged;
    _seconds = next;
    if (!settling) _sinceReport.reset();
    _playing = !paused;
    if (changed) notifyListeners();
  }
}
