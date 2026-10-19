import '../../features/dedication/data/dedication_repository.dart';
import '../../features/dedication/presentation/dedication_labels.dart';
import '../design/design.dart';
import '../localization/tr.dart';

/// The heart of Lahuma: who the reader's recitation is dedicated to, and how
/// much has been dedicated so far. Tapping it lets the reader change the
/// dedication.
class SadaqahCard extends StatelessWidget {
  const SadaqahCard({super.key, required this.dedication, this.onTap});

  final Dedication dedication;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final names = dedication.names.trim();

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconTile(
              icon: CupertinoIcons.heart_fill,
              color: AppColors.tileRed,
              size: 32),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dedication.target.title(context),
                  style: AppTypography.headline.copyWith(color: c.label),
                ),
                if (names.isNotEmpty)
                  Text(
                    names,
                    style: AppTypography.subheadline
                        .weight(FontWeight.w600)
                        .copyWith(color: c.label),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dedication.target.dua(context),
                  style: context.isArabic
                      ? AppTypography.quran(size: 17, height: 1.7)
                          .copyWith(color: c.secondaryLabel)
                      : AppTypography.subheadline
                          .copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dedication.total > 0
                      ? context.tr('أُهدي حتى الآن ${dedication.total} آية',
                          '${dedication.total} ayahs dedicated so far')
                      : context.tr('اقرأ لتبدأ الإهداء',
                          'Read to begin your dedication'),
                  style: AppTypography.footnote
                      .weight(FontWeight.w600)
                      .copyWith(color: c.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
