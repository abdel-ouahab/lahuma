import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../localization/tr.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// "Now playing" bar that floats just above the tab bar (Music-app style):
/// translucent blurred bar material, hairline edge, no shadow. Tap the bar to
/// open the full player; the trailing buttons play / pause and, when
/// [onClose] is set, stop and dismiss the bar.
///
/// Its height is fixed so the shell can reserve [reservedHeight]; text inside
/// does not grow with Dynamic Type (like the bars around it).
class AppMiniPlayerBar extends StatelessWidget {
  const AppMiniPlayerBar({
    super.key,
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.onTap,
    required this.onTogglePlay,
    this.busy = false,
    this.progress,
    this.titleStyle,
    this.onClose,
  });

  /// 40 × 40 artwork / glyph.
  final Widget artwork;
  final String title;
  final String subtitle;
  final bool playing;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onTogglePlay;

  /// 0…1 playback position, drawn as a hairline along the bottom edge.
  final double? progress;

  /// Override for the title (e.g. Scheherazade for an Arabic surah name).
  final TextStyle? titleStyle;

  /// Stops playback; shows a close button after play / pause when set.
  final VoidCallback? onClose;

  static const double _barHeight = 56;
  static const double _margin = AppSpacing.sm;

  /// Space the shell reserves above the tab bar while the bar is visible.
  static const double reservedHeight = _barHeight + _margin * 2;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final radius = BorderRadius.circular(AppRadius.medium + 2);

    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: _margin, vertical: _margin),
        child: Semantics(
          container: true,
          button: true,
          label: '$title, $subtitle',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ClipRSuperellipse(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.barBackground,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: radius,
                      side: BorderSide(
                          color: c.separator, width: AppSpacing.hairline),
                    ),
                  ),
                  child: SizedBox(
                    height: _barHeight,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.sm,
                            end: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              ClipRSuperellipse(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.small),
                                child: SizedBox.square(
                                    dimension: 40, child: artwork),
                              ),
                              const SizedBox(width: AppSpacing.ms),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle ??
                                          AppTypography.subheadline
                                              .weight(FontWeight.w600)
                                              .copyWith(color: c.label),
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption1
                                          .copyWith(color: c.secondaryLabel),
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: playing
                                    ? context.tr('إيقاف مؤقت', 'Pause')
                                    : context.tr('تشغيل', 'Play'),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size.square(
                                      AppSpacing.minTouchTarget),
                                  onPressed: busy
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          onTogglePlay();
                                        },
                                  child: busy
                                      ? const CupertinoActivityIndicator()
                                      : Icon(
                                          playing
                                              ? CupertinoIcons.pause_fill
                                              : CupertinoIcons.play_fill,
                                          size: 24,
                                          color: c.label,
                                        ),
                                ),
                              ),
                              if (onClose != null)
                                Semantics(
                                  button: true,
                                  label: context.tr('إيقاف التشغيل', 'Stop'),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size.square(
                                        AppSpacing.minTouchTarget),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      onClose!();
                                    },
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 18,
                                      color: c.secondaryLabel,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (progress != null)
                          PositionedDirectional(
                            start: AppSpacing.ms,
                            end: AppSpacing.ms,
                            bottom: 0,
                            height: 2,
                            child: FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: progress!.clamp(0.0, 1.0),
                              child: ColoredBox(color: c.accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Default artwork for a recitation: accent gradient tile with a glyph.
class AppArtworkTile extends StatelessWidget {
  const AppArtworkTile({super.key, this.icon = CupertinoIcons.waveform});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: AppColors.heroGradient,
          ),
        ),
        child: Center(child: Icon(icon, size: 20, color: AppColors.onAccent)),
      );
}
