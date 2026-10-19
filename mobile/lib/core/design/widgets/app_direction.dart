import 'package:flutter/cupertino.dart';

/// RTL helpers.
///
/// Most `CupertinoIcons` glyphs (including `chevron_forward` / `chevron_back`)
/// do not mirror on their own. Use [AppDirectionalIcon] for anything that
/// points "forward" or "back"; leave non-directional glyphs (clock, search,
/// checkmark, play) as plain [Icon]s.
class AppDirectionalIcon extends StatelessWidget {
  const AppDirectionalIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final glyph =
        Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    // An icon that already mirrors itself must not be flipped twice.
    return rtl && !icon.matchTextDirection
        ? Transform.flip(flipX: true, child: glyph)
        : glyph;
  }
}

/// Keeps numbers, phone numbers, e-mails and Latin names left-to-right inside
/// Arabic text, so "٣ / 10" or "user@mail.com" never render out of order.
class LtrText extends StatelessWidget {
  const LtrText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          data,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
}

/// Wraps [value] in Unicode left-to-right isolates (U+2066 … U+2069) for use
/// inside a larger, possibly Arabic, string: `'${ltr('12 / 20')} آية'`.
String ltr(String value) => '$_lri$value$_pdi';

const String _lri = '\u{2066}'; // LEFT-TO-RIGHT ISOLATE
const String _pdi = '\u{2069}'; // POP DIRECTIONAL ISOLATE
