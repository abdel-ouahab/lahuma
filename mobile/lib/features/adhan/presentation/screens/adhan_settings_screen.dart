import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../fajr_call/presentation/fajr_call_providers.dart';
import '../../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../../prayer_times/domain/prayer_times.dart';
import '../../../prayer_times/presentation/prayer_times_providers.dart';
import '../../domain/adhan_settings.dart';
import '../../domain/muezzin.dart';
import '../adhan_foreground.dart';
import '../adhan_playback.dart';
import '../adhan_providers.dart';

/// الأذان: on/off, the muezzin (with previews), the five prayers and the
/// reminder before each. Settings → الصلاة → الأذان.
class AdhanSettingsScreen extends ConsumerWidget {
  const AdhanSettingsScreen({super.key});

  static const String path = '/settings/adhan';

  /// Key the preview player uses for the bundled adhan.
  static const String _defaultKey = 'default';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adhanProvider);
    final notifier = ref.read(adhanProvider.notifier);
    final playback = ref.watch(adhanPlaybackProvider);
    final player = ref.read(adhanPlaybackProvider.notifier);
    final hasTimes = ref.watch(upcomingPrayerDaysProvider).isNotEmpty;
    final perms = ref.watch(adhanPermissionsProvider).valueOrNull ??
        const AdhanPermissions();
    final settings = state.settings;
    final arabic = context.isArabic;

    Future<void> enable(bool on) async {
      await notifier.setEnabled(on);
      if (on && context.mounted) await _askPermissions(context, ref);
    }

    Future<void> select(Muezzin m) async {
      if (state.downloadingId != null) return;
      if (m.id == settings.muezzinId && state.download?.version == m.version) {
        return;
      }
      final ok = await notifier.select(m);
      if (!context.mounted) return;
      if (!ok) {
        AppToast.show(
          context,
          context.tr('تعذّر تنزيل الأذان. سيُرفع الأذان الافتراضي.',
              "Couldn't download the adhan. The default one will play."),
          icon: CupertinoIcons.exclamationmark_circle,
        );
        return;
      }
      if (!settings.enabled) {
        await enable(true);
      }
    }

    Future<void> pickReminder() async {
      final minutes = await showAppActionSheet<int>(
        context,
        title: context.tr('تذكير قبل الصلاة', 'Reminder before prayer'),
        message: context.tr('«اقترب وقت صلاة …»', '"Prayer is coming up"'),
        cancelLabel: context.tr('إلغاء', 'Cancel'),
        actions: [
          for (final m in adhanReminderOptions)
            AppSheetAction(
              label: _reminderLabel(context, m),
              value: m,
              isDefault: m == settings.reminderMinutes,
            ),
        ],
      );
      if (minutes != null) await notifier.setReminder(minutes);
    }

    Future<void> pickTest() async {
      final prayer = await showAppActionSheet<PrayerKind>(
        context,
        title: context.tr('تجربة الأذان', 'Test the adhan'),
        message: context.tr('اختر الصلاة', 'Pick a prayer'),
        cancelLabel: context.tr('إلغاء', 'Cancel'),
        actions: [
          for (final p in adhanPrayers)
            AppSheetAction(label: arabic ? p.ar : p.en, value: p),
        ],
      );
      if (prayer == null || !context.mounted) return;
      ref.read(adhanForegroundProvider).test(prayer);
      // The notification too, as at a real prayer time (if allowed).
      final n = ref.read(localNotificationsProvider);
      if (await n.areEnabled() || await n.requestPermission()) {
        await notifier.notifyTest(AdhanForeground.testIdFor(prayer), prayer,
            AdhanForeground.testDelay);
      }
      if (!context.mounted) return;
      AppToast.show(
        context,
        context.tr('سيُرفع أذان ${prayer.ar} بعد 10 ثوانٍ',
            '${prayer.en} adhan in 10 seconds'),
        icon: CupertinoIcons.timer,
      );
    }

    return AppScaffold.largeTitle(
      title: context.tr('الأذان', 'Adhan'),
      onRefresh: notifier.refreshList,
      slivers: [
        if (!state.loaded)
          const SliverFillRemaining(child: AppLoader())
        else ...[
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              footer: context.tr(
                'يُرفع الأذان داخل التطبيق في وقت كل صلاة حسب موقعك، إذا كان التطبيق مفتوحاً. وإلا يصلك إشعار صامت، اضغطه للاستماع.',
                'The adhan plays in the app at each prayer time for your location, while the app is open. Otherwise you get a silent notification; tap it to listen.',
              ),
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.speaker_2_fill,
                      color: AppColors.tileGreen),
                  title: context.tr('تشغيل الأذان', 'Play the adhan'),
                  trailing:
                      AppSwitch(value: settings.enabled, onChanged: enable),
                ),
                if (settings.enabled && !hasTimes)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.location_fill,
                        color: AppColors.tileOrange),
                    title: context.tr('حدّد موقعك', 'Set your location'),
                    subtitle: context.tr('لا نعرف أوقات الصلاة بعد.',
                        "Prayer times aren't known yet."),
                    onTap: () => PrayerSettingsSheet.show(context),
                  ),
                if (settings.enabled && !perms.notifications)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.bell_slash_fill,
                        color: AppColors.tileRed),
                    title:
                        context.tr('الإشعارات متوقفة', 'Notifications are off'),
                    subtitle: context.tr(
                        'لن يصلك تنبيه بوقت الصلاة والتطبيق مغلق. اضغط لتفعيلها.',
                        "You won't be told it's prayer time while the app is closed. Tap to turn them on."),
                    onTap: () => _fixNotifications(context, ref),
                  ),
                if (settings.enabled && !perms.exact)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.alarm_fill,
                        color: AppColors.tileOrange),
                    title: context.tr(
                        'قد يتأخر الإشعار', 'The notification may be late'),
                    subtitle: context.tr(
                        'اسمح بالمنبّهات والتذكيرات ليصل في وقته.',
                        'Allow alarms & reminders so it arrives on time.'),
                    onTap: () => ref
                        .read(localNotificationsProvider)
                        .requestExactAlarms(),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              header: context.tr('المؤذن', 'Muezzin'),
              hasLeading: true,
              footer: context.tr(
                'يُنزَّل صوت المؤذن مرة واحدة ليعمل الأذان دون إنترنت.',
                'The muezzin is downloaded once so the adhan works offline.',
              ),
              children: [
                _MuezzinRow(
                  title: context.tr('الأذان الافتراضي', 'Default adhan'),
                  subtitle:
                      context.tr('مضمّن في التطبيق', 'Built into the app'),
                  selected: settings.muezzinId == null,
                  previewing: playback.isActive(_defaultKey),
                  previewLoading:
                      playback.key == _defaultKey && playback.loading,
                  onPreview: () => player.toggle(_defaultKey,
                      asset: adhanDefaultAsset(fajr: false)),
                  onTap:
                      settings.muezzinId == null ? null : notifier.useDefault,
                ),
                for (final m in state.muezzins)
                  _MuezzinRow(
                    title: m.name(arabic),
                    subtitle: _status(context, state, m),
                    selected: m.id == settings.muezzinId,
                    progress:
                        state.downloadingId == m.id ? state.progress : null,
                    previewing: playback.isActive(m.id),
                    previewLoading: playback.key == m.id && playback.loading,
                    onPreview: () => player.toggle(m.id, url: m.regularUrl),
                    onTap: () => select(m),
                  ),
                if (state.muezzins.isEmpty && state.listLoading)
                  AppListTile(
                    title:
                        context.tr('جارٍ تحميل المؤذنين…', 'Loading muezzins…'),
                    trailing: const CupertinoActivityIndicator(),
                  ),
                if (state.listFailed)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.wifi_exclamationmark,
                        color: AppColors.tileRed),
                    title: context.tr(
                        'تعذّر تحميل المؤذنين', "Couldn't load the muezzins"),
                    subtitle:
                        context.tr('اضغط لإعادة المحاولة', 'Tap to try again'),
                    onTap: notifier.refreshList,
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              header: context.tr('الصلوات', 'Prayers'),
              children: [
                for (final p in adhanPrayers)
                  AppListTile(
                    title: arabic ? p.ar : p.en,
                    trailing: AppSwitch(
                      value: settings.prayers.contains(p),
                      onChanged: (on) => notifier.setPrayer(p, on),
                    ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.bell_fill,
                      color: AppColors.tileIndigo),
                  title:
                      context.tr('تذكير قبل الصلاة', 'Reminder before prayer'),
                  value: _reminderLabel(context, settings.reminderMinutes),
                  onTap: pickReminder,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AppListSection(
              hasLeading: true,
              footer: context.tr(
                'يُرفع الأذان داخل التطبيق بعد 10 ثوانٍ. أبقِ التطبيق مفتوحاً.',
                'The adhan plays in the app in 10 seconds. Keep the app open.',
              ),
              children: [
                AppListTile(
                  leading: const AppIconTile(
                      icon: CupertinoIcons.play_fill,
                      color: AppColors.tileBlue),
                  title: context.tr('تجربة الأذان', 'Test the adhan'),
                  onTap: pickTest,
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ],
    );
  }

  String _status(BuildContext context, AdhanState state, Muezzin m) {
    if (state.downloadingId == m.id) {
      return context.tr('جارٍ التنزيل… ${(state.progress * 100).round()}٪',
          'Downloading… ${(state.progress * 100).round()}%');
    }
    if (state.failedId == m.id) {
      return context.tr('فشل التنزيل · اضغط لإعادة المحاولة',
          'Download failed · Tap to try again');
    }
    final flag = _flag(m.country);
    if (m.id == state.settings.muezzinId) {
      final ready = state.download?.version == m.version;
      return '$flag ${ready ? context.tr('مُنزَّل', 'Downloaded') : context.tr('بانتظار التنزيل', 'Waiting to download')}'
          .trim();
    }
    return flag;
  }

  /// "DZ" → 🇩🇿.
  static String _flag(String country) {
    if (country.length != 2) return '';
    final up = country.toUpperCase();
    return String.fromCharCodes(
        [for (final c in up.codeUnits) 0x1F1E6 + c - 0x41]);
  }

  static String _reminderLabel(BuildContext context, int minutes) {
    if (minutes == 0) return context.tr('متوقف', 'Off');
    return context.tr(
        '$minutes ${minutes <= 10 ? 'دقائق' : 'دقيقة'}', '$minutes min');
  }

  /// Asked when the adhan is turned on, not at launch: notifications, then
  /// (Android 12+) exact alarms so the adhan isn't late.
  static Future<void> _askPermissions(
      BuildContext context, WidgetRef ref) async {
    final n = ref.read(localNotificationsProvider);
    if (!await n.areEnabled() && !await n.requestPermission()) {
      if (context.mounted) _notificationsOffToast(context);
      ref.invalidate(adhanPermissionsProvider);
      return;
    }
    if (!await n.canScheduleExact() && context.mounted) {
      final go = await showAppDialog<bool>(
        context,
        title: context.tr('الأذان في وقته تمامًا', 'Adhan right on time'),
        message: context.tr(
          'اسمح للتطبيق بضبط المنبّهات حتى لا يتأخر الأذان بضع دقائق.',
          'Allow alarms so the adhan is not a few minutes late.',
        ),
        actions: [
          AppDialogAction(label: context.tr('لاحقًا', 'Later'), value: false),
          AppDialogAction(
              label: context.tr('السماح', 'Allow'),
              value: true,
              isDefault: true),
        ],
      );
      if (go == true) await n.requestExactAlarms();
    }
    ref.invalidate(adhanPermissionsProvider);
    await ref.read(adhanProvider.notifier).reschedule();
  }

  /// The warning row: the prompt while the system still shows it, else the
  /// app's settings page (Android) or a hint (iOS).
  static Future<void> _fixNotifications(
      BuildContext context, WidgetRef ref) async {
    final granted =
        await ref.read(localNotificationsProvider).requestPermission();
    ref.invalidate(adhanPermissionsProvider);
    if (granted) {
      await ref.read(adhanProvider.notifier).reschedule();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await ref.read(fajrCallPlatformProvider).openAppSettings();
    } else if (context.mounted) {
      _notificationsOffToast(context);
    }
  }

  static void _notificationsOffToast(BuildContext context) => AppToast.show(
        context,
        context.tr('فعّل الإشعارات من إعدادات الهاتف ليُرفع الأذان.',
            'Turn on notifications in Settings so the adhan can play.'),
        icon: CupertinoIcons.bell_slash,
      );
}

class _MuezzinRow extends StatelessWidget {
  const _MuezzinRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.previewing,
    required this.previewLoading,
    required this.onPreview,
    required this.onTap,
    this.progress,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool previewing;
  final bool previewLoading;
  final VoidCallback onPreview;
  final VoidCallback? onTap;

  /// 0…1 while downloading.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AppListTile(
      leading: SizedBox.square(
        dimension: 30,
        child: previewLoading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(30),
                onPressed: onPreview,
                child: Semantics(
                  label: previewing
                      ? context.tr('إيقاف الاستماع', 'Stop preview')
                      : context.tr('استمع إلى $title', 'Listen to $title'),
                  child: Icon(
                    previewing
                        ? CupertinoIcons.stop_circle_fill
                        : CupertinoIcons.play_circle_fill,
                    size: 30,
                    color: c.accent,
                  ),
                ),
              ),
      ),
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      onTap: onTap,
      chevron: false,
      trailing: progress != null
          ? SizedBox(width: 56, child: AppProgressBar(value: progress!))
          : selected
              ? Icon(CupertinoIcons.checkmark_alt, color: c.accent)
              : null,
    );
  }
}
