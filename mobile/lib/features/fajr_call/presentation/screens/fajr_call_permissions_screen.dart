import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../fajr_call_providers.dart';

/// Step-by-step checklist (notifications → calls → exact alarms →
/// battery). Each step explains why before the system prompt, and ticks
/// update live when the user comes back from system settings. Nothing here
/// is mandatory: without call permissions lists run in manual mode.
class FajrCallPermissionsScreen extends ConsumerStatefulWidget {
  const FajrCallPermissionsScreen({super.key, this.firstRun = false});

  /// Shown right after the first list was switched on.
  final bool firstRun;

  @override
  ConsumerState<FajrCallPermissionsScreen> createState() =>
      _FajrCallPermissionsScreenState();
}

class _FajrCallPermissionsScreenState
    extends ConsumerState<FajrCallPermissionsScreen>
    with WidgetsBindingObserver {
  bool? _notifications;
  bool? _exact;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(StorageKeys.fajrCallPermissionsShown, true));
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final n = ref.read(localNotificationsProvider);
    final notifications = await n.areEnabled();
    final exact = await n.canScheduleExact();
    await ref.read(fajrCallProvider.notifier).refreshPermissions();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _exact = exact;
    });
  }

  Future<void> _askNotifications() async {
    await ref.read(localNotificationsProvider).requestPermission();
    await _check();
  }

  Future<void> _askExact() async {
    await ref.read(localNotificationsProvider).requestExactAlarms();
    await _check();
  }

  Future<void> _askCalls() async {
    await ref.read(fajrCallProvider.notifier).requestCallPermissions();
    await _check();
  }

  Future<void> _askBattery() async {
    await ref
        .read(fajrCallPlatformProvider)
        .requestIgnoreBatteryOptimizations();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fajrCallProvider);
    final p = state.permissions;
    final c = context.palette;
    final calls = _android && state.autoSupported;

    return AppScaffold(
      title: context.tr('الأذونات', 'Permissions'),
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenMargin + AppSpacing.xs,
                0,
                AppSpacing.screenMargin,
                AppSpacing.md),
            child: Text(
              context.tr(
                'ليعمل نداء الفجر في وقته والهاتف مقفل، يحتاج التطبيق بعض الأذونات. كلها اختيارية، ويمكنك تغييرها لاحقًا.',
                'For Fajr Call to work on time with the phone locked, the app needs a few permissions. All are optional and can be changed later.',
              ),
              style:
                  AppTypography.subheadline.copyWith(color: c.secondaryLabel),
            ),
          ),
          _Step(
            number: 1,
            title: context.tr('الإشعارات', 'Notifications'),
            body: context.tr(
              'لتنبيهك عند الفجر، ولإظهار الاتصال الجاري مع زر الإيقاف.',
              'To alert you at Fajr, and to show the ongoing calls with a Stop button.',
            ),
            done: _notifications,
            action: context.tr('السماح', 'Allow'),
            onAction: _askNotifications,
          ),
          if (calls)
            _Step(
              number: 2,
              title: context.tr('المكالمات', 'Phone calls'),
              body: context.tr(
                'للاتصال بمن في القائمة تلقائيًا ومتابعة كل مكالمة وإنهائها بعد مدة الرنين. لا يقرأ التطبيق مكالماتك الأخرى.',
                'To call the people on your list, follow each call and hang up after the ring time. The app does not read your other calls.',
              ),
              done: p.canAutoCall,
              detail: p.canAutoCall && !p.answerCalls
                  ? context.tr(
                      'لم يُسمح بإنهاء المكالمة: سيرنّ الهاتف حتى تنتهي المكالمة من الشبكة.',
                      "Hanging up wasn't allowed: calls will ring until the network ends them.")
                  : null,
              action: context.tr('السماح', 'Allow'),
              onAction: _askCalls,
            ),
          if (_android)
            _Step(
              number: calls ? 3 : 2,
              title: context.tr('المنبّهات الدقيقة', 'Alarms & reminders'),
              body: context.tr(
                'ليبدأ النداء في الدقيقة نفسها لا بعدها بدقائق. ستفتح صفحة الإعدادات: فعّل «السماح بضبط المنبّهات والتذكيرات».',
                'So the call starts on the minute, not minutes late. Settings will open: turn on "Allow setting alarms and reminders".',
              ),
              done: _exact,
              action: context.tr('فتح الإعدادات', 'Open settings'),
              onAction: _askExact,
            ),
          if (calls)
            _Step(
              number: 4,
              title: context.tr('البطارية', 'Battery'),
              body: context.tr(
                'بعض الهواتف (شاومي، أوبو، سامسونج، إنفينكس، تكنو) توقف التطبيقات ليلًا. اسمح للتطبيق بالعمل دون قيود، وفعّل «التشغيل التلقائي» إن وُجد في إعدادات التطبيق.',
                'Some phones (Xiaomi, Oppo, Samsung, Infinix, Tecno) stop apps at night. Let the app run unrestricted, and turn on "Autostart" in the app settings if your phone has it.',
              ),
              done: p.ignoringBatteryOptimizations,
              action: context.tr('السماح', 'Allow'),
              onAction: _askBattery,
              secondary: context.tr('إعدادات التطبيق', 'App settings'),
              onSecondary: () =>
                  ref.read(fajrCallPlatformProvider).openAppSettings(),
            ),
          if (!calls && _android)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                context.tr(
                  'الاتصال التلقائي غير متاح على هذا الجهاز بعد، فتعمل القوائم بالتنبيه وقائمة الاتصال.',
                  'Automatic calling is not available on this device yet, so lists use the reminder and call list.',
                ),
                style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
              ),
            ),
          if (widget.firstRun)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton.filled(
                label: context.tr('تم', 'Done'),
                expand: true,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/home/fajr-call'),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ].listEntrance(),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.done,
    required this.action,
    required this.onAction,
    this.detail,
    this.secondary,
    this.onSecondary,
  });

  final int number;
  final String title;
  final String body;

  /// Null while checking.
  final bool? done;
  final String action;
  final VoidCallback onAction;
  final String? detail;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final ok = done ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.ms),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: ShapeDecoration(
          color: c.secondaryGroupedBackground,
          shape: AppRadius.continuous(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label:
                  '$title: ${ok ? context.tr('مسموح', 'allowed') : context.tr('غير مسموح', 'not allowed')}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ok ? c.success : c.tertiaryFill,
                      shape: BoxShape.circle,
                    ),
                    child: done == null
                        ? const CupertinoActivityIndicator(radius: 7)
                        : ok
                            ? Icon(CupertinoIcons.checkmark_alt,
                                size: 18, color: c.onAccent)
                            : LtrText('$number',
                                style: AppTypography.footnote
                                    .weight(FontWeight.w600)
                                    .copyWith(color: c.label)),
                  ),
                  const SizedBox(width: AppSpacing.ms),
                  Expanded(
                    child: Text(title,
                        style: AppTypography.headline.copyWith(color: c.label)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body,
                style: AppTypography.subheadline
                    .copyWith(color: c.secondaryLabel)),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(detail!,
                  style: AppTypography.footnote.copyWith(color: c.warning)),
            ],
            if (!ok || onSecondary != null) ...[
              const SizedBox(height: AppSpacing.ms),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (!ok)
                    AppButton.tinted(
                        label: action, small: true, onPressed: onAction),
                  if (secondary != null && onSecondary != null)
                    AppButton.plain(
                        label: secondary!, small: true, onPressed: onSecondary),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
