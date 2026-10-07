import 'package:svg_core/svg_core.dart';

/// Builds the HTML page that hosts an SVG inside a WebView or an iframe.
///
/// Inline SVG stylesheets can target the host page (`:root` matches
/// `<html>`), so the page's color scheme and transparent background are
/// marked `!important`: an SVG declaring `color-scheme: light dark` must not
/// make the host paint an opaque canvas.
///
/// With [bridge] enabled the page exposes `window.__sm` (setSvg, play, pause,
/// seek, restart, select) and reports `{t: seconds, p: paused, b: box}` every
/// 200 ms (`b` is the selected element's box as fractions of the page, or
/// null) through
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
  var sel = null;
  // Box of the selected element (child indices from the <svg>) as fractions
  // of the page, so it does not depend on pixel density.
  function boxOf(){
    if (!sel) return null;
    var el = root();
    for (var i = 0; el && i < sel.length; i++) { el = el.children[sel[i]]; }
    if (!el || !el.getBoundingClientRect) return null;
    var r = el.getBoundingClientRect();
    var w = document.documentElement.clientWidth || window.innerWidth;
    var h = document.documentElement.clientHeight || window.innerHeight;
    if (!w || !h || (r.width === 0 && r.height === 0)) return null;
    return [r.left / w, r.top / h, r.right / w, r.bottom / h];
  }
  function report(){ post({t: time(), p: paused, b: boxOf()}); }
  // Box of everything drawn right now, in the svg's user units: [x, y, w, h],
  // or null when nothing is drawn. Strokes count; filters and glows do not.
  function contentBox(){
    var s = root();
    var ctm = s && s.getScreenCTM && s.getScreenCTM();
    if (!ctm) return null;
    var inv = ctm.inverse();
    var l = Infinity, t = Infinity, r = -Infinity, b = -Infinity;
    var leaves = {rect: 1, circle: 1, ellipse: 1, line: 1, polyline: 1, polygon: 1, path: 1, text: 1, image: 1, use: 1};
    var all = s.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (!leaves[el.tagName.toLowerCase()]) continue;
      if (el.closest('defs,clipPath,mask,pattern,symbol,marker')) continue;
      var cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden') continue;
      var rc = el.getBoundingClientRect();
      if (!rc.width && !rc.height) continue;
      var pad = cs.stroke !== 'none' ? (parseFloat(cs.strokeWidth) || 0) / 2 : 0;
      var corners = [[rc.left, rc.top], [rc.right, rc.top], [rc.left, rc.bottom], [rc.right, rc.bottom]];
      for (var k = 0; k < 4; k++) {
        var p = new DOMPoint(corners[k][0], corners[k][1]).matrixTransform(inv);
        if (p.x - pad < l) l = p.x - pad;
        if (p.y - pad < t) t = p.y - pad;
        if (p.x + pad > r) r = p.x + pad;
        if (p.y + pad > b) b = p.y + pad;
      }
    }
    return l === Infinity ? null : [l, t, r - l, b - t];
  }
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
    select: function(path){ sel = path; report(); },
    // Union of contentBox() over one animation cycle, so what moves counts
    // everywhere it goes. The playback position is put back afterwards.
    measure: function(cycle, steps){
      var s = root();
      if (!s) { post({m: null}); return; }
      var was = time();
      var union = null;
      var n = cycle > 0 && steps > 0 ? steps : 0;
      for (var i = 0; i <= n; i++) {
        if (n > 0) {
          var at = cycle * i / n;
          if (s.pauseAnimations) s.pauseAnimations();
          if (s.setCurrentTime) s.setCurrentTime(at);
          anims().forEach(function(a){ try { a.pause(); a.currentTime = at * 1000; } catch (e) {} });
        }
        var box = contentBox();
        if (!box) continue;
        union = union ? [
          Math.min(union[0], box[0]),
          Math.min(union[1], box[1]),
          Math.max(union[0] + union[2], box[0] + box[2]) - Math.min(union[0], box[0]),
          Math.max(union[1] + union[3], box[1] + box[3]) - Math.min(union[1], box[1])
        ] : box;
      }
      if (n > 0) {
        if (s.setCurrentTime) s.setCurrentTime(was);
        anims().forEach(function(a){ try { a.currentTime = was * 1000; } catch (e) {} });
        applyPause();
      }
      post({m: union});
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
