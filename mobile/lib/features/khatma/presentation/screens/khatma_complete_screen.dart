import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/khatma_planner.dart';
import '../khatma_providers.dart';
import '../widgets/khatma_labels.dart';
import 'khatma_setup_screen.dart';

/// A completed khatma: congratulations, the dua of completing the Quran,
/// and how it went. Offers to start the next one.
class KhatmaCompleteScreen extends ConsumerWidget {
  const KhatmaCompleteScreen({super.key, required this.id});

  static const String path = '/khatma/done/:id';
  static String pathFor(String id) => '/khatma/done/$id';

  final String id;

  /// The widely recited dua for completing the Quran. It is a traditional
  /// supplication, not a hadith, and is presented as such.
  static const String dua =
      'اللَّهُمَّ ارْحَمْنِي بِالقُرْآنِ، وَاجْعَلْهُ لِي إِمَامًا وَنُورًا '
      'وَهُدًى وَرَحْمَةً، اللَّهُمَّ ذَكِّرْنِي مِنْهُ مَا نَسِيتُ، '
      'وَعَلِّمْنِي مِنْهُ مَا جَهِلْتُ، وَارْزُقْنِي تِلَاوَتَهُ آنَاءَ '
      'اللَّيْلِ وَأَطْرَافَ النَّهَارِ، وَاجْعَلْهُ لِي حُجَّةً يَا رَبَّ '
      'العَالَمِينَ.';

  static const String duaMeaning =
      'O Allah, have mercy on me through the Quran, and make it a guide, a '
      'light, guidance and mercy for me. O Allah, remind me of what I have '
      'forgotten of it, teach me what I do not know of it, grant me its '
      'recitation through the night and the day, and make it a proof for '
      'me, O Lord of the worlds.';

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context,
      title: context.tr('حذف من القائمة؟', 'Remove from the list?'),
      message: context.tr('تُحذف هذه الختمة من الختمات المكتملة.',
          'This khatma is removed from your completed khatmas.'),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
          label: context.tr('حذف', 'Remove'),
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (ok != true || !context.mounted) return;
    await ref.read(khatmaProvider.notifier).deleteCompleted(id);
    if (context.mounted) context.pop();
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    await ref.read(khatmaProvider.notifier).undo();
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(khatmaProvider);
    final k = state.history.where((h) => h.id == id).firstOrNull;
    final c = context.palette;
    if (!state.loaded) return const AppScaffold(child: AppLoader());
    if (k == null) {
      return AppScaffold(
        title: context.tr('ختمة القرآن', 'Quran khatma'),
        child: Center(
          child: Text(context.tr('لم تُعثر على هذه الختمة', 'Khatma not found'),
              style: AppTypography.body.copyWith(color: c.secondaryLabel)),
        ),
      );
    }
    final justFinished = state.canUndo && state.history.first.id == id;
    final finishedOn = k.completedAt ?? k.endDate;
    final days = KhatmaPlanner.daysTaken(k, finishedOn);

    return AppScaffold(
      title: context.tr('ختمة مكتملة', 'Khatma completed'),
      trailing: justFinished
          ? null
          : AppIconButton(
              icon: CupertinoIcons.trash,
              label: context.tr('حذف', 'Remove'),
              onPressed: () => _delete(context, ref),
            ),
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: AppSpacing.screenInsets,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              ornament: CrescentCornersPainter(c.gold.withValues(alpha: 0.6)),
              child: Column(
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill,
                      size: 56, color: c.gold),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('مبارك! أتممت ختمة القرآن',
                        'Congratulations! You completed the Quran'),
                    textAlign: TextAlign.center,
                    style: AppTypography.title2.copyWith(color: c.label),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.tr('تقبّل الله منك، وجعله شفيعًا لك ولوالديك',
                        'May Allah accept it, and make it an intercessor for you and your parents'),
                    textAlign: TextAlign.center,
                    style: AppTypography.subheadline
                        .copyWith(color: c.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: AppSpacing.screenInsets,
            child: AppCard(
              child: Row(
                children: [
                  _Figure(
                    value: daysLabel(context, days),
                    label: context.tr('المدة', 'Took'),
                  ),
                  _Figure(
                    value: perDayLabel(
                        context, KhatmaPlanner.averagePerDay(k, finishedOn)),
                    label: context.tr('المعدّل', 'Average'),
                  ),
                  _Figure(
                    value: pagesLabel(context, k.pagesToRead),
                    label: context.tr('قرأت', 'Read'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: AppSpacing.screenInsets,
            child: Text(
              context.tr(
                  'من ${dateLabel(context, k.startDate)} إلى ${dateLabel(context, finishedOn)}',
                  '${dateLabel(context, k.startDate)} to ${dateLabel(context, finishedOn)}'),
              textAlign: TextAlign.center,
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppListSection(
            header:
                context.tr('دعاء ختم القرآن', 'Dua for completing the Quran'),
            footer: context.tr('دعاء مأثور يتداوله المسلمون عند الختم.',
                'A traditional supplication Muslims recite on completing the Quran.'),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        dua,
                        textAlign: TextAlign.center,
                        style: AppTypography.quran(size: 22, height: 1.9)
                            .copyWith(color: c.label),
                      ),
                    ),
                    if (!context.isArabic) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        duaMeaning,
                        textAlign: TextAlign.center,
                        style: AppTypography.footnote
                            .copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.active == null)
            Padding(
              padding: AppSpacing.screenInsets,
              child: AppButton.filled(
                label: context.tr('ابدأ ختمة جديدة', 'Start a new khatma'),
                icon: CupertinoIcons.add,
                expand: true,
                onPressed: () =>
                    context.pushReplacement(KhatmaSetupScreen.path),
              ),
            ),
          if (justFinished)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Center(
                child: AppButton.plain(
                  label:
                      context.tr('لم أُكمل بعد؟ تراجع', 'Not finished? Undo'),
                  icon: CupertinoIcons.arrow_uturn_left,
                  small: true,
                  onPressed: () => _undo(context, ref),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(color: c.label),
          ),
          Text(
            label,
            style: AppTypography.caption1.copyWith(color: c.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
