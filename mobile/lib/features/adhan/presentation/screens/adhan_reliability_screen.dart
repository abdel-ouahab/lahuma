import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../data/adhan_alarm_platform.dart';
import '../adhan_providers.dart';

/// "ضمان رفع الأذان": what Android needs for the adhan to play with the app
/// closed (notifications, exact alarms, no battery optimisation), and the
/// manual steps the big phone makers' battery savers need. Android only;
/// reached from the adhan settings.
class AdhanReliabilityScreen extends ConsumerWidget {
  const AdhanReliabilityScreen({super.key});

  static const String path = '/settings/adhan/reliability';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(adhanPermissionsProvider).valueOrNull;
    final native = ref.read(adhanAlarmPlatformProvider);
    final n = ref.read(localNotificationsProvider);
    final maker = perms?.reliability.maker ?? PhoneMaker.other;

    Future<void> after(Future<void> action) async {
      await action;
      ref.invalidate(adhanPermissionsProvider);
      await ref.read(adhanProvider.notifier).reschedule();
    }

    Future<void> battery() async {
      if (await askToRunInBackground(context, native)) {
        ref.invalidate(adhanPermissionsProvider);
        await ref.read(adhanProvider.notifier).reschedule();
      }
    }

    Future<void> openMaker(PhoneMaker m) async {
      final opened = await native.openMakerSettings(m);
      if (!opened && context.mounted) {
        AppToast.show(
          context,
          context.tr('فُتحت إعدادات التطبيق. اتبع الخطوات من هناك.',
              'App settings opened instead. Follow the steps from there.'),
          icon: CupertinoIcons.info,
        );
      }
    }

    final makers = [
      if (maker != PhoneMaker.other) maker,
      for (final m in PhoneMaker.values)
        if (m != maker && m != PhoneMaker.other) m,
    ];

