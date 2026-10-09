import 'package:xml/xml.dart';

import 'xml_support.dart';

/// Makes every animation repeat forever: SMIL elements get
/// `repeatCount="indefinite"` and CSS animations an infinite iteration count.
/// Used at render time for the "repeat animation" setting; never saved.
String forceLoop(String content) {
  final document = tryParseXml(content);
  if (document == null) return content;
  final root = document.rootElement;
  var changed = false;
  for (final element in root.descendantElements) {
    if (smilTags.contains(element.localName) && element.localName != 'set') {
      element
        ..setAttribute('repeatCount', 'indefinite')
        ..removeAttribute('repeatDur');
      changed = true;
    }
  }
  final hasCss = [root, ...root.descendantElements].any(
    (element) =>
        (element.localName == 'style' && styleText(element).contains('animation')) ||
        (element.getAttribute('style')?.contains('animation') ?? false),
  );
  if (hasCss) {
    root.children.add(
      buildElement(
        'style',
        attributes: {'data-sm-loop': ''},
        children: [XmlText('*{animation-iteration-count:infinite !important}')],
      ),
    );
    changed = true;
  }
  return changed ? document.toXmlString() : content;
}

/// Makes every animation play a single time and stay on its last frame: SMIL
/// elements get `repeatCount="1"` and `fill="freeze"`, CSS animations one
/// iteration that keeps the final state. Used at render time when "repeat
/// animation" is off; never saved.
String forcePlayOnce(String content) {
  final document = tryParseXml(content);
  if (document == null) return content;
  final root = document.rootElement;
  var changed = false;
  for (final element in root.descendantElements) {
    if (smilTags.contains(element.localName) && element.localName != 'set') {
      element
        ..setAttribute('repeatCount', '1')
        ..setAttribute('fill', 'freeze')
        ..removeAttribute('repeatDur');
      changed = true;
    }
  }
  final hasCss = [root, ...root.descendantElements].any(
    (element) =>
        (element.localName == 'style' && styleText(element).contains('animation')) ||
        (element.getAttribute('style')?.contains('animation') ?? false),
  );
  if (hasCss) {
    root.children.add(
      buildElement(
        'style',
        attributes: {'data-sm-loop': 'once'},
        children: [
          XmlText(
            '*{animation-iteration-count:1 !important;animation-fill-mode:forwards !important}',
          ),
        ],
      ),
    );
    changed = true;
  }
  return changed ? document.toXmlString() : content;
}
