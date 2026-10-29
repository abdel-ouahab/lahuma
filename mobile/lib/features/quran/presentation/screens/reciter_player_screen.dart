import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/reciter.dart';
import '../../domain/surah_audio.dart';
import '../providers/reciter_providers.dart';
import '../../../../core/design/widgets/app_states.dart' show AppSkeletonList;

/// Full-screen Quran audio player for a specific reciter.
///
/// Shows:
///   - Reciter name + Surah info
///   - Album-art style decorative visual
///   - Playback progress + time labels
///   - Play / Pause / Seek
///   - Surah list (tap to switch surah)
///   - Loading / error states
class ReciterPlayerScreen extends ConsumerStatefulWidget {
  const ReciterPlayerScreen({super.key, required this.reciterId});

  final String reciterId;

  @override
  ConsumerState<ReciterPlayerScreen> createState() =>
      _ReciterPlayerScreenState();
}

class _ReciterPlayerScreenState extends ConsumerState<ReciterPlayerScreen> {
  Reciter? _reciter;
  bool _loadingReciters = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _resolveReciter();
  }

  Future<void> _resolveReciter() async {
    try {
      final repo = ref.read(reciterRepositoryProvider);
      final reciters = await repo.getReciters();
      final match = reciters.cast<Reciter?>().firstWhere(
            (r) => r?.id == widget.reciterId,
            orElse: () => null,
          );
      if (mounted) {
        setState(() {
          _reciter = match;
          _loadingReciters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _loadingReciters = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    if (_loadingReciters) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_initError != null || _reciter == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: _buildAppBar(context, isDark, null),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('تعذّر تحميل بيانات القارئ',
                      'Could not load this reciter'),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                _BackButton(isDark: isDark),
              ],
            ),
          ),
        ),
      );
    }

    return _ReciterPlayerBody(reciter: _reciter!, isDark: isDark);
  }

  AppBar _buildAppBar(BuildContext context, bool isDark, String? title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? AppColors.textDark : AppColors.textLight,
          size: 18,
        ),
        onPressed: () => context.pop(),
        tooltip: context.tr('رجوع', 'Back'),
      ),
      title: title != null
          ? Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            )
          : null,
      centerTitle: true,
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _ReciterPlayerBody extends ConsumerWidget {
  const _ReciterPlayerBody({required this.reciter, required this.isDark});

  final Reciter reciter;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync = ref.watch(surahsForReciterProvider(reciter));
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.textDark : AppColors.textLight,
            size: 18,
          ),
          onPressed: () => context.pop(),
          tooltip: context.tr('رجوع', 'Back'),
        ),
        title: Text(
          reciter.displayName,
          style: GoogleFonts.scheherazadeNew(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
        ),
        centerTitle: true,
      ),
      body: surahsAsync.when(
        data: (surahs) {
          if (surahs.isEmpty) {
            return _NoSurahsState(isDark: isDark);
          }
          return _PlayerContent(
            reciter: reciter,
            surahs: surahs,
            isDark: isDark,
          );
        },
        loading: () => const AppSkeletonList(),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(surahsForReciterProvider(reciter)),
        ),
      ),
    );
  }
}

// ── Player content ────────────────────────────────────────────────────────────

class _PlayerContent extends ConsumerStatefulWidget {
  const _PlayerContent({
    required this.reciter,
    required this.surahs,
    required this.isDark,
  });

  final Reciter reciter;
  final List<SurahAudio> surahs;
  final bool isDark;

  @override
  ConsumerState<_PlayerContent> createState() => _PlayerContentState();
}

