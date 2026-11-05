import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'adhan_reliability_screen.dart';

/// The hidden "adhan in 1 minute" row: shown in debug builds, or after a
/// long press on "Test the adhan".
final adhanDebugUnlockedProvider = StateProvider<bool>((ref) => kDebugMode);

/// الأذان: on/off, the muezzin (with previews), each prayer's mode (adhan,
/// silent notification, off) and the reminder before each.
/// Settings → الصلاة → الأذان.
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
    final android = defaultTargetPlatform == TargetPlatform.android;
    final debug = ref.watch(adhanDebugUnlockedProvider);
    final anyAdhan =
        adhanPrayers.any((p) => settings.modeOf(p) == AdhanMode.adhan);

    Future<void> enable(bool on) async {
      await notifier.setEnabled(on);
      if (on && context.mounted) await _askPermissions(context, ref);
    }

    Future<void> select(Muezzin m) async {
      if (state.downloadingId != null) return;
      if (m.id == settings.muezzinId && state.download?.version == m.version) {
        return;
      }
      // What still plays if this download fails.
      final previous = state.download != null ? state.selected : null;
      final ok = await notifier.select(m);
      if (!context.mounted) return;
      if (!ok) {
        AppToast.show(
          context,
          previous != null
              ? context.tr(
                  'تعذّر تنزيل الأذان. يبقى «${previous.name(true)}».',
                  "Couldn't download the adhan. "
                      '“${previous.name(false)}” stays.')
              : context.tr('تعذّر تنزيل الأذان. سيُرفع الأذان الافتراضي.',
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

    Future<void> pickMode(PrayerKind prayer) async {
      final mode = await showAppActionSheet<AdhanMode>(
        context,
        title: arabic ? prayer.ar : prayer.en,
        cancelLabel: context.tr('إلغاء', 'Cancel'),
        actions: [
          for (final m in AdhanMode.values)
            AppSheetAction(
              label: _modeLabel(context, m),
              value: m,
              isDefault: m == settings.modeOf(prayer),
            ),
        ],
      );
      if (mode != null) await notifier.setMode(prayer, mode);
    }

    /// [delay] 10 s from the row, 1 min from the hidden debug row.
    Future<void> test(PrayerKind prayer, Duration delay) async {
      // The notification (Android: the player's Stop button) needs it.
      final n = ref.read(localNotificationsProvider);
      final allowed = await n.areEnabled() || await n.requestPermission();
      var native = false;
      if (allowed) {
        native = await notifier.notifyTest(
            AdhanForeground.testIdFor(prayer), prayer, delay);
      }
      // No alarm engine (iOS): the app plays it, if still open by then.
      if (!native) ref.read(adhanForegroundProvider).test(prayer, delay: delay);
      if (!context.mounted) return;
      final minute = delay >= const Duration(minutes: 1);
      final when = minute
          ? context.tr('بعد دقيقة', 'in 1 minute')
          : context.tr('بعد 10 ثوانٍ', 'in 10 seconds');
      AppToast.show(
        context,
        native
            ? context.tr('سيُرفع أذان ${prayer.ar} $when، ولو أغلقت التطبيق',
                '${prayer.en} adhan $when, even if you close the app')
            : context.tr(
                'سيُرفع أذان ${prayer.ar} $when', '${prayer.en} adhan $when'),
        icon: CupertinoIcons.timer,
      );
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
      await test(prayer, AdhanForeground.testDelay);
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
              footer: android
                  ? context.tr(
                      'يُرفع الأذان كاملاً في وقت كل صلاة حسب موقعك، ولو كان التطبيق مغلقاً أو بعد إعادة تشغيل الهاتف. أوقفه من الإشعار.',
                      'The full adhan plays at each prayer time for your location, even with the app closed or after a restart. Stop it from the notification.',
                    )
                  : context.tr(
                      'في وقت كل صلاة يصلك إشعار بمقطع من الأذان (30 ثانية)؛ اضغطه لسماعه كاملاً. وإذا كان التطبيق مفتوحاً يُرفع كاملاً.',
                      'At each prayer time a notification plays the first 30 seconds of the adhan; tap it for the full adhan. With the app open, the full adhan plays.',
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
                    title: context.tr('قد يتأخر الأذان أو لا يُرفع',
                        'The adhan may be late or not play'),
                    subtitle: context.tr(
                        'اسمح بالمنبّهات والتذكيرات ليُرفع في وقته.',
                        'Allow alarms & reminders so it plays on time.'),
                    onTap: () => ref
                        .read(localNotificationsProvider)
                        .requestExactAlarms(),
                  ),
                if (settings.enabled && anyAdhan && android && !perms.battery)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.battery_25,
                        color: AppColors.tileOrange),
                    title: context.tr('توفير البطارية قد يمنع الأذان',
                        'Battery saving may stop the adhan'),
                    subtitle: context.tr('اضغط لترى ما يلزم هاتفك.',
                        'Tap to see what your phone needs.'),
                    onTap: () => context.push(AdhanReliabilityScreen.path),
                  ),
                if (settings.enabled && android)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.checkmark_shield_fill,
                        color: AppColors.tileTeal),
                    title: context.tr(
                        'ضمان رفع الأذان', 'Make sure the adhan plays'),
                    onTap: () => context.push(AdhanReliabilityScreen.path),
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
                    // The downloaded file when there is one, so it plays
                    // offline; otherwise streamed from the server.
                    onPreview: () => player.toggle(m.id,
                        file: state.download?.muezzinId == m.id &&
                                state.download?.version == m.version
                            ? state.download!.files[AdhanSoundKind.regular]
                            : null,
                        url: m.regularUrl),
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
                    value: _modeLabel(context, settings.modeOf(p)),
                    onTap: () => pickMode(p),
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
              footer: android
                  ? context.tr(
                      'يُرفع الأذان بعد 10 ثوانٍ، ولو أغلقت التطبيق.',
                      'The adhan plays in 10 seconds, even if you close the app.',
                    )
                  : context.tr(
                      'يُرفع الأذان داخل التطبيق بعد 10 ثوانٍ. أبقِ التطبيق مفتوحاً.',
                      'The adhan plays in the app in 10 seconds. Keep the app open.',
                    ),
              children: [
                // A long press unlocks the debug row below.
                GestureDetector(
                  onLongPress: () => ref
                      .read(adhanDebugUnlockedProvider.notifier)
                      .state = true,
                  child: AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.play_fill,
                        color: AppColors.tileBlue),
                    title: context.tr('تجربة الأذان', 'Test the adhan'),
                    onTap: pickTest,
                  ),
                ),
                if (debug)
                  AppListTile(
                    leading: const AppIconTile(
                        icon: CupertinoIcons.ant_fill,
                        color: AppColors.tileIndigo),
                    title: context.tr(
                        'اختبار: الأذان بعد دقيقة', 'Debug: adhan in 1 minute'),
                    subtitle: context.tr(
                        'أغلق التطبيق وانتظر', 'Close the app and wait'),
                    onTap: () =>
                        test(PrayerKind.dhuhr, AdhanForeground.debugDelay),
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

  static String _modeLabel(BuildContext context, AdhanMode mode) =>
      switch (mode) {
        AdhanMode.adhan => context.tr('أذان', 'Adhan'),
        AdhanMode.silent => context.tr('إشعار صامت', 'Silent notification'),
        AdhanMode.off => context.tr('متوقف', 'Off'),
      };

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
    // Android: the user confirms running in the background, so the adhan
    // plays with the app closed.
    final native = ref.read(adhanAlarmPlatformProvider);
    if (native.supported &&
        !(await native.reliability()).ignoringBatteryOptimizations &&
        context.mounted) {
      await askToRunInBackground(context, native);
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
