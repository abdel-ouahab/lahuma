import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../quran/mushaf/presentation/mushaf_providers.dart';
import '../../../quran/mushaf/presentation/screens/mushaf_screen.dart';
import '../../domain/khatma.dart';
import '../../domain/khatma_planner.dart';
import '../../domain/quran_pages.dart';
import '../khatma_providers.dart';
import '../widgets/khatma_labels.dart';
import '../widgets/juz_wheel.dart';
import '../widgets/khatma_ring.dart';
import '../widgets/page_picker_sheet.dart';
import 'khatma_complete_screen.dart';
import 'khatma_setup_screen.dart';

enum _Menu { edit, pause, resume, delete }

/// The khatma planner: the whole khatma's progress, today's portion, quick
/// progress buttons, pace, and the reading log. Without an active khatma,
/// an invitation to start one and the khatmas already completed.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  static const String path = '/khatma';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(khatmaProvider);
    final active = state.active;
    return AppScaffold(
      title: context.tr('ختمة القرآن', 'Quran khatma'),
      trailing: active == null
          ? null
          : AppIconButton(
              icon: CupertinoIcons.ellipsis_circle,
              label: context.tr('خيارات الختمة', 'Khatma options'),
              onPressed: () => _menu(context, ref, active),
            ),
      child: !state.loaded
          ? const AppLoader()
          : active == null
              ? _Empty(history: state.history)
              : _Active(khatma: active, state: state),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Khatma k) async {
    final paused = k.status == KhatmaStatus.paused;
    final action = await showAppActionSheet<_Menu>(
      context,
      actions: [
        AppSheetAction(
          label:
              context.tr('تعديل المدة والتذكير', 'Edit duration & reminders'),
          value: _Menu.edit,
          icon: CupertinoIcons.slider_horizontal_3,
        ),
        AppSheetAction(
          label: paused
              ? context.tr('استئناف الختمة', 'Resume khatma')
              : context.tr('إيقاف مؤقت', 'Pause'),
          value: paused ? _Menu.resume : _Menu.pause,
          icon: paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
        ),
        AppSheetAction(
          label: context.tr('حذف الختمة', 'Delete khatma'),
          value: _Menu.delete,
          icon: CupertinoIcons.trash,
          isDestructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    final notifier = ref.read(khatmaProvider.notifier);
    switch (action) {
      case _Menu.edit:
        context.push(KhatmaSetupScreen.editPath);
      case _Menu.pause:
        await notifier.pause();
        if (context.mounted) {
          AppToast.show(
              context,
              context.tr('أُوقفت الختمة. تتأخر نهايتها بقدر أيام التوقف.',
                  'Paused. The end date moves on by the days paused.'),
              icon: CupertinoIcons.pause_fill);
        }
      case _Menu.resume:
        await notifier.resume();
      case _Menu.delete:
        final ok = await showAppDialog<bool>(
          context,
          title: context.tr('حذف الختمة؟', 'Delete this khatma?'),
          message: context.tr('يُحذف تقدّمك وسجلّ قراءتك فيها وتذكيراتها.',
              'Its progress, reading log and reminders are deleted.'),
          actions: [
            AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
            AppDialogAction(
              label: context.tr('حذف', 'Delete'),
              value: true,
              isDestructive: true,
            ),
          ],
        );
        if (ok == true) await notifier.delete();
      case null:
        break;
    }
  }
}

// ─── No active khatma ──────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.history});

  final List<Khatma> history;

  /// Durations offered as a one-tap start, shortest first.
  static const List<int> _quickDays = [7, 30, 60];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: AppSpacing.screenInsets,
          child: AppCard(
            // Clear of the frame corners on all four sides.
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl,
                AppSpacing.xl, AppSpacing.xl + AppSpacing.sm),
            ornament: FrameCornersPainter(c.gold.withValues(alpha: 0.55)),
            child: Column(
              children: [
                const JuzWheel(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.tr('اختم القرآن في المدة التي تختارها',
                      'Finish the Quran in the time you choose'),
                  textAlign: TextAlign.center,
                  style: AppTypography.title3.copyWith(color: c.label),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr(
                      'يقسم التطبيق المصحف على أيامك، ويعيد الحساب إن تأخرت أو تقدّمت، ويذكّرك بوردك.',
                      'The app splits the Mushaf over the days, recalculates if you fall behind or get ahead, and reminds you of each day’s portion.'),
                  textAlign: TextAlign.center,
                  style: AppTypography.subheadline
                      .copyWith(color: c.secondaryLabel),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.filled(
                  label: context.tr('ابدأ ختمة جديدة', 'Start a new khatma'),
                  icon: CupertinoIcons.add,
                  expand: true,
                  onPressed: () => context.push(KhatmaSetupScreen.path),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppListSection(
          header: context.tr(
              'أو ابدأ بمدة شائعة', 'Or start with a common duration'),
          children: [
            for (final days in _quickDays)
              AppListTile(
                title: daysLabel(context, days),
                subtitle: _perDay(context, days),
                onTap: () => context.push(KhatmaSetupScreen.pathFor(days)),
              ),
          ],
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _CompletedList(history: history),
        ],
      ],
    );
  }

  /// "جزء واحد يوميًا (21 صفحة)": what [days] asks of each day.
  static String _perDay(BuildContext context, int days) {
    final pages = (QuranPages.total / days).ceil();
    final juz = amountLabel(context, pages, ReadingUnit.juz);
    final p = pagesLabel(context, pages);
    return context.tr('$juz يوميًا ($p)', '$juz a day ($p)');
  }
}

class _CompletedList extends StatelessWidget {
  const _CompletedList({required this.history});

  final List<Khatma> history;

  @override
  Widget build(BuildContext context) {
    return AppListSection(
      header: context.tr('ختمات أتممتها', 'Completed khatmas'),
      hasLeading: true,
      children: [
        for (final k in history)
          AppListTile(
            leading: const AppIconTile(
                icon: CupertinoIcons.checkmark_seal_fill,
                color: AppColors.tileYellow),
            title: dateLabel(context, k.completedAt ?? k.endDate),
            subtitle: daysLabel(context, KhatmaPlanner.daysTaken(k, k.endDate)),
            onTap: () => context.push(KhatmaCompleteScreen.pathFor(k.id)),
          ),
      ],
    );
  }
}

// ─── Active khatma ─────────────────────────────────────────────────────────

class _Active extends ConsumerWidget {
  const _Active({required this.khatma, required this.state});

  final Khatma khatma;
  final KhatmaState state;

  Future<void> _progress(BuildContext context, WidgetRef ref,
      Future<KhatmaProgress> Function(KhatmaNotifier n) update) async {
    final notifier = ref.read(khatmaProvider.notifier);
    final result = await update(notifier);
    if (!context.mounted) return;
    switch (result) {
      case KhatmaProgress.unchanged:
        return;
      case KhatmaProgress.completed:
        HapticFeedback.heavyImpact();
        context.push(KhatmaCompleteScreen.pathFor(khatma.id));
      case KhatmaProgress.saved:
        HapticFeedback.lightImpact();
        final k = ref.read(khatmaProvider).active;
        if (k == null) return;
        AppToast.show(
          context,
          context.tr('أنت الآن في صفحة ${k.lastPageRead}',
              "You're now at page ${k.lastPageRead}"),
          icon: CupertinoIcons.checkmark_alt,
          actionLabel: context.tr('تراجع', 'Undo'),
          onAction: notifier.undo,
        );
    }
  }

  Future<void> _reachPage(BuildContext context, WidgetRef ref) async {
    final page = await showPagePickerSheet(
      context,
      title: context.tr('وصلت إلى صفحة', 'I reached page'),
      initial: khatma.lastPageRead,
      min: khatma.startPage - 1,
    );
    if (page == null || !context.mounted) return;
    await _progress(context, ref, (n) => n.reachPage(page));
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    if (!await ref.read(khatmaProvider.notifier).undo()) return;
    HapticFeedback.selectionClick();
    if (context.mounted) {
      AppToast.show(context, context.tr('تم التراجع', 'Undone'),
          icon: CupertinoIcons.arrow_uturn_left);
    }
  }

  /// Opens the Mushaf on [page]. Back from it having turned pages, asks how
  /// far the reader got, starting from the page they left it on.
  Future<void> _openMushaf(
      BuildContext context, WidgetRef ref, int page) async {
    await context.push('${MushafScreen.path}?page=$page');
    if (!context.mounted) return;
    final left = ref.read(mushafProvider).lastPage;
    final k = ref.read(khatmaProvider).active;
    if (k == null || left <= page || left <= k.lastPageRead) return;
    final picked = await showPagePickerSheet(
      context,
      title: context.tr('إلى أين وصلت؟', 'How far did you read?'),
      initial: left,
      min: k.startPage - 1,
      confirmLabel: context.tr('سجّل تقدّمي', 'Save my progress'),
    );
    if (picked == null || !context.mounted) return;
    await _progress(context, ref, (n) => n.reachPage(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(ref.watch(khatmaClockProvider)());
    final paused = khatma.status == KhatmaStatus.paused;
    final overdue = KhatmaPlanner.isOverdue(khatma, today);
    final mushafPage = ref.watch(mushafProvider.select((m) => m.lastPage));
    final logs = state.logsOf(khatma.id);

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        if (paused)
          _PausedCard(khatma: khatma)
        else if (overdue && !khatma.overdueKept)
          _OverdueCard(khatma: khatma),
        if (!paused) ...[
          _TodayCard(
            khatma: khatma,
            today: today,
            onOpenMushaf: (page) => _openMushaf(context, ref, page),
          ),
          _QuickRow(
            khatma: khatma,
            today: today,
            canUndo: state.canUndo,
            mushafPage: mushafPage,
            onProgress: (update) => _progress(context, ref, update),
            onReachPage: () => _reachPage(context, ref),
            onUndo: () => _undo(context, ref),
          ),
        ],
        _OverviewCard(khatma: khatma, today: today),
        _LogSection(logs: logs, today: today),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.khatma, required this.today});

  final Khatma khatma;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final k = khatma;
    final pace = KhatmaPlanner.pace(k, today);
    final daysLeft = KhatmaPlanner.remainingDays(k.endDate, today);
    final paused = k.status == KhatmaStatus.paused;
    final plan = KhatmaPlanner.dayPlan(k, today);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                KhatmaRing(lastPageRead: k.lastPageRead, size: 132),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('موضعك', "You're at"),
                        style: AppTypography.caption1
                            .copyWith(color: c.secondaryLabel),
                      ),
                      Text(
                        k.lastPageRead == 0
                            ? context.tr('لم تبدأ بعد', 'Not started yet')
                            : pagePlace(context, k.lastPageRead),
                        style: AppTypography.headline.copyWith(color: c.label),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!paused) _PaceChip(pace: pace),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Stat(
                  label: context.tr('الأيام المتبقية', 'Days left'),
                  value: daysLeft == 0
                      ? context.tr('انتهت', 'None')
                      : daysLabel(context, daysLeft),
                ),
                _Stat(
                  label: context.tr('تختم يوم', 'Ends on'),
                  value: dateLabel(context, k.endDate),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Stat(
                  label: context.tr('المطلوب يوميًا', 'Needed per day'),
                  value: paused
                      ? '—'
                      : amountLabel(context, plan.pages, k.displayUnit),
                ),
                _Stat(
                  label: context.tr('معدّلك', 'Your average'),
                  value: perDayLabel(
                      context, KhatmaPlanner.averagePerDay(k, today)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption1.copyWith(color: c.secondaryLabel)),
          Text(value,
              style: AppTypography.subheadline
                  .copyWith(color: c.label, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PaceChip extends StatelessWidget {
  const _PaceChip({required this.pace});

  final KhatmaPace pace;

  @override
  Widget build(BuildContext context) {
    final color = paceColor(context, pace);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Text(
        paceLabel(context, pace),
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Today's portion, framed like a Mushaf page: which surahs, its pages, the
/// words it opens with, how much is read, and the way into the Mushaf.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.khatma,
    required this.today,
    required this.onOpenMushaf,
  });

  final Khatma khatma;
  final DateTime today;
  final ValueChanged<int> onOpenMushaf;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final arabic = context.isArabic;
    final k = khatma;
    final plan = KhatmaPlanner.dayPlan(k, today);
    final read = KhatmaPlanner.readToday(k, today);
    final done = KhatmaPlanner.todayDone(k, today);
    final hasPortion = plan.pages > 0;
    // Where the reading picks up: the page after the last one read.
    final next = (k.lastPageRead + 1).clamp(1, QuranPages.total);
    final fraction = hasPortion ? (read / plan.pages).clamp(0.0, 1.0) : 1.0;

    final firstSurah = QuranPages.surahName(plan.fromPage, arabic: arabic);
    final lastSurah = QuranPages.surahName(plan.targetPage, arabic: arabic);
    final surahs =
        firstSurah == lastSurah ? firstSurah : '$firstSurah – $lastSurah';
    final pages = plan.pages == 1
        ? context.tr('صفحة ${plan.fromPage}', 'Page ${plan.fromPage}')
        : context.tr('الصفحات ${ltr('${plan.fromPage}–${plan.targetPage}')}',
            'Pages ${plan.fromPage}–${plan.targetPage}');
    final unit = k.displayUnit == ReadingUnit.pages
        ? ''
        : context.tr('، ', ', ') +
            amountLabel(context, plan.pages, k.displayUnit);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.ms),
      child: AppCard(
        // Clear of the frame corners on all four sides.
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        borderColor: done ? c.success.withValues(alpha: 0.5) : null,
        ornament: FrameCornersPainter(c.gold.withValues(alpha: 0.55)),
        child: Column(
          children: [
            Text(
              context.tr('ورد اليوم', "Today's portion"),
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
            if (hasPortion) ...[
              Text(
                surahs,
                textAlign: TextAlign.center,
                style: arabic
                    ? AppTypography.quran(size: 30, height: 1.6)
                        .copyWith(color: c.label)
                    : AppTypography.title2.copyWith(color: c.label),
              ),
              Text(
                '$pages$unit',
                style:
                    AppTypography.subheadline.copyWith(color: c.secondaryLabel),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  context.tr('لا شيء متبقٍّ', 'Nothing left'),
                  style: AppTypography.title3.copyWith(color: c.label),
                ),
              ),
            if (hasPortion && !done) ...[
              const SizedBox(height: AppSpacing.md),
              const AppGoldRule(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '﴿ ${QuranPages.openingWords(next)} ﴾',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.quran(size: 21, height: 1.9)
                    .copyWith(color: c.label),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: AppMotion.of(context),
                builder: (context, v, _) => _Bar(
                  value: v,
                  color: done ? c.success : c.accent,
                  track: c.tertiaryFill,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (done) ...[
                  Icon(CupertinoIcons.checkmark_seal_fill,
                      size: 16, color: c.success),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    done
                        ? context.tr('أتممت ورد اليوم، تقبّل الله منك',
                            "Today's portion is done. May Allah accept it")
                        : context.tr(
                            'قرأت ${ltr('$read')} من ${pagesLabel(context, plan.pages)}',
                            'Read $read of ${pagesLabel(context, plan.pages)}'),
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote
                        .copyWith(color: done ? c.success : c.secondaryLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.filled(
              label: done
                  ? context.tr('واصل في المصحف', 'Keep reading')
                  : context.tr('افتح المصحف على صفحة $next',
                      'Open Mushaf at page $next'),
              icon: CupertinoIcons.book_fill,
              expand: true,
              onPressed: () => onOpenMushaf(next),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin bar; [value] 0–1.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => Container(
        height: 6,
        color: track,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      );
}

/// Progress without the Mushaf, under today's portion: mark it done, set the
/// page reached, a page or a hizb at a time, the page the Mushaf was left
/// on, and undo.
class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.khatma,
    required this.today,
    required this.canUndo,
    required this.mushafPage,
    required this.onProgress,
    required this.onReachPage,
    required this.onUndo,
  });

  final Khatma khatma;
  final DateTime today;
  final bool canUndo;
  final int mushafPage;
  final void Function(Future<KhatmaProgress> Function(KhatmaNotifier n))
      onProgress;
  final VoidCallback onReachPage;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final done = KhatmaPlanner.todayDone(khatma, today);
    final showMushaf = mushafPage > 1 &&
        mushafPage != khatma.lastPageRead &&
        mushafPage >= khatma.startPage;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppButton.tinted(
                  label: context.tr('أتممت ورد اليوم', 'Mark today done'),
                  icon: CupertinoIcons.checkmark_alt,
                  small: true,
                  onPressed:
                      done ? null : () => onProgress((n) => n.markTodayDone()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.tinted(
                  label: context.tr('وصلت إلى صفحة…', 'I reached page…'),
                  icon: CupertinoIcons.bookmark_fill,
                  small: true,
                  onPressed: onReachPage,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton.plain(
                label: context.tr('+ صفحة', '+1 page'),
                small: true,
                onPressed: () => onProgress((n) => n.addPages(1)),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton.plain(
                label: context.tr('+ حزب', '+1 hizb'),
                small: true,
                onPressed: () => onProgress((n) => n.addHizb()),
              ),
            ],
          ),
          if (showMushaf)
            AppButton.plain(
              label: context.tr('وصلت إلى صفحة $mushafPage في المصحف',
                  "I'm at page $mushafPage in the Mushaf"),
              icon: CupertinoIcons.book,
              small: true,
              onPressed: () => onProgress((n) => n.reachPage(mushafPage)),
            ),
          if (canUndo)
            AppButton.plain(
              label: context.tr('تراجع عن آخر تحديث', 'Undo last update'),
              icon: CupertinoIcons.arrow_uturn_left,
              small: true,
              onPressed: onUndo,
            ),
        ],
      ),
    );
  }
}

class _PausedCard extends ConsumerWidget {
  const _PausedCard({required this.khatma});

  final Khatma khatma;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.md),
      child: AppCard(
        borderColor: c.warning.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.pause_circle_fill, color: c.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr('الختمة متوقفة مؤقتًا', 'Khatma paused'),
                    style: AppTypography.headline.copyWith(color: c.label),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                  'منذ ${dateLabel(context, khatma.pausedOn ?? khatma.startDate)}. لا تذكير أثناء التوقف، وتتأخر نهاية الختمة بقدر أيامه.',
                  'Since ${dateLabel(context, khatma.pausedOn ?? khatma.startDate)}. No reminders while paused; the end date moves on by the days paused.'),
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
            const SizedBox(height: AppSpacing.ms),
            AppButton.filled(
              label: context.tr('استئناف', 'Resume'),
              icon: CupertinoIcons.play_fill,
              small: true,
              onPressed: () => ref.read(khatmaProvider.notifier).resume(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends ConsumerWidget {
  const _OverdueCard({required this.khatma});

  final Khatma khatma;

  static const List<int> _extensions = [3, 7, 14, 30];

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    final days = await showAppPicker<int>(
      context,
      title: context.tr('مدّد الختمة', 'Extend the khatma'),
      items: _extensions,
      selected: 7,
      labelOf: (d) => daysLabel(context, d),
    );
    if (days != null) await ref.read(khatmaProvider.notifier).extend(days);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final left = KhatmaPlanner.remainingPages(khatma.lastPageRead);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.md),
      child: AppCard(
        borderColor: c.destructive.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                  'انتهت المدة ولم تكتمل الختمة', 'The end date has passed'),
              style: AppTypography.headline.copyWith(color: c.label),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                  'بقي ${pagesLabel(context, left)}. مدّد الختمة لتوزيعها على أيام جديدة، أو أكمل وتبقى كلها ورد اليوم.',
                  '${pagesLabel(context, left)} left. Extend to spread them over new days, or keep going with all of them as today\'s portion.'),
              style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
            ),
            const SizedBox(height: AppSpacing.ms),
            Row(
              children: [
                Expanded(
                  child: AppButton.filled(
                    label: context.tr('مدّد', 'Extend'),
                    small: true,
                    onPressed: () => _extend(context, ref),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.tinted(
                    label: context.tr('أكمل كما هي', 'Keep going'),
                    small: true,
                    onPressed: () =>
                        ref.read(khatmaProvider.notifier).keepOverdue(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({required this.logs, required this.today});

  final List<DailyLog> logs;
  final DateTime today;

  static const int _shown = 14;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    return AppListSection(
      header: context.tr('سجل القراءة', 'Reading log'),
      children: [
        for (final log in logs.take(_shown))
          AppListTile(
            title: dayLabel(context, log.date, today),
            subtitle: context.tr('من صفحة ${log.fromPage} إلى ${log.toPage}',
                'Pages ${log.fromPage}–${log.toPage}'),
            value: pagesLabel(context, log.pages),
          ),
      ],
    );
  }
}
