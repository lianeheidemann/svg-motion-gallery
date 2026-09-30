import 'package:xml/xml.dart';

import 'xml_support.dart';

const _blockedElements = {'script', 'iframe', 'object', 'embed'};

/// Removes active content before an SVG is rendered in a WebView: scripts,
/// embedded browsing contexts, `on*` event handlers and `javascript:` links.
/// Drawing and CSS/SMIL animation are left untouched.
String sanitizeSvg(String content) {
  final document = tryParseXml(content);
  if (document == null) {
    return content
        .replaceAll(RegExp(r'<script[\s\S]*?(</script\s*>|$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'''\son\w+\s*=\s*("[^"]*"|'[^']*')''', caseSensitive: false), '');
  }
  final root = document.rootElement;
  for (final element in root.descendantElements.toList()) {
    if (_blockedElements.contains(element.localName.toLowerCase())) {
      element.remove();
    }
  }
  for (final element in [root, ...root.descendantElements]) {
    element.attributes.removeWhere((attribute) {
      final name = attribute.localName.toLowerCase();
      if (name.startsWith('on')) return true;
      final value = attribute.value.replaceAll(RegExp(r'\s'), '').toLowerCase();
      return (name == 'href' || name == 'src') && value.startsWith('javascript:');
    });
  }
  return document.toXmlString();
}
