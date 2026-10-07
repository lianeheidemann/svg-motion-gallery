import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../host_html.dart';
import '../playback_controller.dart';
import 'live_svg_config.dart';

/// Android and iOS render through the system WebView (full CSS/SMIL).
bool get platformSupportsLiveSvg => Platform.isAndroid || Platform.isIOS;

Widget buildLiveSvg(LiveSvgConfig config) => _WebViewSvg(config: config);

class _WebViewSvg extends StatefulWidget {
  const _WebViewSvg({required this.config});

  final LiveSvgConfig config;

  @override
  State<_WebViewSvg> createState() => _WebViewSvgState();
}

class _WebViewSvgState extends State<_WebViewSvg> implements SvgPlaybackTarget {
  final _web = WebViewController();
  var _loaded = false;

  LiveSvgConfig get _config => widget.config;
  bool get _bridge => _config.controller != null;

  @override
  void initState() {
    super.initState();
    unawaited(_configure());
  }

  Future<void> _configure() async {
    await _web.setJavaScriptMode(_bridge ? JavaScriptMode.unrestricted : JavaScriptMode.disabled);
    await _web.setBackgroundColor(const Color(0x00000000));
    await _web.setNavigationDelegate(
      NavigationDelegate(
        // The hosted page never navigates: block links inside SVGs.
        onNavigationRequest: (request) =>
            request.url.startsWith('about:') || request.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (_) {
          _loaded = true;
          _config.controller?.attach(this);
        },
      ),
    );
    if (_bridge) {
      await _web.addJavaScriptChannel('SmBridge', onMessageReceived: _onMessage);
    }
    await _load();
  }

  Future<void> _load() {
    _loaded = false;
    return _web.loadHtmlString(
      buildHostHtml(
        svg: _config.svg,
        scheme: _config.scheme,
        bridge: _bridge,
        autoplay: _config.controller?.isPlaying ?? _config.autoplay,
        interactive: _config.interactive,
      ),
    );
  }

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message);
    if (data is! Map) return;
    if (data.containsKey('m')) {
      final box = data['m'];
      _config.controller?.reportMeasure(
        box is List
            ? [
                for (final v in box)
                  if (v is num) v.toDouble(),
              ]
            : null,
      );
      return;
    }
    final seconds = data['t'];
    final paused = data['p'];
    if (seconds is num && paused is bool) {
      final box = data['b'];
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

  @override
  void invoke(String method, [List<Object?> arguments = const []]) {
    if (!_loaded) return;
    final args = arguments.map(jsonEncode).join(',');
    unawaited(_web.runJavaScript('window.__sm&&__sm.$method($args)'));
  }

  @override
  void didUpdateWidget(covariant _WebViewSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.config;
    if (old.controller != _config.controller) {
      old.controller?.detach(this);
      if (_loaded) _config.controller?.attach(this);
    }
    if (old.scheme != _config.scheme ||
        old.interactive != _config.interactive ||
        (old.controller == null) != (_config.controller == null)) {
      unawaited(_configure());
    } else if (old.svg != _config.svg) {
      if (_bridge && _loaded) {
        invoke('setSvg', [_config.svg]);
      } else {
        unawaited(_load());
      }
    }
  }

  @override
  void dispose() {
    _config.controller?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_config.interactive,
    child: WebViewWidget(controller: _web),
  );
}
