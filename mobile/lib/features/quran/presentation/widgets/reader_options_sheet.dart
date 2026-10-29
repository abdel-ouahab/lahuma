import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/presentation/settings_providers.dart';

/// Reading options: text size, translation, and jump-to-ayah.
class ReaderOptionsSheet extends ConsumerStatefulWidget {
  const ReaderOptionsSheet({
    super.key,
    required this.ayahCount,
    required this.onJump,
  });

  final int ayahCount;
  final ValueChanged<int> onJump;

  static Future<void> show(
    BuildContext context, {
    required int ayahCount,
    required ValueChanged<int> onJump,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReaderOptionsSheet(ayahCount: ayahCount, onJump: onJump),
    );
  }

  @override
  ConsumerState<ReaderOptionsSheet> createState() => _ReaderOptionsSheetState();
}

class _ReaderOptionsSheetState extends ConsumerState<ReaderOptionsSheet> {
  final _jump = TextEditingController();
  String? _jumpError;

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  void _submitJump() {
    final n = int.tryParse(_jump.text.trim());
    if (n == null || n < 1 || n > widget.ayahCount) {
      setState(() => _jumpError = context.tr(
            'أدخل رقمًا بين 1 و ${widget.ayahCount}',
            'Enter a number from 1 to ${widget.ayahCount}',
          ));
      return;
    }
    Navigator.of(context).pop();
    widget.onJump(n);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.textDark : AppColors.textLight;
    final fontSize = ref.watch(readerFontSizeProvider);
    final showTranslation = ref.watch(showTranslationProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('خيارات القراءة', 'Reading options'),
              style: GoogleFonts.cairo(
                  fontSize: 18, fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(context.tr('حجم الخط', 'Text size'),
                style: GoogleFonts.cairo(fontSize: 13, color: text)),
            Row(
              children: [
                const Icon(Icons.text_decrease_rounded, size: 18),
                Expanded(
                  child: Slider(
                    value: fontSize,
                    min: SettingsRepository.minFontSize,
                    max: SettingsRepository.maxFontSize,
                    divisions: 10,
                    label: fontSize.round().toString(),
                    onChanged: (v) =>
                        ref.read(readerFontSizeProvider.notifier).update(v),
                  ),
                ),
                const Icon(Icons.text_increase_rounded, size: 18),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: showTranslation,
              onChanged: (v) =>
                  ref.read(showTranslationProvider.notifier).update(v),
              title: Text(
                context.tr(
                    'عرض الترجمة الإنجليزية', 'Show English translation'),
                style: GoogleFonts.cairo(fontSize: 14, color: text),
              ),
              subtitle: Text(
                context.tr('Sahih International', 'Sahih International'),
                style: GoogleFonts.cairo(fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(context.tr('الانتقال إلى آية', 'Jump to ayah'),
                style: GoogleFonts.cairo(fontSize: 13, color: text)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _jump,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submitJump(),
                    decoration: InputDecoration(
                      hintText: '1 – ${widget.ayahCount}',
                      errorText: _jumpError,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _submitJump,
                  child: Text(context.tr('انتقال', 'Go')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
