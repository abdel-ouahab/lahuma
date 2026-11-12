import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../adhan/presentation/adhan_providers.dart';
import '../../fajr_call/presentation/fajr_call_providers.dart';
import '../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../data/reminder_notifications.dart';
import '../domain/reminder_plan.dart';
import 'reminder_providers.dart';

/// "التذكير بالأذكار والسور": how often (off / rarely / moderately /
/// often), what that sends today on a timeline of the day, and a preview
/// of the notification itself. Settings → القراءة.
class RemindersSettingsScreen extends ConsumerWidget {
  const RemindersSettingsScreen({super.key});

  static const String path = '/settings/reminders';

  static String frequencyLabel(BuildContext context, ReminderFrequency f) =>
      switch (f) {
        ReminderFrequency.off => context.tr('إيقاف', 'Off'),
        ReminderFrequency.rare => context.tr('قليل', 'Rarely'),
        ReminderFrequency.moderate => context.tr('معتدل', 'Moderately'),
        ReminderFrequency.frequent => context.tr('كثير', 'Often'),
      };

  /// "3 a day, 5 on Friday", or "Off".
  static String summary(BuildContext context, ReminderFrequency f) {
    if (f == ReminderFrequency.off) return context.tr('متوقف', 'Off');
    final daily =
        ReminderKind.values.where((k) => k.sentAt(f) && !k.friday).length;
    final friday = ReminderKind.values.where((k) => k.sentAt(f)).length;
    return context.tr(
      '${_count(daily)} في اليوم، و$friday يوم الجمعة',
      '$daily a day, $friday on Friday',
    );
  }

  static String _count(int n) => switch (n) {
        1 => 'تذكير واحد',
        2 => 'تذكيران',
        _ when n <= 10 => '$n تذكيرات',
        _ => '$n تذكيرًا',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reminderProvider);
    final notifier = ref.read(reminderProvider.notifier);
    // Rebuilds when the times arrive or change.
    ref.watch(upcomingPrayerDaysProvider);
    final today = notifier.today();
    final perms = ref.watch(adhanPermissionsProvider).valueOrNull ??
        const AdhanPermissions();
    final f = state.frequency;
    final on = f != ReminderFrequency.off;
    final now = ref.watch(adhanClockProvider)();
    final next = today
        .where((r) =>
            r.kind.sentAt(f) &&
            (!r.kind.friday || now.weekday == DateTime.friday) &&
            r.at.isAfter(now))
        .firstOrNull;
    final preview = next?.kind ??
        (on
            ? ReminderKind.values.firstWhere((k) => k.sentAt(f))
            : ReminderKind.morningAdhkar);

    Future<void> choose(ReminderFrequency value) async {
      await notifier.setFrequency(value);
      if (value == ReminderFrequency.off) return;
      final n = ref.read(localNotificationsProvider);
      // Asked here, in context, never at launch.
      if (!await n.areEnabled()) await n.requestPermission();
      ref.invalidate(adhanPermissionsProvider);
    }

