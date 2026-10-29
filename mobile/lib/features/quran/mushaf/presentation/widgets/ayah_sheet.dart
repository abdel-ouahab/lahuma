import 'package:flutter/services.dart';
import '../../../../../core/design/design.dart';
import '../../../../../core/localization/tr.dart';
import '../../domain/mushaf_meta.dart';

/// Bottom sheet for a long-pressed ayah: its reference, its text and a copy
/// action. [context] is the Mushaf screen's, used for the toast after closing.
Future<void> showAyahSheet(
  BuildContext context, {
  required int surah,
  required int ayah,
}) {
  final name = MushafMeta.surahName(surah);
  final text = MushafMeta.ayahText(surah, ayah);
  return showAppBottomSheet<void>(
    context,
    title: context.tr('سورة $name · الآية $ayah',
        '${MushafMeta.surahNameLatin(surah)} · Ayah $ayah'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.xs,
          AppSpacing.screenMargin, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTypography.quran(size: 24)
                .copyWith(color: ctx.palette.label),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.tinted(
            label: ctx.tr('نسخ نص الآية', 'Copy ayah text'),
            icon: CupertinoIcons.doc_on_doc,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: '$text ﴿$ayah﴾\n[سورة $name: $ayah]'));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                AppToast.show(
                    context, context.tr('تم نسخ الآية', 'Ayah copied'),
                    icon: CupertinoIcons.checkmark_circle_fill);
              }
            },
          ),
        ],
      ),
    ),
  );
}
