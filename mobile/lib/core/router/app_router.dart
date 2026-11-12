import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design/app_motion.dart';
import '../design/design_system_preview.dart';
import '../shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quran/presentation/screens/surah_list_screen.dart';
import '../../features/quran/presentation/screens/surah_reading_screen.dart';
import '../../features/quran/presentation/screens/reciter_player_screen.dart';
import '../../features/quran/mushaf/presentation/screens/mushaf_index_screen.dart';
import '../../features/quran/mushaf/presentation/screens/mushaf_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_player_screen.dart';
import '../../features/mp3quran/presentation/mp3quran_reciters_screen.dart';
import '../../features/bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/adhan/presentation/screens/adhan_player_screen.dart';
import '../../features/adhan/presentation/screens/adhan_reliability_screen.dart';
import '../../features/adhan/presentation/screens/adhan_settings_screen.dart';
import '../../features/reminders/presentation/reminders_settings_screen.dart';
import '../../features/prayer_times/domain/prayer_times.dart';
import '../../features/adhkar/presentation/screens/adhkar_category_screen.dart';
import '../../features/adhkar/presentation/screens/adhkar_screen.dart';
import '../../features/fajr_call/presentation/screens/fajr_call_edit_screen.dart';
import '../../features/fajr_call/presentation/screens/fajr_call_lists_screen.dart';
import '../../features/fajr_call/presentation/screens/fajr_call_log_screen.dart';
import '../../features/fajr_call/presentation/screens/fajr_call_permissions_screen.dart';
import '../../features/fajr_call/presentation/screens/fajr_wake_list_screen.dart';
import '../../features/khatma/presentation/screens/khatma_complete_screen.dart';
import '../../features/khatma/presentation/screens/khatma_screen.dart';
import '../../features/khatma/presentation/screens/khatma_setup_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/tasbih/presentation/screens/tasbih_screen.dart';

/// Every screen is an iOS page: slide transition with the interactive
/// edge-swipe back gesture (from the right edge in RTL).
Page<void> _page(GoRouterState state, Widget child) =>
    CupertinoPage<void>(key: state.pageKey, child: child);

