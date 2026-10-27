import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../data/adhkar_service.dart';
import '../../domain/dhikr.dart';

extension AdhkarPeriodLabel on AdhkarPeriod {
  String title(BuildContext context) => switch (this) {
        AdhkarPeriod.morning => context.tr('أذكار الصباح', 'Morning adhkar'),
        AdhkarPeriod.evening => context.tr('أذكار المساء', 'Evening adhkar'),
      };
}

/// "مرة واحدة" / "3 مرات" / "Once" / "3 times".
String repetitionLabel(BuildContext context, int count) {
  if (context.isArabic) {
    if (count == 1) return 'مرة واحدة';
    if (count == 2) return 'مرتان';
    return '${ltr('$count')} ${count <= 10 ? 'مرات' : 'مرة'}';
  }
  return count == 1 ? 'Once' : '$count times';
}

/// Dhikr text: Arabic, right-to-left even in the English UI, in the
/// app's Quran face (Scheherazade New), which draws full tashkeel clearly.
class DhikrText extends StatelessWidget {
  const DhikrText(this.text,
      {super.key, this.size = 22, this.textAlign = TextAlign.start});

  final String text;
  final double size;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          textAlign: textAlign,
          style: AppTypography.quran(size: size, height: 1.9)
              .copyWith(color: context.palette.label),
        ),
      );
}

/// The source's virtue and reference under a dhikr, labelled so they read
/// as quoted from the source. Renders nothing when the source has neither.
class DhikrNotes extends StatelessWidget {
  const DhikrNotes({super.key, required this.dhikr});

  final Dhikr dhikr;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final caption = AppTypography.footnote
        .weight(FontWeight.w600)
        .copyWith(color: c.secondaryLabel);

    Widget block(String label, String body) => Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.ms),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: caption),
              const SizedBox(height: AppSpacing.xs),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  body,
                  style: AppTypography.subheadline.copyWith(color: c.label),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dhikr.virtue != null)
          block(context.tr('الفضل', 'Virtue'), dhikr.virtue!),
        if (dhikr.reference != null)
          block(context.tr('المرجع', 'Reference'), dhikr.reference!),
      ],
    );
  }
}

/// Where the text comes from. Shown under every list and in the reader.
class AdhkarSourceNote extends StatelessWidget {
  const AdhkarSourceNote({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Text(
      context.tr(
        'المصدر: islambook.com، عبر مشروع nawafalqari/ayah المفتوح المصدر. '
            'النصوص والفضائل كما وردت في المصدر، ولم يذكر المصدر تخريج الأحاديث.',
        'Source: islambook.com, via the open-source nawafalqari/ayah project. '
            'Texts and virtues are shown as published; the source does not cite hadith references.',
      ),
      textAlign: TextAlign.center,
      style: AppTypography.caption1.copyWith(color: c.tertiaryLabel),
    );
  }
}

/// Error / empty placeholder for adhkar loading.
class AdhkarErrorView extends StatelessWidget {
  const AdhkarErrorView(
      {super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure =
        error is AdhkarException ? (error as AdhkarException).failure : null;

    final (IconData icon, String title, String message) = switch (failure) {
      AdhkarFailure.offline => (
          CupertinoIcons.wifi_slash,
          context.tr('لا يوجد اتصال بالإنترنت', 'You are offline'),
          context.tr(
              'تُحمَّل الأذكار مرة واحدة، ثم تعمل دون اتصال. اتصل بالإنترنت ثم أعد المحاولة.',
              'Adhkar download once, then work offline. Connect to the internet and try again.'),
        ),
      AdhkarFailure.malformed => (
          CupertinoIcons.exclamationmark_triangle,
          context.tr('تعذّرت قراءة الأذكار', 'Could not read the adhkar'),
          context.tr(
              'وصلت البيانات من المصدر بصيغة غير صالحة. أعد المحاولة لاحقًا.',
              'The source sent data in an unexpected format. Try again later.'),
        ),
      AdhkarFailure.empty => (
          CupertinoIcons.tray,
          context.tr('لا توجد أذكار', 'No adhkar found'),
          context.tr('لم يُرجع المصدر أي ذكر. أعد المحاولة لاحقًا.',
              'The source returned no adhkar. Try again later.'),
        ),
      _ => (
          CupertinoIcons.exclamationmark_triangle,
          context.tr('تعذّر تحميل الأذكار', 'Could not load the adhkar'),
          context.tr('أعد المحاولة بعد قليل.', 'Try again in a moment.'),
        ),
    };

    return AppEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: AppButton.tinted(
        label: context.tr('إعادة المحاولة', 'Try again'),
        icon: CupertinoIcons.arrow_clockwise,
        onPressed: onRetry,
      ),
    );
  }
}

/// Round tap counter: a ring fills as repetitions are counted; the centre
/// shows how many remain, then a checkmark.
class DhikrCounterButton extends StatelessWidget {
  const DhikrCounterButton({
    super.key,
    required this.done,
    required this.total,
    required this.onTap,
    this.diameter = 128,
  });

  final int done;
  final int total;
  final VoidCallback onTap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final complete = done >= total;
    final remaining = math.max(0, total - done);

    return Semantics(
      button: true,
      label: context.tr('عدّاد الذكر', 'Dhikr counter'),
      value: context.tr('$done من $total', '$done of $total'),
      hint: complete ? null : context.tr('اضغط لعدّ مرة', 'Tap to count once'),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.square(diameter),
        pressedOpacity: 0.7,
        onPressed: complete ? null : onTap,
        child: SizedBox.square(
          dimension: diameter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : done / total),
            duration: AppMotion.of(context, AppMotion.fast),
            curve: AppMotion.curve,
            builder: (context, value, child) => CustomPaint(
              painter: _RingPainter(
                value: value,
                track: c.fill,
                fill: complete ? c.success : c.accent,
              ),
              child: child,
            ),
            child: Center(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: complete
                    ? Icon(CupertinoIcons.checkmark_alt,
                        size: diameter * 0.36, color: c.success)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LtrText(
                            '$remaining',
                            style: AppTypography.tabular(AppTypography.title1)
                                .copyWith(color: c.label),
                          ),
                          Text(
                            context.tr('متبقٍّ', 'left'),
                            style: AppTypography.caption1
                                .copyWith(color: c.secondaryLabel),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track;
  final Color fill;

  static const double _stroke = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value.clamp(0, 1), false,
          paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}

/// Light tap per repetition, a firmer one when the dhikr is complete.
void dhikrHaptic({required bool completed}) =>
    completed ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
