import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/fajr_contact.dart';
import '../fajr_call_providers.dart';
import '../widgets/awake_toggle.dart';
import '../widgets/fajr_call_labels.dart';

/// Opens the phone app with [phone] ready to call.
typedef Dialer = Future<bool> Function(String phone);

final dialerProvider = Provider<Dialer>((ref) => (phone) =>
    launchUrl(Uri(scheme: 'tel', path: phone)));

/// The wake list (manual mode and iOS): opened from the Fajr notification,
/// one tap calls a person, a tick marks them awake. Calls and ticks are
/// logged like the automatic ones.
class FajrWakeListScreen extends ConsumerWidget {
  const FajrWakeListScreen({super.key, required this.listId, this.firedAt});

  final String listId;

  /// The notification's fire time; identifies this morning's session.
  final DateTime? firedAt;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fajrCallProvider);
    final list = state.listById(listId);
    final c = context.palette;

    final done = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(AppSpacing.minTouchTarget),
      onPressed: () => _close(context),
      child: Text(context.tr('تم', 'Done'),
          style: AppTypography.headline.copyWith(color: c.accent)),
    );

    if (!state.loaded) {
      return AppScaffold(trailing: done, child: const AppLoader());
    }
    if (list == null) {
      return AppScaffold(
        trailing: done,
        child: AppEmptyState(
          icon: CupertinoIcons.sunrise,
          title: context.tr('القائمة غير موجودة', 'List not found'),
          message: context.tr('ربما حُذفت.', 'It may have been deleted.'),
        ),
      );
    }

    final at = firedAt ?? ref.read(fajrClockProvider)();
    final notifier = ref.read(fajrCallProvider.notifier);
    final session = notifier.wakeSession(list, at);
    final awake = session.awakeContactIds;

    Future<void> call(FajrContact contact) async {
      HapticFeedback.lightImpact();
      final opened = await ref.read(dialerProvider)(contact.phone);
      if (opened) {
        await notifier.logManualCall(notifier.wakeSession(list, at), contact);
      } else if (context.mounted) {
        AppToast.show(context,
            context.tr('تعذّر فتح تطبيق الهاتف', "Couldn't open the phone app"),
            icon: CupertinoIcons.exclamationmark_circle);
      }
    }

    return AppScaffold(
      // Opened from a notification, often with nothing behind it: "Done"
      // instead of a back chevron.
      navigationBar: AppNavBar(
        title: list.name,
        trailing: done,
        automaticallyImplyLeading: false,
      ),
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: AppSpacing.screenInsets,
            child: Column(
              children: [
                Icon(CupertinoIcons.sunrise_fill,
                    size: 44, color: c.resolve(AppColors.tileOrange)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr('حان وقت الفجر', "It's time for Fajr"),
                  textAlign: TextAlign.center,
                  style: AppTypography.title2.copyWith(color: c.label),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.tr(
                    'اتصل بكل واحد منهم، ثم علّم من استيقظ.',
                    'Call each of them, then tick who is awake.',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.subheadline
                      .copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppListSection(
            footer: context.tr(
              'لعلّ اتصالك يكون سببًا في صلاة.',
              'Your call may be the reason they pray.',
            ),
            children: [
              for (final contact in list.contacts)
                _WakeRow(
                  contact: contact,
                  called: session.attempts.any(
                      (a) => a.contact.id == contact.id && a.status.isCall),
                  awake: awake.contains(contact.id),
                  onCall: () => call(contact),
                  onAwake: (v) => notifier.markAwake(
                      notifier.wakeSession(list, at), contact,
                      awake: v),
                ),
            ],
          ),
          if (list.contacts.isNotEmpty &&
              list.contacts.every((p) => awake.contains(p.id)))
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                context.tr('استيقظوا جميعًا. تقبّل الله منك ومنهم.',
                    'Everyone is awake. May Allah accept from you and them.'),
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(color: c.success),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _WakeRow extends StatelessWidget {
  const _WakeRow({
    required this.contact,
    required this.called,
    required this.awake,
    required this.onCall,
    required this.onAwake,
  });

  final FajrContact contact;
  final bool called;
  final bool awake;
  final VoidCallback onCall;
  final ValueChanged<bool> onAwake;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md, AppSpacing.ms, AppSpacing.xs, AppSpacing.ms),
      child: Row(
        children: [
          AppIconTile(
            icon: relationIcon(contact.relation),
            color: relationColor(contact.relation),
            size: 36,
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headline.copyWith(color: c.label)),
                LtrText(contact.phone,
                    style: AppTypography.footnote
                        .copyWith(color: c.secondaryLabel)),
                if (called)
                  Text(context.tr('اتصلت به', 'Called'),
                      style: AppTypography.caption1
                          .copyWith(color: c.secondaryLabel)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            container: true,
            button: true,
            label: context.tr('اتصل بـ ${contact.name}', 'Call ${contact.name}'),
            onTap: onCall,
            excludeSemantics: true,
            child: AppButton.tinted(
              label: context.tr('اتصال', 'Call'),
              icon: CupertinoIcons.phone_fill,
              small: true,
              onPressed: onCall,
            ),
          ),
          AwakeToggle(
              value: awake, onChanged: onAwake, name: contact.name, size: 30),
        ],
      ),
    );
  }
}
