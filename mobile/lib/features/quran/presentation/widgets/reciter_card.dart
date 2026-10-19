import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/reciter.dart';

/// Displays a single Quran reciter entry.
///
/// Shows the reciter name, an active-playback indicator, and a play/select
/// button. Tapping anywhere opens the Surah selection / player.
class ReciterCard extends StatelessWidget {
  const ReciterCard({
    super.key,
    required this.reciter,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
  });

  final Reciter reciter;

  /// Whether this reciter is the currently loaded one.
  final bool isActive;

  /// Whether audio is actively playing (used to animate the icon).
  final bool isPlaying;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActiveLight = isActive
        ? AppColors.primaryContainer
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);

    return LahumaCard(
      onTap: onTap,
      color: isActiveLight,
      border:
          isActive ? Border.all(color: AppColors.primary, width: 1.5) : null,
      shadow: [
        BoxShadow(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
          blurRadius: isActive ? 20 : 8,
          offset: const Offset(0, 4),
        ),
      ],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Row(
        children: [
          // ── Microphone / reciter icon badge ─────────────────────────────
          _ReciterIconBadge(isActive: isActive, isPlaying: isPlaying),
          const SizedBox(width: AppSpacing.md),

          // ── Name + subtitle ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reciter.displayName,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.primary
                        : (isDark ? AppColors.textDark : AppColors.textLight),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reciter.name} • ${context.tr('انقر لعرض قائمة التلاوات', 'Tap to see recitations')}',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: isActive
                        ? AppColors.inkMedium
                        : (isDark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight),
                  ),
                ),
              ],
            ),
          ),

          // ── Active indicator / chevron ───────────────────────────────────
          if (isActive)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: AppColors.primary,
                semanticLabel: isPlaying ? 'Pause' : 'Play',
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
              size: 20,
            ),
        ],
      ),
    );
  }
}

// ─── Icon badge ──────────────────────────────────────────────────────────────

class _ReciterIconBadge extends StatefulWidget {
  const _ReciterIconBadge({required this.isActive, required this.isPlaying});

  final bool isActive;
  final bool isPlaying;

  @override
  State<_ReciterIconBadge> createState() => _ReciterIconBadgeState();
}

class _ReciterIconBadgeState extends State<_ReciterIconBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ReciterIconBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isPlaying && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: widget.isActive
                ? [AppColors.primary, AppColors.primaryDark]
                : [const Color(0xFFDDF5F3), const Color(0xFFB8EBE8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: 0.2 + _pulse.value * 0.2,
                    ),
                    blurRadius: 12 + _pulse.value * 8,
                    spreadRadius: _pulse.value * 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          Icons.mic_rounded,
          size: 22,
          color: widget.isActive ? Colors.white : AppColors.inkMedium,
          semanticLabel: 'Quran reciter',
        ),
      ),
    );
  }
}
