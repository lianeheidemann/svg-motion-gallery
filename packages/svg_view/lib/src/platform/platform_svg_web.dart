import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../host_html.dart';
import '../playback_controller.dart';
import 'live_svg_config.dart';

/// Browsers render SVG natively inside a sandboxed `<iframe srcdoc>`.
bool get platformSupportsLiveSvg => true;

Widget buildLiveSvg(LiveSvgConfig config) => _IframeSvg(config: config);

class _IframeSvg extends StatefulWidget {
  const _IframeSvg({required this.config});

  final LiveSvgConfig config;

  @override
  State<_IframeSvg> createState() => _IframeSvgState();
}

class _IframeSvgState extends State<_IframeSvg> implements SvgPlaybackTarget {
  static var _nextId = 0;

  final _id = 'sm${_nextId++}';
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;
  var _loaded = false;

  LiveSvgConfig get _config => widget.config;
  bool get _bridge => _config.controller != null;

  @override
  void initState() {
    super.initState();
    _listener = _onMessage.toJS;
    web.window.addEventListener('message', _listener);
  }

  void _onMessage(web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is! Map || data['smId'] != _id) return;
    final message = data['sm'];
    if (message is! Map) return;
    final seconds = message['t'];
    final paused = message['p'];
    if (seconds is num && paused is bool) {
      final box = message['b'];
      _config.controller?.report(
        seconds: seconds.toDouble(),
        paused: paused,
        box: box is List
            ? [
                for (final v in box)
                  if (v is num) v.toDouble(),
              ]
            : null,
      );
    }
  }

  void _load() {
    final frame = _frame;
    if (frame == null) return;
    _loaded = false;
    frame
      ..setAttribute('sandbox', _bridge ? 'allow-scripts' : '')
      ..srcdoc = buildHostHtml(
        svg: _config.svg,
        scheme: _config.scheme,
        bridge: _bridge,
        autoplay: _config.controller?.isPlaying ?? _config.autoplay,
        interactive: _config.interactive,
        viewId: _id,
      ).toJS;
    frame.style
      ..colorScheme = _config.scheme.name
      ..pointerEvents = _config.interactive ? 'auto' : 'none';
  }

  void _onCreated(Object element) {
    final frame = element as web.HTMLIFrameElement;
    frame.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = 'transparent';
    frame.onload = ((web.Event _) {
      _loaded = true;
      _config.controller?.attach(this);
    }).toJS;
    _frame = frame;
    _load();
  }

  @override
  void invoke(String method, [List<Object?> arguments = const []]) {
    if (!_loaded) return;
    _frame?.contentWindow?.postMessage({'smCall': method, 'args': arguments}.jsify(), '*'.toJS);
  }

  @override
  void didUpdateWidget(covariant _IframeSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.config;
    if (old.controller != _config.controller) {
      old.controller?.detach(this);
      if (_loaded) _config.controller?.attach(this);
    }
    if (old.scheme != _config.scheme ||
        old.interactive != _config.interactive ||
        (old.controller == null) != (_config.controller == null)) {
      _load();
    } else if (old.svg != _config.svg) {
      if (_bridge && _loaded) {
        invoke('setSvg', [_config.svg]);
      } else {
        _load();
      }
    }
  }

  @override
  void dispose() {
    _config.controller?.detach(this);
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_config.interactive,
    child: HtmlElementView.fromTagName(tagName: 'iframe', onElementCreated: _onCreated),
  );
}
