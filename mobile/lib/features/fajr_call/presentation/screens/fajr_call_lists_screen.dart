import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/fajr_call_list.dart';
import '../fajr_call_providers.dart';
import '../widgets/fajr_call_labels.dart';
import '../widgets/lantern_mark.dart';
import '../widgets/prayer_settings_sheet.dart';

/// Fajr Call home: every list with its next call and an on/off switch.
class FajrCallListsScreen extends ConsumerWidget {
  const FajrCallListsScreen({super.key});

  static const String path = '/home/fajr-call';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fajrCallProvider);
    final notifier = ref.read(fajrCallProvider.notifier);
    final now = ref.watch(fajrClockProvider)();

    Future<void> toggle(FajrCallList list, bool on) async {
      await notifier.setEnabled(list.id, on);
      if (!context.mounted || !on) return;
      if (list.startMode == FajrStartMode.fajr && !state.prayer.hasLocation) {
        await PrayerSettingsSheet.show(context);
      }
      final prefs = await SharedPreferences.getInstance();
      final shown =
          prefs.getBool(StorageKeys.fajrCallPermissionsShown) ?? false;
      if (context.mounted && !shown) {
        await context.push('$path/permissions?first=1');
      }
    }

    return AppScaffold.largeTitle(
      title: context.tr('نداء الفجر', 'Fajr Call'),
      trailing: AppIconButton(
        icon: CupertinoIcons.plus,
        label: context.tr('قائمة جديدة', 'New list'),
        onPressed: () => context.push('$path/new'),
      ),
      slivers: [
        if (!state.loaded)
          const SliverFillRemaining(child: AppLoader())
        else if (state.lists.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(onCreate: () => context.push('$path/new')),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenMargin + AppSpacing.xs,
                  0,
                  AppSpacing.screenMargin,
                  AppSpacing.sm),
              child: Text(
                context.tr(
                  'لعلّ اتصالًا منك يكون سببًا في صلاة.',
                  'A call from you may be the reason someone prays.',
                ),
                style: AppTypography.subheadline
                    .copyWith(color: context.palette.secondaryLabel),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              children: [
                for (final list in state.lists)
                  _ListRow(
                    list: list,
                    subtitle: _subtitle(context, ref, list, now),
                    onTap: () => context.push('$path/${list.id}'),
                    onToggle: (on) => toggle(list, on),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              header: context.tr('الإعدادات', 'Settings'),
              hasLeading: true,
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.location_fill,
                      color: AppColors.tileBlue),
                  title: context.tr('الموقع وطريقة الحساب', 'Location & method'),
                  value: state.prayer.hasLocation
                      ? state.prayer.placeName
                      : context.tr('غير محدد', 'Not set'),
                  onTap: () => PrayerSettingsSheet.show(context),
                ),
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.lock_shield_fill,
                      color: AppColors.tileGreen),
                  title: context.tr('الأذونات', 'Permissions'),
                  onTap: () => context.push('$path/permissions'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _subtitle(
      BuildContext context, WidgetRef ref, FajrCallList list, DateTime now) {
    final people = peopleCount(context, list.contacts.length);
    if (!list.enabled) return '${context.tr('متوقفة', 'Off')} · $people';
    if (list.contacts.isEmpty) {
      return context.tr('أضف شخصًا واحدًا على الأقل', 'Add at least one person');
    }
    final next = ref.watch(fajrNextFireProvider(list.id));
    if (next == null) {
      return list.startMode == FajrStartMode.fajr
          ? context.tr('حدّد موقعك لحساب وقت الفجر',
              'Set your location to work out Fajr')
          : context.tr('لا موعد قادم', 'Nothing scheduled');
    }
    return '${formatFire(context, next, now)} · $people';
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.list,
    required this.subtitle,
    required this.onTap,
    required this.onToggle,
  });

  final FajrCallList list;
  final String subtitle;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: AppIconTile(
        icon: list.startMode == FajrStartMode.fajr
            ? CupertinoIcons.sunrise_fill
            : CupertinoIcons.alarm_fill,
        color: list.enabled ? AppColors.tileOrange : AppColors.tileIndigo,
      ),
      title: list.name.isEmpty ? context.tr('بلا اسم', 'Untitled') : list.name,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Semantics(
        label: context.tr('تفعيل ${list.name}', 'Turn on ${list.name}'),
        child: AppSwitch(value: list.enabled, onChanged: onToggle),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LanternMark(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.tr('أيقظ والديك للفجر', 'Wake your parents for Fajr'),
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(color: c.label),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              'اختر من تحب، وعند الفجر يتصل بهم التطبيق واحدًا تلو الآخر. لعلّ اتصالك يكون سببًا في صلاة.',
              'Choose the people you love. At Fajr the app calls them one by one. Your call may be the reason they pray.',
            ),
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.filled(
            label: context.tr('جهّز أول قائمة', 'Set up your first list'),
            icon: CupertinoIcons.plus,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
