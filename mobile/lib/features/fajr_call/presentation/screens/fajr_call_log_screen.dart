import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/call_attempt.dart';
import '../../domain/call_session.dart';
import '../../domain/fajr_call_list.dart';
import '../../domain/fajr_contact.dart';
import '../fajr_call_providers.dart';
import '../widgets/awake_toggle.dart';
import '../widgets/fajr_call_labels.dart';

/// Results of one list: totals, then each morning with who was called and
/// who is awake. Ticking someone here counts them as awake, the same as on
/// the wake list.
class FajrCallLogScreen extends ConsumerWidget {
  const FajrCallLogScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fajrCallProvider);
    final sessions = state.sessionsOf(listId);
    final now = ref.watch(fajrClockProvider)();
    final c = context.palette;

    Future<void> clear() async {
      final ok = await showAppDialog<bool>(
        context,
        title: context.tr('مسح السجل؟', 'Clear the log?'),
        message: context.tr('لا يمكن التراجع عن ذلك.', "This can't be undone."),
        actions: [
          AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
          AppDialogAction(
              label: context.tr('مسح', 'Clear'),
              value: true,
              isDestructive: true),
        ],
      );
      if (ok == true) {
        await ref.read(fajrCallProvider.notifier).clearLog(listId: listId);
      }
    }

    final total = sessions.fold<int>(0, (n, s) => n + s.total);
    final awake = sessions.fold<int>(0, (n, s) => n + s.awake);
    // Woke up is counted in people, so it is shown against the people
    // reached, not against Calls (which counts every retry).
    final people = sessions.fold<int>(0, (n, s) => n + s.contacts.length);
    // Calls that ended before the ring timeout (picked up or declined),
    // plus any the call log confirmed as answered.
    final ended = sessions.fold<int>(0, (n, s) => n + s.ended + s.answered);
    final noAnswer = sessions.fold<int>(0, (n, s) => n + s.noAnswer);
    final failed = sessions.fold<int>(0, (n, s) => n + s.failed);

    return AppScaffold(
      title: context.tr('السجل', 'Log'),
      trailing: sessions.isEmpty
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppSpacing.minTouchTarget),
              onPressed: clear,
              child: Text(context.tr('مسح', 'Clear'),
                  style: AppTypography.body.copyWith(color: c.destructive)),
            ),
      child: sessions.isEmpty
          ? AppEmptyState(
              icon: CupertinoIcons.list_bullet,
              title: context.tr('لا شيء بعد', 'Nothing yet'),
              message: context.tr(
                  'بعد أول فجر ستجد هنا من اتصلت به ومن استيقظ.',
                  "After the first Fajr you'll see here who was called and who woke up."),
            )
          : ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screenInsets,
                  child: _Stats(
                    total: total,
                    awake: awake,
                    people: people,
                    ended: ended,
                    noAnswer: noAnswer,
                    failed: failed,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final s in sessions) _SessionSection(session: s, now: now),
                const SizedBox(height: AppSpacing.lg),
              ].listEntrance(),
            ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.total,
    required this.awake,
    required this.people,
    required this.ended,
    required this.noAnswer,
    required this.failed,
  });

  final int total;
  final int awake;
  final int people;
  final int ended;
  final int noAnswer;
  final int failed;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> tiles) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.ms),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
    return Column(
      children: [
        row([
          _StatTile(
              label: context.tr('الاتصالات', 'Calls'),
              value: total,
              icon: CupertinoIcons.phone_arrow_up_right,
              color: AppColors.tilePurple),
          _StatTile(
              label: context.tr('استيقظوا', 'Woke up'),
              value: awake,
              of: people,
              icon: CupertinoIcons.checkmark_circle_fill,
              color: AppColors.success),
        ]),
        const SizedBox(height: AppSpacing.ms),
        row([
          _StatTile(
              label: context.tr('انتهت', 'Ended'),
              value: ended,
              icon: CupertinoIcons.phone_fill,
              color: AppColors.tileBlue),
          _StatTile(
              label: context.tr('لم يردّوا', 'No answer'),
              value: noAnswer,
              icon: CupertinoIcons.phone_down_fill,
              color: AppColors.warning),
          _StatTile(
              label: context.tr('تعذّر', 'Failed'),
              value: failed,
              icon: CupertinoIcons.exclamationmark_circle_fill,
              color: AppColors.destructive),
        ]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.of,
  });

  final String label;
  final int value;

  /// Shows the value as "value/of" (e.g. 1/2 people awake).
  final int? of;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      container: true,
      label: of == null
          ? '$label: $value'
          : context.tr('$label: $value من $of', '$label: $value of $of'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.ms),
        decoration: ShapeDecoration(
          color: c.secondaryGroupedBackground,
          shape: AppRadius.continuous(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: c.resolve(color)),
            const SizedBox(height: AppSpacing.xs + 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$value'),
                  if (of != null)
                    TextSpan(
                        text: '/$of', style: TextStyle(color: c.tertiaryLabel)),
                ]),
                style: AppTypography.tabular(AppTypography.title2)
                    .copyWith(color: c.label),
              ),
            ),
            Text(label,
                style:
                    AppTypography.footnote.copyWith(color: c.secondaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _SessionSection extends ConsumerWidget {
  const _SessionSection({required this.session, required this.now});

  final CallSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awakeIds = session.awakeContactIds;
    final contacts = session.contacts;
    final header = [
      formatFire(context, session.firedAt, now),
      context.tr('استيقظ ${ltr('${awakeIds.length}/${contacts.length}')}',
          '${awakeIds.length}/${contacts.length} awake'),
      if (session.mode == FajrCallMode.manual) context.tr('يدوي', 'Manual'),
      if (session.stoppedByUser) context.tr('أُوقف', 'Stopped'),
    ].join(' · ');
    // "Call ended" can mean picked up or declined: without the call log the
    // app can't tell, so say so where it still matters (nobody ticked yet).
    final unsure = contacts.any((p) {
      if (awakeIds.contains(p.id)) return false;
      CallStatus? last;
      for (final a in session.attempts) {
        if (a.contact.id == p.id && a.status.isCall) last = a.status;
      }
      return last == CallStatus.called;
    });
    return AppListSection(
      header: header,
      footer: unsure
          ? context.tr(
              '«انتهت المكالمة» تعني أنه ردّ أو رفض قبل انتهاء الرنين. اضغط «استيقظ؟» إن تأكّدت أنه استيقظ.',
              '"Call ended" means they picked up or declined before the ring timeout. Tap "Awake?" once you know they are up.')
          : null,
      hasLeading: true,
      children: [
        for (final contact in contacts)
          _ContactResult(
            contact: contact,
            attempts: [
              for (final a in session.attempts)
                if (a.contact.id == contact.id && a.status.isCall) a,
            ],
            awake: awakeIds.contains(contact.id),
            onToggleAwake: (v) => ref
                .read(fajrCallProvider.notifier)
                .markAwake(session, contact, awake: v),
          ),
      ],
    );
  }
}

class _ContactResult extends StatelessWidget {
  const _ContactResult({
    required this.contact,
    required this.attempts,
    required this.awake,
    required this.onToggleAwake,
  });

  final FajrContact contact;
  final List<CallAttempt> attempts;
  final bool awake;
  final ValueChanged<bool> onToggleAwake;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final last = attempts.isEmpty ? null : attempts.last.status;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            statusIcon(
                awake ? CallStatus.markedAwake : last ?? CallStatus.called),
            size: 26,
            color: c.resolve(statusColor(
                awake ? CallStatus.markedAwake : last ?? CallStatus.called)),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: AppTypography.body.copyWith(color: c.label)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 2,
                  children: [
                    for (final a in attempts)
                      Semantics(
                        label:
                            '${statusLabel(context, a.status)} ${formatClock(context, a.startedAt)}',
                        excludeSemantics: true,
                        // One run of text, so a long label wraps instead
                        // of overflowing under large Dynamic Type.
                        child: Text.rich(
                          TextSpan(children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(statusIcon(a.status),
                                  size: 13,
                                  color: c.resolve(statusColor(a.status))),
                            ),
                            TextSpan(
                                text:
                                    ' ${formatClock(context, a.startedAt)} · ${statusLabel(context, a.status)}'),
                          ]),
                          style: AppTypography.footnote
                              .copyWith(color: c.secondaryLabel),
                        ),
                      ),
                    if (attempts.isEmpty)
                      Text(context.tr('لم يُتّصل به', 'Not called'),
                          style: AppTypography.footnote
                              .copyWith(color: c.secondaryLabel)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AwakeToggle(
              value: awake,
              onChanged: onToggleAwake,
              name: contact.name,
              showLabel: true),
        ],
      ),
    );
  }
}
