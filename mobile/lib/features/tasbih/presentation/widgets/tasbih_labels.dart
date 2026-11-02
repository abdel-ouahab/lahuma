import 'package:intl/intl.dart' show NumberFormat;
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern('en');

/// 1,240 — Latin digits with grouping, as elsewhere in the app.
String formatCount(int n) => _grouped.format(n);

/// "1,240 تسبيحة اليوم" / "1,240 today".
String tasbihatToday(BuildContext context, int n) {
  if (!context.isArabic) {
    return n == 0 ? 'Nothing counted today' : '${formatCount(n)} today';
  }
  if (n == 0) return 'لم تُسبّح اليوم بعد';
  if (n == 1) return 'تسبيحة واحدة اليوم';
  if (n == 2) return 'تسبيحتان اليوم';
  final r = n % 100;
  final noun = r >= 3 && r <= 10 ? 'تسبيحات' : 'تسبيحة';
  return '${ltr(formatCount(n))} $noun اليوم';
}

/// "الهدف 33" / "بلا حدّ".
String targetLabel(BuildContext context, int? target) => target == null
    ? context.tr('بلا حدّ', 'No limit')
    : context.tr('الهدف ${ltr(formatCount(target))}',
        'Target ${formatCount(target)}');

extension BeadMaterialLabel on BeadMaterial {
  String label(BuildContext context) => switch (this) {
        BeadMaterial.amber => context.tr('كهرمان', 'Amber'),
        BeadMaterial.wood => context.tr('خشب', 'Wood'),
        BeadMaterial.pearl => context.tr('لؤلؤ', 'Pearl'),
      };
}

/// Dhikr text in the app's Quran face, right-to-left in either language.
class TasbihDhikrText extends StatelessWidget {
  const TasbihDhikrText(
    this.text, {
    super.key,
    this.size = 22,
    this.maxLines,
    this.color,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double size;
  final int? maxLines;
  final Color? color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: AppTypography.quran(size: size, height: 1.5)
              .copyWith(color: color ?? context.palette.label),
        ),
      );
}