class _PlayerContentState extends ConsumerState<_PlayerContent> {
  late SurahAudio _selectedSurah;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Select the first available surah by default (or keep the active one).
    final activeSurah = ref.read(activeSurahAudioProvider);
    final activeReciter = ref.read(activeReciterProvider);
    _selectedSurah =
        (activeReciter?.id == widget.reciter.id && activeSurah != null)
            ? activeSurah
            : widget.surahs.firstWhere((s) => s.isAvailable,
                orElse: () => widget.surahs.first);
  }

  Future<void> _playSurah(SurahAudio surah) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedSurah = surah;
    });

    try {
      // play() claims audio focus, which stops the other players.
      ref.read(activeReciterProvider.notifier).state = widget.reciter;
      ref.read(activeSurahAudioProvider.notifier).state = surah;
      await ref.read(quranAudioServiceProvider).play(widget.reciter, surah);
    } catch (e) {
      if (mounted) {
        setState(() => _error = context.tr(
            'تعذّر تشغيل الملف الصوتي', 'Could not play this recitation'));
        _showError(context, _error!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerStateAsync = ref.watch(audioPlayerStateProvider);
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);
    final activeReciter = ref.watch(activeReciterProvider);
    final activeSurah = ref.watch(activeSurahAudioProvider);

    final isThisReciterActive = activeReciter?.id == widget.reciter.id;
    final isThisSurahActive = isThisReciterActive &&
        activeSurah?.surahNumber == _selectedSurah.surahNumber;

    final isPlaying = playerStateAsync.maybeWhen(
      data: (s) => s.playing && isThisSurahActive,
      orElse: () => false,
    );

    final isCompleted = playerStateAsync.maybeWhen(
      data: (s) =>
          s.processingState == ProcessingState.completed && isThisSurahActive,
      orElse: () => false,
    );

    final position = positionAsync.maybeWhen(
      data: (d) => isThisSurahActive ? d : Duration.zero,
      orElse: () => Duration.zero,
    );

    final duration = durationAsync.maybeWhen(
      data: (d) => isThisSurahActive ? (d ?? Duration.zero) : Duration.zero,
      orElse: () => Duration.zero,
    );

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // ── Album art / decorative visual ──────────────────────────────
            _AlbumArt(isDark: widget.isDark, isPlaying: isPlaying),
            const SizedBox(height: AppSpacing.xl),

            // ── Surah name ─────────────────────────────────────────────────
            Text(
              _selectedSurah.surahArabicName,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? AppColors.textDark : AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _selectedSurah.surahName,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Error banner ───────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Seek slider ────────────────────────────────────────────────
            _SeekSlider(
              position: position,
              duration: duration,
              progress: progress.toDouble(),
              isDark: widget.isDark,
              onSeek: (value) {
                if (duration.inMilliseconds > 0) {
                  final target = Duration(
                    milliseconds: (value * duration.inMilliseconds).round(),
                  );
                  ref.read(quranAudioServiceProvider).seek(target);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Playback controls ──────────────────────────────────────────
            _PlaybackControls(
              isPlaying: isPlaying,
              isLoading: _isLoading,
              isCompleted: isCompleted,
              isDark: widget.isDark,
              onPlay: () => _playSurah(_selectedSurah),
              onPause: () async {
                await ref.read(quranAudioServiceProvider).pause();
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Surah list ─────────────────────────────────────────────────
            if (widget.surahs.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  context.tr(
                      'السور المتاحة: ${widget.surahs.where((s) => s.isAvailable).length} من ${widget.surahs.length}',
                      '${widget.surahs.where((s) => s.isAvailable).length} of ${widget.surahs.length} surahs available'),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...widget.surahs.map((surah) {
                final isSelected =
                    surah.surahNumber == _selectedSurah.surahNumber;
                return _SurahListTile(
                  surah: surah,
                  isSelected: isSelected,
                  isPlaying: isSelected && isPlaying,
                  isDark: widget.isDark,
                  onTap: !surah.isAvailable
                      ? null
                      : () => isSelected && isPlaying
                          ? ref.read(quranAudioServiceProvider).pause()
                          : _playSurah(surah),
                );
              }),
            ],

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Album art ─────────────────────────────────────────────────────────────────

class _AlbumArt extends StatefulWidget {
  const _AlbumArt({required this.isDark, required this.isPlaying});
  final bool isDark;
  final bool isPlaying;

  @override
  State<_AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<_AlbumArt> with TickerProviderStateMixin {
  late final AnimationController _rotate;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _updateAnimations();
  }

  @override
  void didUpdateWidget(_AlbumArt old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) _updateAnimations();
  }

  void _updateAnimations() {
    if (widget.isPlaying) {
      _rotate.repeat();
      _pulse.repeat(reverse: true);
    } else {
      _rotate.stop();
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _rotate.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotate, _pulse]),
      builder: (_, __) {
        return Transform.rotate(
          angle: _rotate.value * 2 * 3.14159,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                  Color(0xFF0D6B64),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.25 + _pulse.value * 0.2,
                  ),
                  blurRadius: 30 + _pulse.value * 20,
                  spreadRadius: _pulse.value * 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 30,
                  semanticLabel: 'Quran reciter',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Seek slider ───────────────────────────────────────────────────────────────

class _SeekSlider extends StatelessWidget {
  const _SeekSlider({
    required this.position,
    required this.duration,
    required this.progress,
    required this.isDark,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final double progress;
  final bool isDark;
  final ValueChanged<double> onSeek;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: 'Seek bar',
          slider: true,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: progress,
              onChanged: onSeek,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(position),
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
                ),
              ),
              Text(
                _format(duration),
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Playback controls ─────────────────────────────────────────────────────────

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.isDark,
    required this.onPlay,
    required this.onPause,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool isCompleted;
  final bool isDark;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main play / pause button
        Semantics(
          label: isPlaying ? 'Pause' : 'Play',
          button: true,
          child: GestureDetector(
            onTap: isLoading ? null : (isPlaying ? onPause : onPlay),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      isCompleted
                          ? Icons.replay_rounded
                          : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      color: Colors.white,
                      size: 36,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Surah list tile ───────────────────────────────────────────────────────────

class _SurahListTile extends StatelessWidget {
  const _SurahListTile({
    required this.surah,
    required this.isSelected,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
  });

  final SurahAudio surah;
  final bool isSelected;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: surah.isAvailable ? 1 : 0.4,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.surfaceElevatedDark
                          : AppColors.primaryContainer),
                ),
                child: Center(
                  child: Text(
                    '${surah.surahNumber}',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  surah.surahArabicName,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textDark : AppColors.textLight),
                  ),
                ),
              ),
              if (isPlaying)
                const Icon(
                  Icons.equalizer_rounded,
                  color: AppColors.primary,
                  size: 20,
                  semanticLabel: 'Playing',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No surahs state ───────────────────────────────────────────────────────────

class _NoSurahsState extends StatelessWidget {
  const _NoSurahsState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audio_file_outlined,
                size: 60,
                color: isDark ? AppColors.mutedDark : AppColors.mutedLight),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('لا توجد سور متاحة لهذا القارئ',
                  'No surahs available for this reciter yet'),
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          context.tr('رجوع', 'Back'),
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
