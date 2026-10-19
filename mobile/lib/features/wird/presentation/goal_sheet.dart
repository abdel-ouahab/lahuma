import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/wird_repository.dart';
import 'wird_providers.dart';

/// Bottom sheet for picking the daily ayah goal.
class GoalSheet extends ConsumerWidget {
  const GoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      // Show above the shell's floating nav bar instead of behind it.
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const GoalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goal = ref.watch(wirdProvider.select((w) => w.goal));

    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('هدفك اليومي', 'Daily goal'),
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr('كم آية تريد أن تقرأ كل يوم؟',
                    'How many ayahs do you want to read each day?'),
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in WirdRepository.goalOptions)
                    ChoiceChip(
                      label: Text(context.tr('$option آية', '$option ayahs')),
                      selected: goal == option,
                      onSelected: (_) {
                        ref.read(wirdProvider.notifier).setGoal(option);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
