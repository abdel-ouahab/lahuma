import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/audio/audio_focus.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/design/widgets/app_entrance.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/design/widgets/app_mini_player.dart';
import '../../quran/presentation/providers/quran_providers.dart';
import '../domain/mp3quran_models.dart';
import 'mp3quran_providers.dart';

/// Lists the Surahs the chosen Moshaf really has and plays them.
///
/// Two surfaces share one playback controller: a library view (this screen)
/// and a full-screen "Now Playing" view opened from the bar at the bottom.
class Mp3QuranPlayerScreen extends ConsumerWidget {
  const Mp3QuranPlayerScreen(
      {super.key, required this.reciterId, required this.moshafId});

  final int reciterId;
  final int moshafId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mp3RecitersProvider);
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
            error: e, onRetry: () => ref.invalidate(mp3RecitersProvider)),
      ),
      data: (reciters) {
        Mp3Reciter? reciter;
        for (final r in reciters) {
          if (r.id == reciterId) reciter = r;
        }
        final moshaf = reciter?.moshafById(moshafId);
        if (reciter == null || moshaf == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                  context.tr('التلاوة غير متاحة', 'Recitation unavailable'),
                  style: GoogleFonts.cairo()),
            ),
          );
        }
        return _PlayerBody(reciter: reciter, moshaf: moshaf);
      },
    );
  }
}

// ── Design tokens ────────────────────────────────────────────────────────────

/// Monochrome slate palette (171C26 · 6C7689 · A4AAB7 · FFFFFF) with a
/// dark-mode counterpart.
class _Pal {
  const _Pal({
    required this.bg,
    required this.bgEdge,
    required this.surface,
    required this.chip,
    required this.ink,
    required this.sub,
    required this.mute,
    required this.onInk,
  });

  final Color bg;
  final Color bgEdge;
  final Color surface;
  final Color chip;
  final Color ink; // primary text and the filled "accent" surfaces
  final Color sub;
  final Color mute;
  final Color onInk; // content drawn on top of [ink]

  static const light = _Pal(
    bg: Color(0xFFF4F6FA),
    bgEdge: Color(0xFFE9EDF4),
    surface: Color(0xFFFFFFFF),
    chip: Color(0xFFECEEF3),
    ink: Color(0xFF171C26),
    sub: Color(0xFF6C7689),
    mute: Color(0xFFA4AAB7),
    onInk: Color(0xFFFFFFFF),
  );

  static const dark = _Pal(
    bg: Color(0xFF0C0F15),
    bgEdge: Color(0xFF0C0F15),
    surface: Color(0xFF171C26),
    chip: Color(0xFF212733),
    ink: Color(0xFFF4F6FA),
    sub: Color(0xFF9AA3B2),
    mute: Color(0xFF5C6575),
    onInk: Color(0xFF171C26),
  );

  static _Pal of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Inter for Latin/digits; Cairo picks up the Arabic glyphs Inter lacks.
TextStyle _inter(double size, FontWeight weight, Color color,
    {double? height, double? letterSpacing}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  ).copyWith(fontFamilyFallback: [GoogleFonts.cairo().fontFamily!]);
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Rebuilds with the player's live (playing, busy) flags.
class _PlaybackBuilder extends StatelessWidget {
  const _PlaybackBuilder({
    required this.controller,
    required this.state,
    required this.builder,
  });

  final Mp3PlaybackController controller;
  final Mp3PlaybackState state;
  final Widget Function(BuildContext context, bool playing, bool busy) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: controller.player.playerStateStream,
      builder: (context, snap) {
        final ps = snap.data;
        final busy = state.status == Mp3PlaybackStatus.loading ||
            ps?.processingState == ProcessingState.loading ||
            ps?.processingState == ProcessingState.buffering;
        final playing = (ps?.playing ?? false) &&
            ps?.processingState != ProcessingState.completed;
        return builder(context, playing, busy);
      },
    );
  }
}

