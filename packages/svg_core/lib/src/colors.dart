import 'package:xml/xml.dart';

import 'css.dart';
import 'xml_support.dart';

/// Parsing and formatting of CSS/SVG color values.
class SvgColorValue {
  const SvgColorValue._();

  static const named = <String, String>{
    'black': '#000000',
    'white': '#FFFFFF',
    'red': '#FF0000',
    'green': '#008000',
    'blue': '#0000FF',
    'yellow': '#FFFF00',
    'orange': '#FFA500',
    'purple': '#800080',
    'pink': '#FFC0CB',
    'cyan': '#00FFFF',
    'aqua': '#00FFFF',
    'magenta': '#FF00FF',
    'fuchsia': '#FF00FF',
    'gray': '#808080',
    'grey': '#808080',
    'silver': '#C0C0C0',
    'maroon': '#800000',
    'olive': '#808000',
    'lime': '#00FF00',
    'teal': '#008080',
    'navy': '#000080',
    'gold': '#FFD700',
    'indigo': '#4B0082',
    'violet': '#EE82EE',
    'brown': '#A52A2A',
    'coral': '#FF7F50',
    'crimson': '#DC143C',
    'tomato': '#FF6347',
    'salmon': '#FA8072',
    'orchid': '#DA70D6',
    'plum': '#DDA0DD',
    'turquoise': '#40E0D0',
    'skyblue': '#87CEEB',
    'steelblue': '#4682B4',
    'royalblue': '#4169E1',
    'dodgerblue': '#1E90FF',
    'deepskyblue': '#00BFFF',
    'hotpink': '#FF69B4',
    'deeppink': '#FF1493',
    'darkblue': '#00008B',
    'darkgreen': '#006400',
    'darkred': '#8B0000',
    'darkgray': '#A9A9A9',
    'darkgrey': '#A9A9A9',
    'lightgray': '#D3D3D3',
    'lightgrey': '#D3D3D3',
    'lightblue': '#ADD8E6',
    'lightgreen': '#90EE90',
    'whitesmoke': '#F5F5F5',
    'beige': '#F5F5DC',
    'khaki': '#F0E68C',
    'lavender': '#E6E6FA',
    'tan': '#D2B48C',
    'chocolate': '#D2691E',
    'seagreen': '#2E8B57',
    'slategray': '#708090',
    'slateblue': '#6A5ACD',
    'midnightblue': '#191970',
    'rebeccapurple': '#663399',
  };

  /// `#RRGGBB` (uppercase) for a hex, `rgb()`/`rgba()` or named color;
  /// null for anything else (`none`, `url(...)`, `currentColor`...).
  static String? normalize(String token) {
    final value = token.trim().toLowerCase();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return null;
      return switch (hex.length) {
        3 || 4 => '#${hex[0] * 2}${hex[1] * 2}${hex[2] * 2}'.toUpperCase(),
        6 || 8 => '#${hex.substring(0, 6)}'.toUpperCase(),
        _ => null,
      };
    }
    final rgb = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(value);
    if (rgb != null) {
      final parts = rgb.group(1)!.split(RegExp(r'[\s,/]+')).where((p) => p.isNotEmpty).toList();
      if (parts.length < 3) return null;
      final channels = <int>[];
      for (final part in parts.take(3)) {
        final number = double.tryParse(part.replaceAll('%', ''));
        if (number == null) return null;
        final channel = part.endsWith('%') ? number * 2.55 : number;
        channels.add(channel.round().clamp(0, 255));
      }
      return '#${channels.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}'.toUpperCase();
    }
    return named[value];
  }

  static final _token = RegExp(
    r'url\([^)]*\)|var\([^)]*\)|#[0-9a-fA-F]{3,8}(?![\w-])|rgba?\([^)]*\)|(?<![\w#.-])[a-zA-Z]+(?![\w(-])',
  );

  /// Calls [replace] for every color inside [value] (a paint value, a SMIL
  /// `values` list or a CSS declaration value) and splices the result back.
  /// [replace] receives the raw token and its normalized form.
  static String mapColors(String value, String Function(String token, String normalized) replace) =>
      value.replaceAllMapped(_token, (match) {
        final token = match.group(0)!;
        if (token.startsWith('url(') || token.startsWith('var(')) return token;
        final normalized = normalize(token);
        return normalized == null ? token : replace(token, normalized);
      });

  /// Rewrites [token] with the RGB of [hex], keeping the token's alpha.
  static String recolor(String token, String hex) {
    final lower = token.trim().toLowerCase();
    if (lower.startsWith('#') && (lower.length == 5 || lower.length == 9)) {
      final alpha = lower.length == 5 ? lower[4] * 2 : lower.substring(7);
      return '$hex${alpha.toUpperCase()}';
    }
    final rgba = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(lower);
    if (rgba != null) {
      final parts = rgba.group(1)!.split(RegExp(r'[\s,/]+')).where((p) => p.isNotEmpty).toList();
      if (parts.length == 4) {
        final value = int.parse(hex.substring(1), radix: 16);
        return 'rgba(${value >> 16 & 255}, ${value >> 8 & 255}, ${value & 255}, ${parts[3]})';
      }
    }
    return hex;
  }
}

const _paintAttributes = {'fill', 'stroke', 'stop-color', 'flood-color', 'lighting-color', 'color'};
const _cssColorProperties = {
  ..._paintAttributes,
  'background',
  'background-color',
  'border-color',
  'outline-color',
};
const _smilValueAttributes = {'values', 'from', 'to', 'by'};

/// Document-wide color operations (the editor's "Colors" tab).
class SvgColors {
  const SvgColors._();

  /// Distinct colors used by the document, in order of first appearance.
  static List<String> palette(String svg) {
    final colors = <String>{};
    _rewrite(svg, (token, normalized) {
      colors.add(normalized);
      return token;
    });
    return colors.toList();
  }

  /// Replaces every occurrence of color [from] (any notation) with [to].
  static String replace(String svg, String from, String to) {
    final source = SvgColorValue.normalize(from);
    final target = SvgColorValue.normalize(to);
    if (source == null || target == null || source == target) return svg;
    return _rewrite(
      svg,
      (token, normalized) => normalized == source ? SvgColorValue.recolor(token, target) : token,
    );
  }

  static String _rewrite(String svg, String Function(String token, String normalized) replace) {
    final document = tryParseSvg(svg);
    if (document == null) return svg;
    final root = document.rootElement;
    String mapCss(String property, String value) =>
        _cssColorProperties.contains(property) ? SvgColorValue.mapColors(value, replace) : value;

    for (final element in [root, ...root.descendantElements]) {
      final animatesColor = _paintAttributes.contains(element.getAttribute('attributeName'));
      for (final attribute in element.attributes) {
        final name = attribute.localName;
        if (_paintAttributes.contains(name) ||
            (animatesColor && _smilValueAttributes.contains(name))) {
          attribute.value = SvgColorValue.mapColors(attribute.value, replace);
        } else if (name == 'style') {
          attribute.value = mapDeclarations(attribute.value, mapCss);
        }
      }
      if (element.localName == 'style') {
        setStyleText(element, mapStylesheetDeclarations(styleText(element), mapCss));
      }
    }
    return document.toXmlString();
  }
}
