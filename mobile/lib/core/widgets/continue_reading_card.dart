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
    this.onOpenMushaf,
  });

  final String? surahName;
  final int? ayahNumber;
  final double? progressPercent;
  final VoidCallback? onTap;

  /// Opens the Mushaf on its last page. Hidden when null.
  final VoidCallback? onOpenMushaf;

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
          // Main action: a white capsule, the card's only bright element.
          // The whole card is its tap target. The Mushaf capsule beside it
          // is quieter and handles its own tap.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Capsule(
                icon: CupertinoIcons.play_fill,
                label: hasProgress
                    ? context.tr('متابعة القراءة', 'Continue')
                    : context.tr('ابدأ الآن', 'Begin'),
                fill: onHero,
                color: actionColor,
              ),
              if (onOpenMushaf != null)
                Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: context.tr(
                      'متابعة القراءة في المصحف', 'Continue in the Mushaf'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenMushaf,
                    child: _Capsule(
                      icon: CupertinoIcons.book_fill,
                      label: context.tr(
                          'متابعة القراءة في المصحف', 'Continue in the Mushaf'),
                      fill: onHero.withValues(alpha: 0.18),
                      color: onHero,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.icon,
    required this.label,
    required this.fill,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                label,
                style: AppTypography.subheadline
                    .weight(FontWeight.w700)
                    .copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