    return AppScaffold.largeTitle(
      title: context.tr('ضمان رفع الأذان', 'Make sure the adhan plays'),
      slivers: [
        SliverToBoxAdapter(
          child: AppListSection(
            header: context.tr('الأذونات', 'Permissions'),
            hasLeading: true,
            footer: context.tr(
              'يُرفع الأذان بصوت الإشعارات، فتأكد أن صوت الإشعارات ليس منخفضاً. الوضع الصامت و«عدم الإزعاج» يكتمانه.',
              'The adhan plays at notification volume, so keep it up. Silent mode and Do Not Disturb mute it.',
            ),
            children: [
              _CheckRow(
                ok: perms?.notifications ?? true,
                title: context.tr('الإشعارات', 'Notifications'),
                hint: context.tr('لزر الإيقاف أثناء الأذان',
                    'For the Stop button while it plays'),
                onFix: () => after(n.requestPermission()),
              ),
              _CheckRow(
                ok: perms?.exact ?? true,
                title: context.tr('المنبّهات والتذكيرات', 'Alarms & reminders'),
                hint: context.tr(
                    'ليُرفع في وقته تماماً', 'So it plays right on time'),
                onFix: () => after(n.requestExactAlarms()),
              ),
              _CheckRow(
                ok: perms?.battery ?? true,
                title: context.tr('بلا قيود على البطارية', 'No battery limits'),
                hint: context.tr(
                    'ليعمل والتطبيق مغلق', 'So it works with the app closed'),
                onFix: battery,
              ),
            ],
          ),
        ),
        for (final m in makers)
          SliverToBoxAdapter(
            child: AppListSection(
              header: m == maker
                  ? context.tr('هاتفك: ${_name(m, true)}',
                      'Your phone: ${_name(m, false)}')
                  : _name(m, context.isArabic),
              children: [
                _Steps(steps: _steps(context, m)),
                AppListTile(
                  title: context.tr('افتح الإعدادات', 'Open settings'),
                  onTap: () => openMaker(m),
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: AppListSection(
            footer: context.tr(
              'للتأكد: من صفحة الأذان جرّب الأذان، ثم أغلق التطبيق من قائمة التطبيقات الأخيرة وانتظر.',
              'To check: test the adhan from the adhan page, then close the app from Recents and wait.',
            ),
            children: [
              AppListTile(
                title: context.tr('إعدادات التطبيق', 'App settings'),
                onTap: native.openAppSettings,
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  static String _name(PhoneMaker m, bool arabic) => switch (m) {
        PhoneMaker.xiaomi =>
          arabic ? 'شاومي · ريدمي · بوكو' : 'Xiaomi · Redmi · POCO',
        PhoneMaker.oppo =>
          arabic ? 'أوبو · ريلمي · ون بلس' : 'Oppo · Realme · OnePlus',
        PhoneMaker.huawei => arabic ? 'هواوي · أونر' : 'Huawei · Honor',
        PhoneMaker.samsung => arabic ? 'سامسونج' : 'Samsung',
        PhoneMaker.other => arabic ? 'هواتف أخرى' : 'Other phones',
      };

  static List<String> _steps(BuildContext context, PhoneMaker m) => switch (m) {
        PhoneMaker.xiaomi => [
            context.tr(
                'الإعدادات ← التطبيقات ← إحسان ← التشغيل التلقائي: فعّله.',
                'Settings → Apps → Ihsan → Autostart: on.'),
            context.tr('ثم «توفير البطارية»: اختر «بلا قيود».',
                'Then Battery saver: choose "No restrictions".'),
            context.tr(
                'في التطبيقات الأخيرة، اضغط مطولاً على «إحسان» واختر القفل.',
                'In Recents, long-press Ihsan and lock it.'),
          ],
        PhoneMaker.oppo => [
            context.tr(
                'الإعدادات ← البطارية ← إحسان: اسمح بالنشاط في الخلفية والتشغيل التلقائي.',
                'Settings → Battery → Ihsan: allow background activity and auto launch.'),
            context.tr('«تحسين استخدام البطارية»: لا تحسّن «إحسان».',
                'Optimise battery use: don\'t optimise Ihsan.'),
            context.tr(
                'في التطبيقات الأخيرة، اضغط ⋮ على «إحسان» واختر «قفل». لا يمكن القفل و«وضع توفير الطاقة» مفعّل.',
                'In Recents, tap ⋮ on Ihsan and choose Lock. Apps can\'t be locked while Power saving mode is on.'),
            context.tr(
                'لا تسحب «إحسان» لإغلاقه من التطبيقات الأخيرة: هذا يوقفه بالكامل فلا يُرفع الأذان حتى تفتحه من جديد.',
                'Don\'t swipe Ihsan away from Recents: that fully stops it, and no adhan plays until you open it again.'),
          ],
        PhoneMaker.huawei => [
            context.tr(
                'الإعدادات ← البطارية ← تشغيل التطبيقات ← إحسان: اختر الإدارة اليدوية.',
                'Settings → Battery → App launch → Ihsan: manage manually.'),
            context.tr(
                'فعّل التشغيل التلقائي والتشغيل الثانوي والتشغيل في الخلفية.',
                'Turn on auto-launch, secondary launch and run in background.'),
            context.tr(
                'في التطبيقات الأخيرة، اقفل «إحسان».', 'In Recents, lock Ihsan.'),
          ],
        PhoneMaker.samsung => [
            context.tr('الإعدادات ← التطبيقات ← إحسان ← البطارية: «غير مقيّد».',
                'Settings → Apps → Ihsan → Battery: Unrestricted.'),
            context.tr(
                'العناية بالجهاز ← البطارية ← حدود الاستخدام في الخلفية: أزل «إحسان» من التطبيقات النائمة، وأضفه إلى «التطبيقات التي لا تنام أبداً».',
                'Device care → Battery → Background usage limits: remove Ihsan from sleeping apps and add it to "Never sleeping apps".'),
          ],
        PhoneMaker.other => const [],
      };
}

/// Android: why the adhan needs to run in the background, then the system
/// "stop optimising battery usage?" dialog. True when the user went on to
/// it (the system dialog's own answer isn't reported back).
Future<bool> askToRunInBackground(
    BuildContext context, AdhanAlarmPlatform native) async {
  final go = await showAppDialog<bool>(
    context,
    title: context.tr('العمل في الخلفية', 'Run in the background'),
    message: context.tr(
      'ليُرفع الأذان والتطبيق مغلق، يحتاج تطبيق «إحسان» أن يعمل في الخلفية: في وقت كل صلاة يظهر إشعار ويُرفع الأذان بصوت الإشعارات. اختر «السماح» في النافذة التالية. لا يزيد هذا من استهلاك البطارية إلا وقت الأذان.',
      'To play the adhan with the app closed, Ihsan needs to run in the background: at each prayer time a notification appears and the adhan plays at notification volume. Choose "Allow" in the next window. The app only wakes at prayer times.',
    ),
    actions: [
      AppDialogAction(label: context.tr('لاحقًا', 'Later'), value: false),
      AppDialogAction(
          label: context.tr('متابعة', 'Continue'),
          value: true,
          isDefault: true),
    ],
  );
  if (go != true) return false;
  await native.requestIgnoreBatteryOptimizations();
  return true;
}

/// A requirement: a tick when met, otherwise a tappable fix.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.title,
    required this.hint,
    required this.onFix,
  });

  final bool ok;
  final String title;
  final String hint;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: AppIconTile(
        icon:
            ok ? CupertinoIcons.checkmark_alt : CupertinoIcons.exclamationmark,
        color: ok ? AppColors.tileGreen : AppColors.tileOrange,
      ),
      title: title,
      subtitle:
          ok ? hint : context.tr('اضغط للسماح · $hint', 'Tap to allow · $hint'),
      onTap: ok ? null : onFix,
    );
  }
}

/// Numbered manual steps.
class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final style = AppTypography.subheadline.copyWith(color: c.label);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
              child: Text('${i + 1}. ${steps[i]}', style: style),
            ),
        ],
      ),
    );
  }
}
