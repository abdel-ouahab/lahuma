import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design/design.dart';
import '../localization/tr.dart';
import '../../features/mp3quran/presentation/mp3quran_player_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_providers.dart';
import '../../features/quran/presentation/providers/ayah_audio_provider.dart';
import '../../features/quran/presentation/providers/reciter_providers.dart';
import '../../features/quran/presentation/widgets/ayah_mini_player.dart';
import '../../features/quran/presentation/widgets/quran_mini_player.dart';

/// Persistent shell wrapping the 4 main destinations.
///
/// Pages scroll under the floating tab bar; the mini-player (when audio
/// is loaded) sits just above it. Both heights reach the pages as bottom
/// `MediaQuery` padding (see [AppTabScaffold]), so screens never pad for the
/// bar themselves. Each tab keeps its own navigation stack through the
/// router's `StatefulShellRoute` branches.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static List<AppTabItem> _tabs(BuildContext context) => [
        AppTabItem(
          icon: CupertinoIcons.house,
          activeIcon: CupertinoIcons.house_fill,
          label: context.tr('الرئيسية', 'Home'),
        ),
        AppTabItem(
          icon: CupertinoIcons.book,
          activeIcon: CupertinoIcons.book_fill,
          label: context.tr('القرآن', 'Quran'),
        ),
        AppTabItem(
          icon: CupertinoIcons.bookmark,
          activeIcon: CupertinoIcons.bookmark_fill,
          label: context.tr('العلامات', 'Bookmarks'),
        ),
        AppTabItem(
          icon: CupertinoIcons.ellipsis_circle,
          activeIcon: CupertinoIcons.ellipsis_circle_fill,
          label: context.tr('المزيد', 'More'),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quranVisible = ref.watch(activeReciterProvider) != null &&
        ref.watch(activeSurahAudioProvider) != null;
    final session = ref.watch(mp3SessionProvider);
    // Watching keeps the (auto-disposed) controller, and so the audio, alive
    // on every tab, not just while the player screen is open.
    final mp3Visible = session != null &&
        ref.watch(mp3PlaybackProvider(session.moshaf)).surah != null;
    // The reader's ayah recitation, still going after the reader was closed.
    final ayahVisible = ref.watch(ayahAudioProvider) != null;

    // AudioFocus keeps a single player active, so at most one of these shows.
    final Widget? miniPlayer = mp3Visible
        ? const Mp3MiniPlayer()
        : quranVisible
            ? const QuranMiniPlayer()
            : ayahVisible
                ? const AyahMiniPlayer()
                : null;

    return AppTabScaffold(
      body: navigationShell,
      accessory: miniPlayer,
      accessoryHeight: AppMiniPlayerBar.reservedHeight,
      tabBar: AppTabBar(
        items: _tabs(context),
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
