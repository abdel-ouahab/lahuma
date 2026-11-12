import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/widgets/shortcut_tile.dart';
import '../../domain/khatma.dart';
import '../../domain/khatma_planner.dart';
import '../../domain/quran_pages.dart';
import '../khatma_providers.dart';
import '../screens/khatma_screen.dart';
import 'khatma_labels.dart';
import 'khatma_ring.dart';

/// Home's large shortcut into the khatma: the juz' ring, what is left of
/// today's portion and where it picks up, or an invitation to start one.
class KhatmaHomeCard extends ConsumerWidget {
  const KhatmaHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final k = ref.watch(khatmaProvider.select((s) => s.active));
    final today = dateOnly(ref.watch(khatmaClockProvider)());
    final title = context.tr('ختمة القرآن', 'Quran khatma');
    final (lead, line, from) = _status(context, k, today);
    final percent =
        k == null ? 0 : (k.lastPageRead * 100 / QuranPages.total).floor();
    // Painted like the other shortcuts: an open Mushaf on its rahl.
    const ink = ShortcutTile.onScene;
    final inkDim = ink.withValues(alpha: 0.82);
    final tone = AppColors.tileGreen.color;
    return AppCard(
      color: TileScenePainter.baseFor(tone),
      borderColor:
          AppColors.gold.color.withValues(alpha: c.isDark ? 0.35 : 0.5),
      ornament: TileScenePainter(
        scene: TileScene.openMushaf,
        tone: tone,
        textDirection: Directionality.of(context),
      ),
      onTap: () => context.push(KhatmaScreen.path),
      semanticLabel: [title, lead, line, if (from != null) from].join('، '),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.headline.copyWith(color: ink)),
              ),
              AppDirectionalIcon(CupertinoIcons.chevron_forward,
                  size: 16, color: ink.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          KhatmaRing(
            lastPageRead: k?.lastPageRead ?? 0,
            size: 76,
            onScene: true,
            center: k == null
                ? const Icon(CupertinoIcons.add,
                    size: 26, color: AppColors.lanternFlame)
                : Text(
                    ltr('$percent%'),
                    style: AppTypography.tabular(AppTypography.subheadline)
                        .copyWith(color: ink, fontWeight: FontWeight.w600),
                  ),
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.ms),
          Text(
            lead,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title3.copyWith(color: ink),
          ),
          Text(
            line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.footnote.copyWith(color: inkDim),
          ),
          if (from != null)
            Text(
              from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.footnote
                  .weight(FontWeight.w600)
                  .copyWith(color: AppColors.lanternFlame),
            ),
        ],
      ),
    );
  }

  /// The large line, the line under it, and where reading picks up.
  static (String, String, String?) _status(
      BuildContext context, Khatma? k, DateTime today) {
    if (k == null) {
      return (
        context.tr('ابدأ ختمة', 'Start a khatma'),
        context.tr('اختم القرآن في المدة التي تختارها',
            'Finish the Quran in the time you choose'),
        null,
      );
    }
    if (k.status == KhatmaStatus.paused) {
      return (
        context.tr('متوقفة مؤقتًا', 'Paused'),
        context.tr('استأنفها متى شئت', 'Resume it any time'),
        null,
      );
    }
    final left = KhatmaPlanner.todayRemaining(k, today);
    if (left == 0) {
      return (
        context.tr('تمّ ورد اليوم', "Today's portion done"),
        context.tr('تقبّل الله منك', 'May Allah accept it'),
        null,
      );
    }
    final next = (k.lastPageRead + 1).clamp(1, QuranPages.total);
    return (
      pagesLabel(context, left),
      context.tr('بقيت من ورد اليوم', 'left of today’s portion'),
      context.tr('من صفحة $next، ${QuranPages.surahName(next, arabic: true)}',
          'From page $next, ${QuranPages.surahName(next, arabic: false)}'),
    );
  }
}
