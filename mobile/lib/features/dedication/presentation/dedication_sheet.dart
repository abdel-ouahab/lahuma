import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/dedication_repository.dart';
import 'dedication_labels.dart';
import 'dedication_providers.dart';

/// Bottom sheet for choosing who the reading is dedicated to.
class DedicationSheet extends ConsumerStatefulWidget {
  const DedicationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Open above the shell so the floating tab bar does not cover the sheet.
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const DedicationSheet(),
    );
  }

  @override
  ConsumerState<DedicationSheet> createState() => _DedicationSheetState();
}

class _DedicationSheetState extends ConsumerState<DedicationSheet> {
  late DedicationTarget _target;
  late final TextEditingController _names;

  @override
  void initState() {
    super.initState();
    final current = ref.read(dedicationProvider);
    _target = current.target;
    _names = TextEditingController(text: current.names);
  }

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(dedicationProvider.notifier)
        .set(target: _target, names: _names.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.textDark : AppColors.textLight;

    final media = MediaQuery.of(context);
    // Keyboard when open, otherwise the system gesture/nav bar.
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0, // the drag handle already provides top spacing
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('لمن تُهدي قراءتك؟', 'Who is this reading for?'),
              style: GoogleFonts.cairo(
                  fontSize: 18, fontWeight: FontWeight.w700, color: text),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                'كل آية تقرؤها تُحسب لهم، وتظهر دعوتك في نهاية كل سورة.',
                'Every ayah you read is counted for them, and your dua appears at the end of each surah.',
              ),
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.6,
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in DedicationTarget.values)
                  ChoiceChip(
                    label: Text(t.chip(context)),
                    selected: _target == t,
                    onSelected: (_) => setState(() => _target = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _names,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('الاسم (اختياري)', 'Name (optional)'),
                hintText: context.tr('مثال: أبي محمد', 'For example: Muhammad'),
                counterText: '', // still capped at 60; the counter was clutter
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _save,
                child: Text(context.tr('حفظ النية', 'Save dedication')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
