import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/glass_navigation_bar.dart';
import '../../features/mp3quran/presentation/mp3quran_player_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_providers.dart';
import '../../features/quran/presentation/providers/reciter_providers.dart';
import '../../features/quran/presentation/widgets/quran_mini_player.dart';

/// Persistent shell wrapping the 4 main destinations.
///
/// The [GlassNavigationBar] floats above the content using a [Stack], so page
/// content scrolls behind the translucent glass — this is what makes the
/// BackdropFilter blur effect visible.
///
/// Each branch's scrollable content should add bottom padding equal to
/// [GlassNavigationBar.totalHeight] so the last items remain reachable.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Approximate height of [QuranMiniPlayer] including its vertical margin.
  static const double _miniPlayerHeight = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quranVisible = ref.watch(activeReciterProvider) != null &&
        ref.watch(activeSurahAudioProvider) != null;
    final session = ref.watch(mp3SessionProvider);
    // Watching keeps the (auto-disposed) controller, and so the audio, alive
    // on every tab, not just while the player screen is open.
    final mp3Visible = session != null &&
        ref.watch(mp3PlaybackProvider(session.moshaf)).surah != null;
    final miniPlayerVisible = quranVisible || mp3Visible;
    final reserved = mp3Visible ? kMp3MiniPlayerHeight : _miniPlayerHeight;

    return Scaffold(
      // No bottomNavigationBar — the glass bar is overlaid via Stack below.
      extendBody: true,
      body: Stack(
        children: [
          // ── Page content (full-screen, scrolls behind the glass bar) ───
          // While the mini-player is showing, content ends above it rather
          // than scrolling underneath.
          Padding(
            padding: EdgeInsets.only(
              bottom: miniPlayerVisible
                  ? GlassNavigationBar.totalHeight(context) + reserved
                  : 0,
            ),
            child: navigationShell,
          ),

          // ── Quran mini-player (visible during audio playback) ──────────
          Positioned(
            left: 0,
            right: 0,
            bottom: GlassNavigationBar.totalHeight(context),
            child: mp3Visible ? const Mp3MiniPlayer() : const QuranMiniPlayer(),
          ),

          // ── Floating glass navigation bar ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