/// Screens the splash hands over to (the introduction, the tab shell): they
/// fade in over the splash rather than slide, since there is nothing to go
/// back to. Instant with Reduce Motion.
Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.standard,
      reverseTransitionDuration: AppMotion.standard,
      transitionsBuilder: (context, animation, _, child) =>
          MediaQuery.disableAnimationsOf(context)
              ? child
              : FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: AppMotion.curve),
                  child: child,
                ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Splash (outside shell) ──────────────────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _page(state, const SplashScreen()),
      ),

      // ── Introduction (outside shell — first launch, or from Settings) ──
      GoRoute(
        path: OnboardingScreen.path,
        pageBuilder: (context, state) => _fadePage(
          state,
          OnboardingScreen(replay: state.uri.queryParameters['replay'] == '1'),
        ),
      ),

      // ── Surah reader (outside shell — full-screen reading experience) ───
      GoRoute(
        path: r'/quran/:number(\d+)',
        pageBuilder: (context, state) => _page(
          state,
          SurahReadingScreen(
            surahNumber: int.parse(state.pathParameters['number']!),
            initialAyah:
                int.tryParse(state.uri.queryParameters['ayah'] ?? '') ?? 1,
          ),
        ),
      ),

      // ── Mushaf (outside shell — full-screen pages) ─────────────────────
      GoRoute(
        path: MushafScreen.path,
        pageBuilder: (context, state) => _page(
          state,
          MushafScreen(
            initialPage: int.tryParse(state.uri.queryParameters['page'] ?? ''),
          ),
        ),
        routes: [
          GoRoute(
            path: 'index',
            pageBuilder: (context, state) => _page(
              state,
              MushafIndexScreen(
                currentPage:
                    int.tryParse(state.uri.queryParameters['page'] ?? ''),
              ),
            ),
          ),
        ],
      ),

      // Old addresses: Bookmarks used to be a tab, adhkar lived under Home.
      GoRoute(path: '/bookmarks', redirect: (_, __) => BookmarksScreen.path),
      GoRoute(path: '/home/adhkar', redirect: (_, __) => AdhkarScreen.path),

      // ── Tasbih (outside shell — the beads need the full screen) ─────────
      GoRoute(
        path: TasbihScreen.path,
        pageBuilder: (context, state) => _page(state, const TasbihScreen()),
      ),

      // ── Khatma planner (outside shell — opened from its reminders) ──────
      GoRoute(
        path: KhatmaScreen.path,
        pageBuilder: (context, state) => _page(state, const KhatmaScreen()),
        routes: [
          GoRoute(
            path: 'setup',
            pageBuilder: (context, state) => _page(
                state,
                KhatmaSetupScreen(
                    initialDays:
                        int.tryParse(state.uri.queryParameters['days'] ?? ''))),
          ),
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) =>
                _page(state, const KhatmaSetupScreen(edit: true)),
          ),
          GoRoute(
            path: 'done/:id',
            pageBuilder: (context, state) => _page(state,
                KhatmaCompleteScreen(id: state.pathParameters['id'] ?? '')),
          ),
        ],
      ),

      // ── Qibla (outside shell — the compass needs the full screen) ───────
      GoRoute(
        path: QiblaScreen.path,
        pageBuilder: (context, state) => _page(state, const QiblaScreen()),
      ),

      // ── Fajr wake list (outside shell — opened from the Fajr notification)
      GoRoute(
        path: '/fajr-call/wake/:id',
        pageBuilder: (context, state) {
          final at = int.tryParse(state.uri.queryParameters['at'] ?? '');
          return _page(
            state,
            FajrWakeListScreen(
              listId: state.pathParameters['id']!,
              firedAt:
                  at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
            ),
          );
        },
      ),

      // ── Adhan player (outside shell — opened from an adhan notification)
      GoRoute(
        path: AdhanPlayerScreen.path,
        pageBuilder: (context, state) {
          final name = state.uri.queryParameters['prayer'];
          final prayer = PrayerKind.values
                  .where((p) => p.name == name && p != PrayerKind.sunrise)
                  .firstOrNull ??
              PrayerKind.dhuhr;
          return _page(state, AdhanPlayerScreen(prayer: prayer));
        },
      ),

      // ── Account (optional sign in) ──────────────────────────────────────
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) => _page(state, const AccountScreen()),
      ),

      // ── Design system catalogue (debug builds only) ─────────────────────
      if (kDebugMode)
        GoRoute(
          path: '/__design',
          pageBuilder: (context, state) =>
              _page(state, const DesignSystemPreview()),
        ),

      // ── Main Shell with persistent tab bar ──────────────────────────────
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) =>
            _fadePage(state, MainShell(navigationShell: navigationShell)),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    _page(state, const HomeScreen()),
                routes: [
                  // Bookmarks (moved off the tab bar for Adhkar).
                  GoRoute(
                    path: 'bookmarks',
                    pageBuilder: (context, state) =>
                        _page(state, const BookmarksScreen()),
                  ),
                  GoRoute(
                    path: 'fajr-call',
                    pageBuilder: (context, state) =>
                        _page(state, const FajrCallListsScreen()),
                    routes: [
                      // Before ':id', which would otherwise capture them.
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            _page(state, const FajrCallEditScreen()),
                      ),
                      GoRoute(
                        path: 'permissions',
                        pageBuilder: (context, state) => _page(
                          state,
                          FajrCallPermissionsScreen(
                            firstRun: state.uri.queryParameters['first'] == '1',
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _page(
                          state,
                          FajrCallEditScreen(
                              listId: state.pathParameters['id']!),
                        ),
                        routes: [
                          GoRoute(
                            path: 'log',
                            pageBuilder: (context, state) => _page(
                              state,
                              FajrCallLogScreen(
                                  listId: state.pathParameters['id']!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Quran list + Reciters player
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quran',
                pageBuilder: (context, state) => _page(
                  state,
                  SurahListScreen(
                    initialTab:
                        int.tryParse(state.uri.queryParameters['tab'] ?? '') ??
                            0,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'mp3quran',
                    pageBuilder: (context, state) =>
                        _page(state, const Mp3QuranRecitersScreen()),
                    routes: [
                      GoRoute(
                        path: ':reciterId/:moshafId',
                        pageBuilder: (context, state) => _page(
                          state,
                          Mp3QuranPlayerScreen(
                            reciterId: int.tryParse(
                                    state.pathParameters['reciterId']!) ??
                                -1,
                            moshafId: int.tryParse(
                                    state.pathParameters['moshafId']!) ??
                                -1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Reciter full-screen player (inside shell so mini-player stays)
                  GoRoute(
                    path: 'reciters/:id',
                    pageBuilder: (context, state) => _page(
                      state,
                      ReciterPlayerScreen(
                        reciterId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 — Adhkar & duas
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AdhkarScreen.path,
                pageBuilder: (context, state) =>
                    _page(state, const AdhkarScreen()),
                routes: [
                  GoRoute(
                    path: ':category',
                    pageBuilder: (context, state) => _page(
                      state,
                      AdhkarCategoryScreen(
                          categoryId: state.pathParameters['category']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3 — More / Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    _page(state, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'adhan',
                    pageBuilder: (context, state) =>
                        _page(state, const AdhanSettingsScreen()),
                    routes: [
                      GoRoute(
                        path: 'reliability',
                        pageBuilder: (context, state) =>
                            _page(state, const AdhanReliabilityScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reminders',
                    pageBuilder: (context, state) =>
                        _page(state, const RemindersSettingsScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
