import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../prayer_times/domain/prayer_times.dart';
import '../../data/adhan_scheduler.dart';
import '../../domain/muezzin.dart';
import '../adhan_playback.dart';
import '../adhan_providers.dart';

/// Opened by tapping an adhan notification: plays the full-length adhan
/// (the downloaded file, or the bundled one) with a large stop button.
class AdhanPlayerScreen extends ConsumerStatefulWidget {
  const AdhanPlayerScreen({super.key, required this.prayer});

  final PrayerKind prayer;

  static const String path = AdhanScheduler.playRoute;

  @override
  ConsumerState<AdhanPlayerScreen> createState() => _AdhanPlayerScreenState();
}

class _AdhanPlayerScreenState extends ConsumerState<AdhanPlayerScreen> {
  static const String _key = AdhanScheduler.playRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Opened from a cold start: the download record may still be loading.
    await ref.read(adhanProvider.notifier).ready;
    if (!mounted) return;
    final fajr = widget.prayer == PrayerKind.fajr;
    final file = ref
        .read(adhanProvider)
        .download
        ?.files[AdhanSoundKind.full(fajr: fajr)];
    await ref.read(adhanPlaybackProvider.notifier).play(
          _key,
          file: file,
          asset: adhanDefaultAsset(fajr: fajr),
        );
  }

  Future<void> _stop() async {
    await ref.read(adhanPlaybackProvider.notifier).stop();
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final playback = ref.watch(adhanPlaybackProvider);
    final muezzin = ref.watch(adhanProvider.select((s) => s.selected));
    final arabic = context.isArabic;
    final prayer = arabic ? widget.prayer.ar : widget.prayer.en;
    final playing = playback.isActive(_key);

    return AppScaffold(
      // Opened from a notification, often with nothing behind it: "Done"
      // instead of a back chevron.
      navigationBar: AppNavBar(
        automaticallyImplyLeading: false,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
          onPressed: _stop,
          child: Text(context.tr('تم', 'Done'),
              style: AppTypography.headline.copyWith(color: c.accent)),
        ),
      ),
      child: SafeArea(
        // Spread out as designed when it fits; scrolls in landscape and
        // with large text.
        child: AppFillScroll(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                widget.prayer == PrayerKind.fajr
                    ? CupertinoIcons.sunrise_fill
                    : CupertinoIcons.speaker_3_fill,
                size: 72,
                color: c.accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.tr(
                    'حان الآن وقت صلاة $prayer', "It's time for $prayer"),
                textAlign: TextAlign.center,
                style: AppTypography.title1.copyWith(color: c.label),
              ),
              if (widget.prayer == PrayerKind.fajr) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr(
                      'الصلاة خير من النوم', 'Prayer is better than sleep'),
                  textAlign: TextAlign.center,
                  style: AppTypography.title3.copyWith(color: c.secondaryLabel),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                muezzin?.name(arabic) ??
                    context.tr('الأذان الافتراضي', 'Default adhan'),
                textAlign: TextAlign.center,
                style:
                    AppTypography.subheadline.copyWith(color: c.secondaryLabel),
              ),
              const Spacer(),
              if (playback.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    context.tr('تعذّر تشغيل الأذان', "Couldn't play the adhan"),
                    style:
                        AppTypography.footnote.copyWith(color: c.destructive),
                  ),
                ),
              AppButton.filled(
                label: playing
                    ? context.tr('إيقاف الأذان', 'Stop the adhan')
                    : context.tr('إغلاق', 'Close'),
                icon: playing ? CupertinoIcons.stop_fill : CupertinoIcons.xmark,
                expand: true,
                onPressed: _stop,
              ),
              if (!playing && !playback.loading) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton.plain(
                  label: context.tr('استمع مرة أخرى', 'Play again'),
                  icon: CupertinoIcons.play_fill,
                  onPressed: _start,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
