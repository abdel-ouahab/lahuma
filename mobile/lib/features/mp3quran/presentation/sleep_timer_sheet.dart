import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/audio/sleep_timer.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// `12:05`, or `1:02:05` from an hour up.
String formatSleepRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Bottom sheet for the Now Playing sleep timer: a few lengths, or the end
/// of the current surah. A pick starts the timer and closes the sheet; while
/// one runs the sheet shows the time left and a way to turn it off.
class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key, required this.timer});

  final SleepTimer timer;

  static const lengths = [5, 10, 15, 30, 45, 60];

  static Future<void> show(BuildContext context, SleepTimer timer) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (_) => SleepTimerSheet(timer: timer),
    );
  }

  static const _sheet = Color(0xF5072620);
  static const _gold = AppColors.toastAction;

  void _pick(BuildContext context, VoidCallback start) {
    HapticFeedback.selectionClick();
    start();
    Navigator.of(context).pop();
  }

  String _unit(BuildContext context, int minutes) => context.tr(
        minutes <= 10 ? 'دقائق' : 'دقيقة',
        'min',
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        final remaining = timer.remaining;
        final status = timer.endOfTrack
            ? context.tr('يتوقف التشغيل عند نهاية السورة',
                'Playback pauses when this surah ends')
            : remaining != null
                ? context.tr(
                    'يتوقف التشغيل بعد ${formatSleepRemaining(remaining)}',
                    'Playback pauses in ${formatSleepRemaining(remaining)}')
                : context.tr('اختر متى يتوقف التشغيل تلقائياً',
                    'Choose when playback pauses by itself');

        return Container(
          decoration: const BoxDecoration(
            color: _sheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, 10, AppSpacing.lg, AppSpacing.md + bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('مؤقت الإيقاف', 'Sleep timer'),
                  style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: timer.isActive
                          ? _gold
                          : Colors.white.withValues(alpha: 0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: AppSpacing.sm + 2,
                  crossAxisSpacing: AppSpacing.sm + 2,
                  childAspectRatio: 1.55,
                  children: [
                    for (final m in lengths)
                      _Tile(
                        selected: timer.chosen == Duration(minutes: m),
                        label: context.tr('$m دقيقة', '$m minutes'),
                        onTap: () => _pick(
                            context, () => timer.start(Duration(minutes: m))),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$m',
                                style: GoogleFonts.cairo(
                                    fontSize: 22,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            Text(_unit(context, m),
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    height: 1.2,
                                    color:
                                        Colors.white.withValues(alpha: 0.65))),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                SizedBox(
                  height: 56,
                  child: _Tile(
                    selected: timer.endOfTrack,
                    label: context.tr('نهاية السورة', 'End of surah'),
                    onTap: () => _pick(context, timer.startEndOfTrack),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_bottom_rounded,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: AppSpacing.sm),
                        Text(context.tr('نهاية السورة', 'End of surah'),
                            style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                if (timer.isActive) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      timer.cancel();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      context.tr('إيقاف المؤقت', 'Turn off timer'),
                      style: GoogleFonts.cairo(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // The InkWell's own tap action is excluded with its text.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: selected ? 0.1 : 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? SleepTimerSheet._gold
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}
