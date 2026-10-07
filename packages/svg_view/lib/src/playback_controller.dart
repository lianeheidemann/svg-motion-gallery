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
  }

  @internal
  void detach(SvgPlaybackTarget target) {
    if (identical(_target, target)) _target = null;
  }

  /// Called by renderers with the timeline state.
  @internal
  void report({required double seconds, required bool paused}) {
    final settling = _sinceSeek.isRunning && _sinceSeek.elapsed < _seekSettle;
    final next = settling ? _seconds : seconds;
    final changed = (next - _seconds).abs() > 0.001 || paused == _playing;
    _seconds = next;
    if (!settling) _sinceReport.reset();
    _playing = !paused;
    if (changed) notifyListeners();
  }
}