// ── Library view ─────────────────────────────────────────────────────────────

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({required this.reciter, required this.moshaf});

  final Mp3Reciter reciter;
  final Mp3Moshaf moshaf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = _Pal.of(context);
    final state = ref.watch(mp3PlaybackProvider(moshaf));
    final controller = ref.read(mp3PlaybackProvider(moshaf).notifier);
    final names = ref.watch(mp3SuwarProvider).valueOrNull ?? const {};
    String nameOf(int n) => names[n] ?? context.tr('سورة $n', 'Surah $n');

    // Hand playback to the app-wide mini player so it survives leaving this
    // screen.
    final session = Mp3Session(reciter, moshaf);
    if (state.surah != null && ref.read(mp3SessionProvider) != session) {
      Future.microtask(
          () => ref.read(mp3SessionProvider.notifier).state = session);
    }

    // The tab shell reports the tab bar and mini-player as bottom padding;
    // the list scrolls behind both and its last row stays reachable.
    final listBottom = MediaQuery.paddingOf(context).bottom + AppSpacing.md;

    return Scaffold(
      backgroundColor: pal.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pal.bg, pal.bgEdge],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: context.tr('رجوع', 'Back'),
                      icon: Icon(Icons.chevron_left_rounded,
                          size: 30, color: pal.ink),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _LibraryHeader(
                      pal: pal,
                      reciter: reciter,
                      moshaf: moshaf,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _ActionRow(
                      pal: pal,
                      controller: controller,
                      state: state,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (state.status == Mp3PlaybackStatus.error)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      child: Text(
                        state.error == 'unavailable'
                            ? context.tr('هذه السورة غير متوفرة لهذه التلاوة',
                                'This surah is not available for this recitation')
                            : context.tr(
                                'تعذّر تشغيل التلاوة. تحقق من الاتصال وأعد المحاولة.',
                                'Could not play this recitation. Check your connection and try again.'),
                        style: _inter(12, FontWeight.w500, AppColors.error),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, listBottom),
                      itemCount: moshaf.surahNumbers.length,
                      itemBuilder: (_, i) {
                        final n = moshaf.surahNumbers[i];
                        return _TrackTile(
                          pal: pal,
                          index: i + 1,
                          title: nameOf(n),
                          subtitle: reciter.name,
                          active: state.surah == n,
                          onTap: () => controller.playSurah(n),
                        ).listEntrance(i);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.pal,
    required this.reciter,
    required this.moshaf,
  });

  final _Pal pal;
  final Mp3Reciter reciter;
  final Mp3Moshaf moshaf;

  @override
  Widget build(BuildContext context) {
    final count = moshaf.surahNumbers.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _Artwork(size: 112, radius: 22, shadow: false),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('$count سورة', '$count surahs'),
                style: _inter(12, FontWeight.w500, pal.sub),
              ),
              const SizedBox(height: 4),
              Text(
                reciter.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _inter(24, FontWeight.w800, pal.ink,
                    height: 1.2, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                moshaf.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _inter(13, FontWeight.w500, pal.sub, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.pal,
    required this.controller,
    required this.state,
  });

  final _Pal pal;
  final Mp3PlaybackController controller;
  final Mp3PlaybackState state;

  @override
  Widget build(BuildContext context) {
    return _PlaybackBuilder(
      controller: controller,
      state: state,
      builder: (context, playing, busy) {
        return Row(
          children: [
            Expanded(
              child: _PillButton(
                label: playing
                    ? context.tr('إيقاف مؤقت', 'Pause')
                    : context.tr('تشغيل', 'Play'),
                icon: playing
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                background: pal.ink,
                foreground: pal.onInk,
                onTap: controller.togglePlay,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: _PillButton(
                label: context.tr('عشوائي', 'Shuffle'),
                icon: Icons.shuffle_rounded,
                background: pal.chip,
                foreground: pal.ink,
                onTap: () {
                  controller.shuffle.value = true;
                  controller.playRandom();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                Text(label, style: _inter(14, FontWeight.w600, foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.pal,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final _Pal pal;
  final int index;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? pal.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: active
                      ? Icon(Icons.equalizer_rounded,
                          size: 20, color: pal.ink, semanticLabel: 'Playing')
                      : Text(
                          index.toString().padLeft(2, '0'),
                          style: _inter(13, FontWeight.w600, pal.sub),
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _inter(
                            15,
                            active ? FontWeight.w700 : FontWeight.w600,
                            pal.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _inter(12, FontWeight.w500, pal.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App-wide "now playing" bar. Shown by the main shell on every tab while a
/// recitation is active; tapping it opens the full-screen player.
class Mp3MiniPlayer extends ConsumerWidget {
  const Mp3MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mp3SessionProvider);
    if (session == null) return const SizedBox.shrink();
    final moshaf = session.moshaf;
    final state = ref.watch(mp3PlaybackProvider(moshaf));
    final surah = state.surah;
    if (surah == null) return const SizedBox.shrink();
    final controller = ref.read(mp3PlaybackProvider(moshaf).notifier);
    final names = ref.watch(mp3SuwarProvider).valueOrNull ?? const {};

    return _PlaybackBuilder(
      controller: controller,
      state: state,
      builder: (context, playing, busy) => AppMiniPlayerBar(
        artwork: const _Artwork(size: 40, radius: 0, shadow: false),
        title: names[surah] ?? context.tr('سورة $surah', 'Surah $surah'),
        subtitle: session.reciter.name,
        playing: playing,
        busy: busy,
        onTogglePlay: controller.togglePlay,
        onClose: () => ref.read(audioFocusProvider).stopAll(),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (_) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: _NowPlayingScreen(
                reciter: session.reciter, moshaf: session.moshaf),
          ),
        ),
      ),
    );
  }
}

// ── Now Playing view ─────────────────────────────────────────────────────────

/// Immersive "Now Playing" palette: always dark, tinted blue like the artwork.
class _Np {
  static const top = Color(0xFF15356A);
  static const mid = Color(0xFF0F2A55);
  static const bottom = Color(0xFF3A5568);
  static const accent = Color(0xFFA9C2F0); // artist line
  static const white = Colors.white;
  static Color dim(double a) => Colors.white.withValues(alpha: a);
}

class _NowPlayingScreen extends ConsumerStatefulWidget {
  const _NowPlayingScreen({required this.reciter, required this.moshaf});

  final Mp3Reciter reciter;
  final Mp3Moshaf moshaf;

  @override
  ConsumerState<_NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<_NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  static const _maxDrag = 140.0;

  /// Horizontal finger offset; the artwork follows it while swiping.
  final ValueNotifier<double> _dx = ValueNotifier(0);
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Animation<double>? _snapAnim;

  int _direction = 1; // 1 = moved forward (next), -1 = backward
  int? _lastSurah;
  bool _starred = false;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() => _dx.value = _snapAnim?.value ?? 0);
  }

  @override
  void dispose() {
    _snap.dispose();
    _dx.dispose();
    super.dispose();
  }

  void _springBack() {
    _snapAnim = Tween<double>(begin: _dx.value, end: 0)
        .animate(CurvedAnimation(parent: _snap, curve: Curves.easeOutBack));
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reciter = widget.reciter;
    final moshaf = widget.moshaf;
    final state = ref.watch(mp3PlaybackProvider(moshaf));
    final controller = ref.read(mp3PlaybackProvider(moshaf).notifier);
    final names = ref.watch(mp3SuwarProvider).valueOrNull ?? const {};
    final surah = state.surah;
    if (surah != null && _lastSurah != null && surah != _lastSurah) {
      _direction = surah > _lastSurah! ? 1 : -1;
    }
    _lastSurah = surah;
    final title = surah == null
        ? moshaf.name
        : (names[surah] ?? context.tr('سورة $surah', 'Surah $surah'));
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _Np.mid,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            // Background wash.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_Np.top, _Np.mid, _Np.bottom],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            // Full-bleed artwork that fades into the gradient.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screen.height * 0.68,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0, 0.6, 1],
                ).createShader(r),
                child: ValueListenableBuilder<double>(
                  valueListenable: _dx,
                  builder: (_, dx, child) => Opacity(
                    opacity: (1 - dx.abs() / (_maxDrag * 3)).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(dx * 0.5, 0),
                      child: child,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == ValueKey(surah);
                      final from =
                          Offset((incoming ? 1 : -1) * _direction * 0.4, 0);
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: from, end: Offset.zero)
                              .animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox.expand(
                      key: ValueKey(surah),
                      child: Opacity(
                        opacity: 0.85,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: _Artwork(
                              size: screen.width, radius: 0, shadow: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _snap.stop(),
                onHorizontalDragUpdate: (d) {
                  // Rubber-band when there is nothing further in that direction.
                  final blocked = (d.delta.dx < 0 && !controller.hasNext) ||
                      (d.delta.dx > 0 && !controller.hasPrevious);
                  _dx.value = (_dx.value + d.delta.dx * (blocked ? 0.25 : 1))
                      .clamp(-_maxDrag, _maxDrag);
                },
                onHorizontalDragCancel: _springBack,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  final go = v.abs() > 300 || _dx.value.abs() > _maxDrag * 0.6;
                  final forward = v != 0 ? v < 0 : _dx.value < 0;
                  // Swipe left → next surah, swipe right → previous.
                  if (go && forward && controller.hasNext) {
                    HapticFeedback.selectionClick();
                    _direction = 1;
                    controller.next();
                  } else if (go && !forward && controller.hasPrevious) {
                    HapticFeedback.selectionClick();
                    _direction = -1;
                    controller.previous();
                  }
                  _springBack();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      // Grabber — tap to dismiss.
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: 28,
                          width: 120,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _Np.dim(0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    title,
                                    key: ValueKey(title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _inter(
                                        22, FontWeight.w700, _Np.white,
                                        letterSpacing: -0.3),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reciter.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      _inter(22, FontWeight.w500, _Np.accent),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('المفضلة', 'Favorite'),
                            onPressed: () =>
                                setState(() => _starred = !_starred),
                            icon: Icon(
                              _starred
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 28,
                              color: _Np.white,
                            ),
                          ),
                        ],
                      ),
                      if (state.status == Mp3PlaybackStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            state.error == 'unavailable'
                                ? context.tr(
                                    'هذه السورة غير متوفرة لهذه التلاوة',
                                    'This surah is not available for this recitation')
                                : context.tr('تعذّر تشغيل التلاوة',
                                    'Could not play this recitation'),
                            textAlign: TextAlign.center,
                            style: _inter(
                                12, FontWeight.w500, const Color(0xFFFFB4AB)),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      _ProgressBar(controller: controller),
                      const SizedBox(height: AppSpacing.lg),
                      _NowPlayingControls(controller: controller, state: state),
                      const SizedBox(height: AppSpacing.lg),
                      _VolumeRow(controller: controller),
                      const SizedBox(height: AppSpacing.md),
                      _BottomRow(
                        controller: controller,
                        onQueue: () =>
                            _SurahSheet.show(context, reciter, moshaf),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingControls extends StatelessWidget {
  const _NowPlayingControls({required this.controller, required this.state});

  final Mp3PlaybackController controller;
  final Mp3PlaybackState state;

  Widget _skip(IconData icon, String label, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        iconSize: 58,
        onPressed: onTap,
        icon: Icon(icon, color: onTap == null ? _Np.dim(0.35) : _Np.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PlaybackBuilder(
      controller: controller,
      state: state,
      builder: (context, playing, busy) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _skip(Icons.fast_rewind_rounded, 'Previous',
                controller.hasPrevious ? controller.previous : null),
            Semantics(
              button: true,
              label: playing ? 'Pause' : 'Play',
              child: IconButton(
                iconSize: 72,
                onPressed: busy ? null : controller.togglePlay,
                icon: busy
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: _Np.white),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: _Np.white,
                      ),
              ),
            ),
            _skip(Icons.fast_forward_rounded, 'Next',
                controller.hasNext ? controller.next : null),
          ],
        );
      },
    );
  }
}

/// Shuffle · repeat · surah list; inactive toggles are dimmed.
class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.controller, required this.onQueue});

  final Mp3PlaybackController controller;
  final VoidCallback onQueue;

  Widget _toggle(ValueNotifier<bool> flag, IconData icon, String label) {
    return ValueListenableBuilder<bool>(
      valueListenable: flag,
      builder: (_, on, __) => IconButton(
        tooltip: label,
        onPressed: () => flag.value = !on,
        icon: Icon(icon, size: 26, color: on ? _Np.white : _Np.dim(0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _toggle(controller.shuffle, Icons.shuffle_rounded,
            context.tr('عشوائي', 'Shuffle')),
        _toggle(controller.repeat, Icons.repeat_one_rounded,
            context.tr('تكرار', 'Repeat')),
        IconButton(
          tooltip: context.tr('قائمة السور', 'Surah list'),
          onPressed: onQueue,
          icon: const Icon(Icons.format_list_bulleted_rounded,
              size: 26, color: _Np.white),
        ),
      ],
    );
  }
}

// ── Progress ─────────────────────────────────────────────────────────────────

/// Thin scrubbable bar with elapsed (left) and remaining (right) time.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.controller});

  final Mp3PlaybackController controller;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _drag; // 0..1 while the user is scrubbing

  @override
  Widget build(BuildContext context) {
    final player = widget.controller.player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (_, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (_, posSnap) {
            var pos = posSnap.data ?? Duration.zero;
            if (pos > total) pos = total;
            final live = total.inMilliseconds > 0
                ? pos.inMilliseconds / total.inMilliseconds
                : 0.0;
            final frac = (_drag ?? live).clamp(0.0, 1.0);
            final shown = _drag != null
                ? Duration(
                    milliseconds: (_drag! * total.inMilliseconds).round())
                : pos;
            final remaining = total - shown;

            void scrub(double dx, double width) {
              if (total == Duration.zero) return;
              setState(() => _drag = (dx / width).clamp(0.0, 1.0));
            }

            void commit() {
              final f = _drag;
              if (f != null && total > Duration.zero) {
                widget.controller.seek(
                    Duration(milliseconds: (f * total.inMilliseconds).round()));
              }
              setState(() => _drag = null);
            }

            final scrubbing = _drag != null;
            return Column(
              children: [
                Semantics(
                  label: 'Seek bar',
                  slider: true,
                  child: LayoutBuilder(
                    builder: (_, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => scrub(d.localPosition.dx, box.maxWidth),
                      onTapUp: (_) => commit(),
                      onHorizontalDragStart: (d) =>
                          scrub(d.localPosition.dx, box.maxWidth),
                      onHorizontalDragUpdate: (d) =>
                          scrub(d.localPosition.dx, box.maxWidth),
                      onHorizontalDragEnd: (_) => commit(),
                      onHorizontalDragCancel: () =>
                          setState(() => _drag = null),
                      child: SizedBox(
                        height: 24,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: scrubbing ? 10 : 6,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: _Np.dim(0.28),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: frac,
                              child: Container(color: _Np.dim(0.9)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(shown),
                        style: _inter(12, FontWeight.w600, _Np.dim(0.6))),
                    Text(
                        '-${_fmt(remaining.isNegative ? Duration.zero : remaining)}',
                        style: _inter(12, FontWeight.w600, _Np.dim(0.6))),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Volume ───────────────────────────────────────────────────────────────────

/// Mute · slider · loud icons bound to the real player volume.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.controller});

  final Mp3PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    return StreamBuilder<double>(
      initialData: player.volume,
      stream: player.volumeStream,
      builder: (context, snap) {
        final volume = snap.data ?? player.volume;
        return Row(
          children: [
            GestureDetector(
              onTap: controller.toggleMute,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                    volume <= 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_mute_rounded,
                    size: 18,
                    color: _Np.dim(0.6),
                    semanticLabel: context.tr('كتم الصوت', 'Mute')),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  activeTrackColor: _Np.dim(0.9),
                  inactiveTrackColor: _Np.dim(0.28),
                  thumbColor: Colors.transparent,
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Semantics(
                  label: 'Volume',
                  child: Slider(
                    value: volume.clamp(0.0, 1.0),
                    onChanged: controller.setVolume,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child:
                  Icon(Icons.volume_up_rounded, size: 20, color: _Np.dim(0.6)),
            ),
          ],
        );
      },
    );
  }
}

// ── Surah picker ─────────────────────────────────────────────────────────────

class _SurahEntry {
  const _SurahEntry(this.number, this.arabic, this.english, this.translation,
      this.available, this.searchKey);

  final int number;
  final String arabic;
  final String english;
  final String translation;
  final bool available;
  final String searchKey;
}

/// Bottom sheet listing all 114 surahs; picking one plays it in place.
class _SurahSheet extends ConsumerStatefulWidget {
  const _SurahSheet({
    required this.reciter,
    required this.moshaf,
    required this.scroll,
  });

  final Mp3Reciter reciter;
  final Mp3Moshaf moshaf;
  final ScrollController scroll;

  static const double _rowHeight = 68;

  static Future<void> show(
      BuildContext context, Mp3Reciter reciter, Mp3Moshaf moshaf) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) =>
            _SurahSheet(reciter: reciter, moshaf: moshaf, scroll: scroll),
      ),
    );
  }

  @override
  ConsumerState<_SurahSheet> createState() => _SurahSheetState();
}

class _SurahSheetState extends ConsumerState<_SurahSheet> {
  final _search = TextEditingController();
  String _query = '';
  bool _didScroll = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_SurahEntry> _entries(BuildContext context) {
    final names = ref.watch(mp3SuwarProvider).valueOrNull ?? const {};
    final meta = ref.watch(surahListProvider).valueOrNull ?? const [];
    final byNumber = {for (final s in meta) s.number: s};
    final available = widget.moshaf.surahNumbers.toSet();
    return List.generate(114, (i) {
      final n = i + 1;
      final s = byNumber[n];
      final arabic =
          names[n] ?? s?.arabicName ?? context.tr('سورة $n', 'Surah $n');
      final english = s?.englishName ?? '';
      final translation = s?.englishNameTranslation ?? '';
      final key = [
        normalizeArabic(arabic),
        if (s != null) normalizeArabic(s.arabicName),
        english.toLowerCase(),
        translation.toLowerCase(),
      ].join('|');
      return _SurahEntry(
          n, arabic, english, translation, available.contains(n), key);
    });
  }

  bool _matches(_SurahEntry e, String q) {
    if (q.isEmpty) return true;
    if (int.tryParse(q) != null) return e.number.toString().startsWith(q);
    return e.searchKey.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);
    final state = ref.watch(mp3PlaybackProvider(widget.moshaf));
    final controller = ref.read(mp3PlaybackProvider(widget.moshaf).notifier);
    final q = normalizeArabic(_query);
    final items = _entries(context).where((e) => _matches(e, q)).toList();

    // Start with the playing surah in view.
    if (!_didScroll && state.surah != null) {
      _didScroll = true;
      final current = state.surah!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sc = widget.scroll;
        if (!sc.hasClients) return;
        final target = ((current - 1) * _SurahSheet._rowHeight - 80)
            .clamp(0.0, sc.position.maxScrollExtent);
        sc.jumpTo(target);
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: pal.mute,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('السور', 'Surahs'),
                    style: _inter(20, FontWeight.w800, pal.ink,
                        letterSpacing: -0.3),
                  ),
                ),
                Text('114', style: _inter(13, FontWeight.w600, pal.sub)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              style: _inter(15, FontWeight.w500, pal.ink),
              cursorColor: pal.ink,
              decoration: InputDecoration(
                hintText: context.tr(
                    'ابحث بالاسم أو الرقم', 'Search by name or number'),
                hintStyle: _inter(15, FontWeight.w500, pal.mute),
                prefixIcon: Icon(Icons.search_rounded, color: pal.sub),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('مسح', 'Clear'),
                        icon: Icon(Icons.close_rounded, color: pal.sub),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: pal.chip,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      context.tr('لا توجد نتائج', 'No surahs found'),
                      style: _inter(14, FontWeight.w500, pal.sub),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scroll,
                    itemExtent: _SurahSheet._rowHeight,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      MediaQuery.of(context).padding.bottom + AppSpacing.md,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final e = items[i];
                      final active = state.surah == e.number;
                      return _SurahRow(
                        pal: pal,
                        entry: e,
                        active: active,
                        loading:
                            active && state.status == Mp3PlaybackStatus.loading,
                        onTap: !e.available
                            ? null
                            : () {
                                controller.playSurah(e.number);
                                Navigator.of(context).pop();
                              },
                      ).listEntrance(i);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.pal,
    required this.entry,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final _Pal pal;
  final _SurahEntry entry;
  final bool active;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (entry.english.isNotEmpty) entry.english,
      if (entry.translation.isNotEmpty) entry.translation,
    ].join(' · ');
    return Opacity(
      opacity: entry.available ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: active ? pal.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? pal.ink : pal.chip,
                    ),
                    child: Text(
                      '${entry.number}',
                      style: _inter(
                          12, FontWeight.w700, active ? pal.onInk : pal.sub),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.arabic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _inter(
                              16,
                              active ? FontWeight.w800 : FontWeight.w600,
                              pal.ink),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _inter(12, FontWeight.w500, pal.sub),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: pal.ink),
                    )
                  else if (active)
                    Icon(Icons.equalizer_rounded,
                        size: 22, color: pal.ink, semanticLabel: 'Playing'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Artwork ──────────────────────────────────────────────────────────────────

/// Abstract cross-section artwork: a pale disc with growth rings on a deep
/// slate tile, echoing the slate palette.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.size,
    required this.radius,
    required this.shadow,
  });

  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1218), Color(0xFF232B3A)],
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: const Color(0xFF171C26).withValues(alpha: 0.28),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(painter: _RingsPainter()),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  Path _blob(Offset c, double r, int salt) {
    final path = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final a = 2 * pi * i / steps;
      final wobble =
          1 + 0.035 * sin(a * 3 + salt) + 0.02 * cos(a * 5 + salt * 2);
      final p = c + Offset(cos(a), sin(a)) * (r * wobble);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;

    canvas.drawPath(
      _blob(c, r, 0),
      Paint()..color = const Color(0xFFE8EBF1),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, size.shortestSide / 150)
      ..color = const Color(0xFF171C26).withValues(alpha: 0.22);
    for (var i = 1; i <= 7; i++) {
      canvas.drawPath(_blob(c, r * i / 8, i), line);
    }

    // A couple of radial cracks.
    final crack = Paint()
      ..strokeWidth = line.strokeWidth * 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF171C26).withValues(alpha: 0.35);
    canvas.drawLine(c, c + Offset(cos(0.5), sin(0.5)) * r * 0.95, crack);
    canvas.drawLine(c, c + Offset(cos(2.4), sin(2.4)) * r * 0.8, crack);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}