    return AppScaffold.largeTitle(
      title: context.tr('التذكير بالأذكار والسور', 'Adhkar & surah reminders'),
      slivers: [
        if (!state.loaded)
          const SliverFillRemaining(child: AppLoader())
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                  AppSpacing.sm, AppSpacing.screenMargin, AppSpacing.lg),
              child: AnimatedOpacity(
                opacity: on ? 1 : 0.45,
                duration: AppMotion.standard,
                child: _NotificationPreview(
                  kind: preview,
                  at: next?.at,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSegmentedControl<ReminderFrequency>(
                    segments: {
                      for (final v in ReminderFrequency.values)
                        v: frequencyLabel(context, v),
                    },
                    value: f,
                    onChanged: choose,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.xs),
                    child: Text(
                      on
                          ? summary(context, f)
                          : context.tr('لن يصلك أي تذكير بالأذكار والسور.',
                              "You won't get adhkar or surah reminders."),
                      style: AppTypography.footnote
                          .copyWith(color: context.palette.secondaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (on && !perms.notifications)
            SliverToBoxAdapter(
              child: AppListSection(
                hasLeading: true,
                margin: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screenMargin,
                    AppSpacing.md,
                    AppSpacing.screenMargin,
                    0),
                children: [
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.bell_slash_fill,
                        color: AppColors.tileRed),
                    title:
                        context.tr('الإشعارات متوقفة', 'Notifications are off'),
                    subtitle: context.tr(
                        'لن يصلك التذكير حتى تفعّلها. اضغط لتفعيلها.',
                        "Reminders can't reach you until you turn them on. Tap to turn them on."),
                    onTap: () => _fixNotifications(ref),
                  ),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                  AppSpacing.xl, AppSpacing.screenMargin, AppSpacing.sm),
              child: Text(
                context.tr('يومك', 'Your day'),
                style: AppTypography.headline
                    .copyWith(color: context.palette.label),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin),
              child: _DayTimeline(
                frequency: f,
                times: {for (final r in today) r.kind: r.at},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin + AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.screenMargin,
                  AppSpacing.xxl),
              child: today.isEmpty
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                      onPressed: () => PrayerSettingsSheet.show(context),
                      child: Text(
                        context.tr('حدّد موقعك لتأتي التذكيرات في أوقاتها',
                            'Set your location so reminders come on time'),
                        style: AppTypography.subheadline
                            .copyWith(color: context.palette.accent),
                      ),
                    )
                  : Text(
                      context.tr(
                        'تتبع الأوقاتُ مواقيتَ الصلاة في مدينتك، فتتغير معها كل يوم. اضغط التذكير لتفتح الأذكار أو المصحف أو المسبحة.',
                        'Times follow the prayer times where you are, so they move with them each day. Tap a reminder to open the adhkar, the Mushaf or the tasbih.',
                      ),
                      style: AppTypography.footnote
                          .copyWith(color: context.palette.secondaryLabel),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  static Future<void> _fixNotifications(WidgetRef ref) async {
    final granted =
        await ref.read(localNotificationsProvider).requestPermission();
    ref.invalidate(adhanPermissionsProvider);
    if (granted) {
      await ref.read(reminderProvider.notifier).reschedule();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await ref.read(fajrCallPlatformProvider).openAppSettings();
    }
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// What the notification looks like on the lock screen: the hilal on
/// mosque green, the app name, its category and time, title and body.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.kind, required this.at});

  final ReminderKind kind;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final arabic = context.isArabic;
    final meta = AppTypography.caption1.copyWith(color: c.secondaryLabel);
    return Semantics(
      label: context.tr('معاينة الإشعار', 'Notification preview'),
      child: AnimatedSwitcher(
        duration: AppMotion.standard,
        child: Container(
          key: ValueKey(kind),
          padding: const EdgeInsets.all(AppSpacing.ms),
          decoration: BoxDecoration(
            color: c.secondaryGroupedBackground,
            borderRadius: BorderRadius.circular(AppRadius.large + 6),
            border: Border.all(color: c.separator, width: AppSpacing.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: LocalNotifications.accent,
                  borderRadius: BorderRadius.circular(AppRadius.medium - 2),
                ),
                padding: const EdgeInsets.all(8),
                child: CustomPaint(painter: HilalPainter(c.gold)),
              ),
              const SizedBox(width: AppSpacing.ms),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(context.tr('إحسان', 'Ihsan'),
                            style: meta.copyWith(
                                color: c.accent, fontWeight: FontWeight.w600)),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            ReminderText.category(kind, arabic: arabic),
                            style: meta,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        if (at != null)
                          Text(_clock(at!),
                              style: AppTypography.tabular(meta),
                              textDirection: TextDirection.ltr),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ReminderText.title(kind, arabic: arabic),
                      style: AppTypography.headline.copyWith(color: c.label),
                    ),
                    Text(
                      ReminderText.body(kind, arabic: arabic),
                      style: AppTypography.subheadline
                          .copyWith(color: c.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every reminder in the order of the day, on a gold rail. The ones the
/// chosen frequency sends are lit beads; the rest stay hollow and say
/// which frequency adds them.
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.frequency, required this.times});

  final ReminderFrequency frequency;
  final Map<ReminderKind, DateTime> times;

  String _when(BuildContext context, ReminderKind k) => switch (k) {
        ReminderKind.morningAdhkar =>
          context.tr('بعد الفجر، قبل الشروق', 'After Fajr, before sunrise'),
        ReminderKind.kahf =>
          context.tr('يوم الجمعة، في الضحى', 'Friday morning'),
        ReminderKind.midday => context.tr('بعد الظهر', 'After Dhuhr'),
        ReminderKind.salawat =>
          context.tr('يوم الجمعة، بعد الصلاة', 'Friday, after Jumuah'),
        ReminderKind.eveningAdhkar =>
          context.tr('بعد العصر، قبل المغرب', 'After Asr, before Maghrib'),
        ReminderKind.mulk => context.tr('بعد العشاء', 'After Isha'),
        ReminderKind.sleepAdhkar => context.tr('قبل النوم', 'Before sleep'),
      };

  @override
  Widget build(BuildContext context) {
    const kinds = ReminderKind.values;
    return Column(
      children: [
        for (var i = 0; i < kinds.length; i++)
          _TimelineRow(
            kind: kinds[i],
            sent: kinds[i].sentAt(frequency),
            addedBy: frequency == ReminderFrequency.off
                ? null
                : RemindersSettingsScreen.frequencyLabel(
                    context, kinds[i].from),
            when: _when(context, kinds[i]),
            at: times[kinds[i]],
            first: i == 0,
            last: i == kinds.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.kind,
    required this.sent,
    required this.addedBy,
    required this.when,
    required this.at,
    required this.first,
    required this.last,
  });

  final ReminderKind kind;
  final bool sent;

  /// The frequency that would add it (shown when it isn't sent).
  final String? addedBy;
  final String when;
  final DateTime? at;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final arabic = context.isArabic;
    const bead = 14.0;
    const rail = 28.0;
    return Semantics(
      container: true,
      label: '${ReminderText.title(kind, arabic: arabic)}, $when'
          '${at != null ? ', ${_clock(at!)}' : ''}, '
          '${sent ? context.tr('مفعّل', 'on') : context.tr('غير مفعّل', 'off')}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: rail,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // The rail: gold, broken above the first bead and below
                  // the last.
                  Positioned(
                    top: first ? 22 : 0,
                    bottom: last ? null : 0,
                    height: last ? 22 : null,
                    child: Container(
                        width: 1.5, color: c.gold.withValues(alpha: 0.55)),
                  ),
                  Positioned(
                    top: 22 - bead / 2,
                    child: AnimatedContainer(
                      duration: AppMotion.standard,
                      curve: Curves.easeOutCubic,
                      width: bead,
                      height: bead,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sent
                            ? c.accent
                            : c.groupedBackground,
                        border: Border.all(
                          color: sent ? c.gold : c.tertiaryLabel,
                          width: sent ? 2 : 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AnimatedOpacity(
                duration: AppMotion.standard,
                opacity: sent ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ReminderText.title(kind, arabic: arabic),
                              style: AppTypography.callout.copyWith(
                                color: c.label,
                                fontWeight:
                                    sent ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            Text(
                              !sent && addedBy != null
                                  ? context.tr('$when. يُضاف مع «$addedBy»',
                                      '$when. Added with “$addedBy”')
                                  : when,
                              style: AppTypography.footnote
                                  .copyWith(color: c.secondaryLabel),
                            ),
                          ],
                        ),
                      ),
                      if (at != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _clock(at!),
                            textDirection: TextDirection.ltr,
                            style: AppTypography.tabular(
                              AppTypography.subheadline.copyWith(
                                color: sent ? c.label : c.secondaryLabel,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
