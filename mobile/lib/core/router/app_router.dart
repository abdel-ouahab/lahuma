import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/screens/surah_list_screen.dart';
import '../../features/quran/presentation/screens/surah_reading_screen.dart';
import '../../features/quran/presentation/screens/reciter_player_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_player_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_reciters_screen.dart';
import '../../features/bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/auth/presentation/account_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Splash (outside shell) ──────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Surah reader (outside shell — full-screen reading experience) ───
      GoRoute(
        path: r'/quran/:number(\d+)',
        builder: (context, state) => SurahReadingScreen(
          surahNumber: int.parse(state.pathParameters['number']!),
          initialAyah:
              int.tryParse(state.uri.queryParameters['ayah'] ?? '') ?? 1,
        ),
      ),

      // ── Account (optional sign in) ──────────────────────────────────────
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),

      // ── Main Shell with persistent bottom nav ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1 — Quran list + Reciters player
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quran',
                builder: (context, state) => SurahListScreen(
                  initialTab:
                      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                ),
                routes: [
                  GoRoute(
                    path: 'mp3quran',
                    builder: (context, state) => const Mp3QuranRecitersScreen(),
                    routes: [
                      GoRoute(
                        path: ':reciterId/:moshafId',
                        builder: (context, state) => Mp3QuranPlayerScreen(
                          reciterId: int.tryParse(
                                  state.pathParameters['reciterId']!) ??
                              -1,
                          moshafId: int.tryParse(
                                  state.pathParameters['moshafId']!) ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                  // Reciter full-screen player (inside shell so mini-player stays)
                  GoRoute(
                    path: 'reciters/:id',
                    builder: (context, state) => ReciterPlayerScreen(
                      reciterId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Bookmarks
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookmarks',
                builder: (context, state) => const BookmarksScreen(),
              ),
            ],
          ),
          // Branch 3 — More / Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
