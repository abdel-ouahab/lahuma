import '../design/design.dart';
import '../localization/tr.dart';

/// Hero "Continue Reading" card on the Home screen.
/// One idea: where you left off, and a single obvious way back in.
/// [progressPercent] is null when it isn't known.
class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    this.surahName,
    this.ayahNumber,
    this.progressPercent,
    this.onTap,
  });

  final String? surahName;
  final int? ayahNumber;
  final double? progressPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasProgress = surahName != null;
    const onHero = AppColors.onAccent;
    final onHeroDim = onHero.withValues(alpha: 0.75);
    final actionColor = AppColors.heroGradient.last;
    final caption = AppTypography.footnote
        .weight(FontWeight.w600)
        .copyWith(color: onHeroDim);

    return AppCard(
      onTap: onTap,
      semanticLabel: hasProgress
          ? context.tr(
              'متابعة القراءة: $surahName', 'Continue reading $surahName')
          : context.tr('ابدأ القراءة', 'Start reading'),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ml),
      gradient: const LinearGradient(
        colors: AppColors.heroGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasProgress
                      ? context.tr('آخر قراءة', 'Last read')
                      : context.tr('ابدأ القراءة', 'Start reading'),
                  style: caption,
                ),
              ),
              if (progressPercent != null)
                LtrText('${progressPercent!.toInt()}%',
                    style: AppTypography.tabular(caption)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasProgress
                ? surahName!
                : context.tr('القرآن الكريم', 'The Holy Quran'),
            style: AppTypography.quran(
                    size: 34, weight: FontWeight.w700, height: 1.35)
                .copyWith(color: onHero),
          ),
          if (hasProgress)
            Text(
              context.tr('الآية ${ayahNumber ?? 1}', 'Ayah ${ayahNumber ?? 1}'),
              style: AppTypography.subheadline.copyWith(color: onHeroDim),
            ),
          const SizedBox(height: AppSpacing.md),
          if (progressPercent != null) ...[
            AppProgressBar(
              value: progressPercent! / 100,
              color: onHero,
              trackColor: onHero.withValues(alpha: 0.22),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Single clear action: a white capsule, the card's only bright
          // element. The whole card is the tap target.
          DecoratedBox(
            decoration:
                const ShapeDecoration(color: onHero, shape: StadiumBorder()),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.play_fill, size: 15, color: actionColor),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      hasProgress
                          ? context.tr('متابعة القراءة', 'Continue')
                          : context.tr('ابدأ الآن', 'Begin'),
                      style: AppTypography.subheadline
                          .weight(FontWeight.w700)
                          .copyWith(color: actionColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
