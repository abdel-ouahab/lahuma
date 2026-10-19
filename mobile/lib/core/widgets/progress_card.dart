import '../../features/wird/data/wird_repository.dart';
import '../design/design.dart';
import '../localization/tr.dart';

/// Today's wird: ayahs read against the daily goal. Calm, not competitive —
/// the only streak shown is the one the reader has actually earned.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.wird, this.onTap});

  final WirdState wird;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final percent = (wird.fraction * 100).toInt();

    final message = wird.goalReached
        ? context.tr('أتممت وردك اليوم، تقبّل الله منك',
            'You finished today\'s wird. May Allah accept it.')
        : wird.ayahsToday == 0
            ? context.tr('ابدأ وردك اليوم', 'Start today\'s wird')
            : context.tr('بقي ${wird.goal - wird.ayahsToday} آية على هدفك',
                '${wird.goal - wird.ayahsToday} ayahs to reach your goal');

    final count = AppTypography.tabular(
      AppTypography.subheadline
          .weight(FontWeight.w600)
          .copyWith(color: c.secondaryLabel),
    );

    return AppCard(
      onTap: onTap,
      child: Semantics(
        label: context.tr(
          '${wird.ayahsToday} من ${wird.goal} آية اليوم. اضغط لتغيير الهدف.',
          '${wird.ayahsToday} of ${wird.goal} ayahs today. Tap to change the goal.',
        ),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.sun_max_fill,
                    size: 18, color: c.resolve(AppColors.tileOrange)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr('وردك اليوم', 'Today\'s wird'),
                    style: AppTypography.headline.copyWith(color: c.label),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  context.tr(
                    '${ltr('${wird.ayahsToday} / ${wird.goal}')} آية',
                    '${wird.ayahsToday} / ${wird.goal} ayahs',
                  ),
                  style: count,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppProgressBar(value: wird.fraction, height: 8),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                LtrText(
                  '$percent%',
                  style: AppTypography.tabular(
                    AppTypography.footnote
                        .weight(FontWeight.w600)
                        .copyWith(color: c.accent),
                  ),
                ),
              ],
            ),
            if (wird.streak >= 2) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(CupertinoIcons.flame_fill, size: 16, color: c.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      context.tr('${wird.streak} أيام متتالية',
                          '${wird.streak}-day streak'),
                      style: AppTypography.footnote
                          .weight(FontWeight.w600)
                          .copyWith(color: c.secondaryLabel),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
