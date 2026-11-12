import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../data/wird_repository.dart';
import 'wird_providers.dart';

/// Bottom sheet for picking the daily ayah goal.
class GoalSheet extends ConsumerWidget {
  const GoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppBottomSheet<void>(
      context,
      title: context.tr('الهدف اليومي', 'Daily goal'),
      builder: (_) => const GoalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final goal = ref.watch(wirdProvider.select((w) => w.goal));

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('كم آية تريد أن تقرأ كل يوم؟',
                'How many ayahs do you want to read each day?'),
            style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final option in WirdRepository.goalOptions) ...[
            _GoalOption(
              ayahs: option,
              selected: option == goal,
              onTap: () {
                ref.read(wirdProvider.notifier).setGoal(option);
                Navigator.of(context).pop();
              },
            ),
            if (option != WirdRepository.goalOptions.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.ayahs,
    required this.selected,
    required this.onTap,
  });

  final int ayahs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    // About ten ayahs per Mushaf page on average (6236 over 604 pages).
    final pages = ayahs / 10;
    final pagesLabel = pages < 1
        ? context.tr('أقل من صفحة', 'Under a page')
        : pages == 1
            ? context.tr('نحو صفحة', 'About a page')
            : pages.round() == 2
                ? context.tr('نحو صفحتين', 'About 2 pages')
                : context.tr('نحو ${pages.round()} صفحات',
                    'About ${pages.round()} pages');
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        onTap: onTap,
        color: selected ? c.accentTint : c.secondaryGroupedBackground,
        borderColor: selected ? c.accent : null,
        radius: AppRadius.medium,
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.ms),
        semanticLabel: context.tr('$ayahs آية، $pagesLabel',
            '$ayahs ayahs, ${pagesLabel.toLowerCase()}'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr('$ayahs آية', '$ayahs ayahs'),
                style: AppTypography.tabular(AppTypography.headline)
                    .copyWith(color: c.label),
              ),
            ),
            Text(
              pagesLabel,
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(CupertinoIcons.checkmark_alt, size: 18, color: c.accent),
            ],
          ],
        ),
      ),
    );
  }
}
