import 'package:svg_core/svg_core.dart';

/// Builds the HTML page that hosts an SVG inside a WebView or an iframe.
///
/// Inline SVG stylesheets can target the host page (`:root` matches
/// `<html>`), so the page's color scheme and transparent background are
/// marked `!important`: an SVG declaring `color-scheme: light dark` must not
/// make the host paint an opaque canvas.
///
/// With [bridge] enabled the page exposes `window.__sm` (setSvg, play, pause,
/// seek, restart) and reports `{t: seconds, p: paused}` every 200 ms through
/// the `SmBridge` JavaScript channel (mobile) or `postMessage` (web, tagged
/// with [viewId]).
String buildHostHtml({
  required String svg,
  required SvgColorScheme scheme,
  bool bridge = false,
  bool autoplay = true,
  bool interactive = false,
  String viewId = '',
}) {
  final script = bridge
      ? '<script>${_bridgeScript(autoplay: autoplay, viewId: viewId)}</script>'
      : '';
  final pausedCss = !bridge && !autoplay ? '*{animation-play-state:paused!important}' : '';
  return '''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<meta name="color-scheme" content="${scheme.name}">
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent!important;color-scheme:${scheme.name}!important}
body{-webkit-tap-highlight-color:transparent;-webkit-user-select:none;user-select:none${interactive ? '' : ';pointer-events:none'}}
#stage{width:100%;height:100%;display:flex;align-items:center;justify-content:center}
#stage>svg{width:100%;height:100%;display:block}
$pausedCss
</style></head>
<body><div id="stage">$svg</div>$script</body></html>''';
}

String _bridgeScript({required bool autoplay, required String viewId}) =>
    '''
(function(){
  var paused = ${autoplay ? 'false' : 'true'};
  function root(){ return document.querySelector('#stage>svg'); }
  function anims(){ return document.getAnimations ? document.getAnimations() : []; }
  function post(message){
    try {
      if (window.SmBridge) { SmBridge.postMessage(JSON.stringify(message)); }
      else if (window.parent !== window) { window.parent.postMessage({smId: '$viewId', sm: message}, '*'); }
    } catch (e) {}
  }
  function time(){
    var s = root();
    if (s && s.getCurrentTime) { var t = s.getCurrentTime(); if (t > 0) return t; }
    var a = anims()[0];
    return a && a.currentTime ? a.currentTime / 1000 : 0;
  }
  function report(){ post({t: time(), p: paused}); }
  function applyPause(){
    var s = root();
    if (s && s.pauseAnimations) { paused ? s.pauseAnimations() : s.unpauseAnimations(); }
    anims().forEach(function(a){ try { paused ? a.pause() : a.play(); } catch (e) {} });
  }
  var api = {
    setSvg: function(markup){ document.getElementById('stage').innerHTML = markup; applyPause(); report(); },
    play: function(){ paused = false; applyPause(); report(); },
    pause: function(){ paused = true; applyPause(); report(); },
    seek: function(t){
      var s = root();
      if (s && s.setCurrentTime) s.setCurrentTime(t);
      anims().forEach(function(a){ try { a.currentTime = t * 1000; } catch (e) {} });
      report();
    },
    restart: function(){ api.seek(0); api.play(); }
  };
  window.__sm = api;
  window.addEventListener('message', function(e){
    var d = e.data;
    if (d && d.smCall && api[d.smCall]) api[d.smCall].apply(null, d.args || []);
  });
  applyPause();
  window.addEventListener('load', applyPause);
  setInterval(report, 200);
})();
''';
