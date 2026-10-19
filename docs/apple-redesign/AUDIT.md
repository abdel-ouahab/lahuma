# Apple redesign — Phase 0 audit

Scope: the Flutter app in `mobile/` (package `lahuma`, Arabic RTL-first Quran app). Read-only audit; no code was changed. Baseline `flutter analyze`: **4 infos** (all `prefer_const_constructors`: `app_theme.dart:159`, `bookmark_card.dart:48`, `reciter_player_screen.dart:519`, `quran_mini_player.dart:100`). "Zero new issues" in later phases means this number must not grow.

## Decisions

| Question | Answer |
|---|---|
| Platforms | iOS look on every platform (no adaptive split) |
| Nav chrome | Classic Cupertino. Phase 5 (Liquid Glass) is skipped; no native-glass package |
| Brand | Keep teal `#14958B`, Cairo (headline styles), Scheherazade New (Quran text). Body UI text uses the system font on iOS, Cairo elsewhere |
| Git | Branch `feature/apple-design`; baseline commit of `mobile/` + `.claude/skills/`; one commit per phase |
| Packages | None added |

## 1. Flutter version and Cupertino support

- Flutter **3.47.2** (stable), Dart **3.13.2**; `pubspec` SDK constraint `>=3.3.0 <4.0.0`.
- Present in the SDK and usable: `CupertinoPageScaffold`, `CupertinoNavigationBar`, `CupertinoSliverNavigationBar` (including `.search` and `bottom`/`bottomMode`), `CupertinoTabBar`, `CupertinoListSection.insetGrouped`, `CupertinoSlidingSegmentedControl`, `CupertinoSliverRefreshControl`, `CupertinoSheetRoute` / `showCupertinoSheet`, `CupertinoAlertDialog`, `CupertinoActionSheet`, `CupertinoSwitch`, `CupertinoSlider`, `CupertinoDatePicker`, `CupertinoPicker`.
- UI packages in use: `google_fonts`, `go_router`, `flutter_riverpod`, `scrollable_positioned_list`, `share_plus`, `cupertino_icons` (declared, **0 uses**). No Liquid Glass package.
- **There is no `ios/` folder** (only `android/`), and Windows cannot build iOS. Connected test device: Android (SM G998B).
- Git had zero commits before the baseline (unborn `master`; no `main`).

## 2. Current theme setup

- `core/theme/app_colors.dart`: static `const Color` tokens (teal accent, ink, tinted card colors, light/dark surfaces, Quran reader, semantic). 70 lines, no `CupertinoDynamicColor`.
- `core/theme/app_theme.dart`: Material 3 `ThemeData` from `ColorScheme.fromSeed`, Cairo text theme via `GoogleFonts.cairoTextTheme`, `NoSplash`, `CupertinoPageTransitionsBuilder` on **all** platforms, themed `ElevatedButton`, `TextButton`, `InputDecoration`, `BottomNavigationBar`, `BottomSheet`, `Chip`, `AppBar`, `Divider`. Not themed: `FilledButton`, `OutlinedButton`, `Switch`, `Slider`, `Dialog`, `SnackBar` (those use stock M3 defaults).
- `core/theme/app_text_styles.dart`: Cairo/Scheherazade styles with fixed sizes — **unused** (0 call sites). Real UI inlines `GoogleFonts.cairo(fontSize: …)`: 144 occurrences.
- `core/theme/app_spacing.dart`: `AppSpacing` (4/8/16/24/32/48) and `AppRadius` (8…28, 999). Used on ~270 lines in 29 files. No 44pt touch-target token.
- Dark mode: `AppThemeMode {light, dark, system}` held by `themeModeProvider`, mapped to `ThemeMode` in `main.dart`. Dark base is true black with lifted cards. **This switch logic must be preserved.**
- `main.dart`: `MaterialApp.router`, locale from `localeOptionProvider` (`ar`/`en`), `GlobalMaterialLocalizations` + `GlobalWidgetsLocalizations` + `GlobalCupertinoLocalizations` already registered. No `builder`, no `textScaler` handling.

## 3. Screens and the Material widgets they use

| Screen | Role | Material widgets / notes |
|---|---|---|
| `features/splash/splash_screen.dart` | root route `/` | `Scaffold`, gradient `Container`, Fade/Slide transitions; `letterSpacing: 2` on the Arabic wordmark; `Future.delayed(1800ms)` → `context.go('/home')` (logic, keep) |
| `features/home/.../home_screen.dart` | tab root `/home` | `Scaffold`, `SafeArea`, `CustomScrollView`, custom header row, `SliverGrid` (2 cols, aspect 1.3) of `FeatureCard`; 3 raw hex tile colors |
| `features/quran/.../surah_list_screen.dart` | tab root `/quran` | `Scaffold`, `TabBar`/`TabBarView`/`TabController` (3 tabs: Surahs, Juz', Reciters), `TextField`, `Material`+`InkWell` (Juz rows), `CircularProgressIndicator`; fixed 44pt tab pill; `?tab=` deep link |
| `features/mp3quran/.../mp3quran_reciters_screen.dart` | list (embedded in Reciters tab; standalone screen is orphaned) | `AppBar`, filled `TextField`, `RefreshIndicator`, `ActionChip` per moshaf |
| `features/bookmarks/.../bookmarks_screen.dart` | tab root `/bookmarks` | `Scaffold`, `Dismissible`, floating `SnackBar` + `SnackBarAction`, `FilledButton`, `IconButton` (in `BookmarkCard`) |
| `features/settings/.../settings_screen.dart` | tab root `/settings` | `Scaffold`, `InkWell`, `Slider`, `SwitchListTile`, 1px `Divider`, private `_Card`/`_NavTile`/`_SettingTile` |
| `features/auth/.../account_screen.dart` | pushed, outside shell `/account` | `Scaffold`, `Form` + 3 `TextFormField`, `IconButton`, `FilledButton`, `OutlinedButton.icon`, `TextButton`; email regex + 8-char rule (logic, keep) |
| `features/quran/.../surah_reading_screen.dart` | pushed, outside shell `/quran/:n` | `Scaffold` (custom top row), `ScrollablePositionedList`, `SnackBar`, `FilledButton.icon`; `ReadingTracker`, scroll thresholds, audio listeners (logic, keep) |
| `features/quran/.../reciter_player_screen.dart` | pushed, inside shell | transparent `AppBar`, `Slider` (seek), `SnackBar`, animated album art with `BoxShadow` glow |
| `features/mp3quran/.../mp3quran_player_screen.dart` (1641 lines) | pushed inside shell + 2 modal sheets + mini-player | `Scaffold`, `Slider`, `Material`+`InkWell`, `DraggableScrollableSheet`, `ShaderMask`; own `_Pal` / `_Np` palettes and Inter font; bespoke `_ProgressBar` scrubber; side effect in `build` (leave untouched) |
| Modals | | `ayah_action_sheet` (3-col tile grid), `ayah_text_sheet`, `reader_options_sheet` (`Slider`, `SwitchListTile`, `TextField`), `ayah_note_dialog` (`AlertDialog`), `goal_sheet`, `dedication_sheet` (`ChoiceChip`s, `TextField`), Now Playing + Surah picker sheets. Totals: 7× `showModalBottomSheet`, 1× `showDialog`, 10× `SnackBar` |
| Shell | | `MainShell` (`Scaffold(extendBody)` + `Stack`), `GlassNavigationBar` (`BackdropFilter` σ30, two `BoxShadow`s), `QuranMiniPlayer` (blur pill), `Mp3MiniPlayer` (`Material` elevation 8) |

## 4. Shared / custom widgets → future design system

| Widget | Call sites | Verdict |
|---|---|---|
| `LahumaCard` (`core/widgets/app_card.dart`) | 10 | Best base: Material-free, spring-press (`kLahumaSpring`, honours `disableAnimations`). Becomes `AppCard` minus shadow/coloured override |
| `LahumaIconButton` | 7 | 44pt hit area + semantics already; becomes `AppIconButton` (opacity press, haptic) |
| `ErrorRetry` | 6 | Becomes `AppErrorState`; keep its offline-detection logic |
| `FeatureCard`, `SectionTitle`, `ContinueReadingCard`, `ProgressCard`, `SadaqahCard` | 4 / 3 / 2 / 1 / 1 (home only) | Restyle onto tokens |
| `GlassNavigationBar` | 1 widget, **8 files call `GlassNavigationBar.totalHeight()`** | Replaced by `AppTabBar`; the manual paddings go away |
| `QuranMiniPlayer`, `Mp3MiniPlayer` | 1 each (shell) | Share one mini-player container, one height token |
| `AppButton`, `AppTextField`, `AppCard` (forwarder), `LahumaBottomNavigation`, `AppTextStyles` | **0** | Dead code. Replaced by the new library; deleted only with approval |
| `ReciterListView`, `ReciterCard`, `Mp3QuranRecitersScreen` route | 0 | Dead / orphaned; same rule |

## 5. Hard-coded values that must be replaced

Counts over `mobile/lib` (excluding generated l10n):

| Pattern | Count |
|---|---|
| `Colors.` | 342 |
| `Color(0x` | 78 |
| `GoogleFonts.` | 144 |
| `fontSize:` | 142 |
| `Icons.` | 110 (`CupertinoIcons`: 0) |
| `BoxShadow` | 17 |
| `elevation:` | 8 |
| `InkWell` / `InkResponse` | 8 |
| `showModalBottomSheet` / `showDialog` / `SnackBar` | 7 / 1 / 10 |
| `Slider(` / `TextField(` / `CircularProgressIndicator` | 6 / 8 / 13 |
| `BackdropFilter` | 4 |
| `FloatingActionButton` / `MaterialPageRoute` | 0 / 0 |

Heaviest files for `Colors.`/hex: `reciter_player_screen` (51), `mp3quran_player_screen` (38), `settings_screen` (21), `surah_list_screen` (21), `reciter_card` (17), `quran_mini_player` (14), `ayah_action_sheet` (13, six rainbow action colors), `glass_navigation_bar` (13), `ayah_widget` (12).

Raw hex outside the theme: `home_screen` (`8E5CF7`, `0A84FF`, `FF6482`), `progress_card` (`FF9F0A`, `E08A33`), `ayah_widget` (`E08A33`), `reciter_player_screen` (`0D6B64`), `reciter_card` (`DDF5F3`, `B8EBE8`), `mp3quran_player_screen` (`_Pal`/`_Np` palettes), `bookmark_card` (`Colors.red`).

Shadows to remove: `ContinueReadingCard` (coloured `primaryDark` blur 30), `SurahHeader` (blur 30, offset 14), `ReciterPlayerScreen` album-art glow + play button, `SurahListItem`, `ReciterCard`, `QuranMiniPlayer`, `Mp3MiniPlayer` (elevation 8), `GlassNavigationBar` (two), `LahumaCard` light-mode shadow, `settings_screen` `_Card` override, `LahumaBottomNavigation`.

Fixed sizes that clip under Dynamic Type: tab pill `height: 44`; glass bar `height: 64`; feature grid `childAspectRatio: 1.3` (overflows near 1.6× by estimate); action-sheet tile width math; `_SurahSheet._rowHeight = 68`; mini-player reserved heights `64` and `80`.

## 6. RTL problems

- **Wrong chevron in Arabic** — `settings_screen.dart:342-344` picks `chevron_left_rounded` for Arabic, but that Material icon has `matchTextDirection: true`, so it mirrors twice and points the wrong way.
- `reciter_player_screen.dart:416` uses `Alignment.centerRight` for a label (wrong in English); `_format` drops hours.
- `mp3quran_player_screen.dart`: Now Playing wraps the whole sheet in `Directionality(ltr)` (Arabic titles are left-aligned); `_ProgressBar` uses `Alignment.centerLeft`; tile index uses `padLeft`.
- `EdgeInsets.fromLTRB` ×33: all symmetric (safe) but should become `EdgeInsetsDirectional`. `EdgeInsets.only(left|right)`: 0. `Alignment.*Left/Right`: 12 (mostly gradients). `Positioned(left/right)`: symmetric in `MainShell`.
- Numbers and Latin text inside Arabic paragraphs without LTR isolation: `continue_reading_card:67` (`NN%`), `progress_card:58,96` (`N / M آية`, `%`), `bookmark_card:111` (`d/m/y`), `account_screen:118` (email), `surah_reading_screen` meta (`مكية • 7 آية`), `reciter_player_screen` timers.
- Letter-spacing on Arabic: splash wordmark (`2`), `AppTextStyles.labelSmall` (`0.5`; unused). `home_screen` guards correctly.
- Directional icons that don't mirror: `play_arrow_rounded` (play is intentionally not mirrored), `fast_rewind/forward_rounded`.
- Account screen: fixed Arabic-Indic `٨` in a message while the rest of the app uses Western digits.

## 7. Layout and platform issues beyond RTL

- Bottom inset is counted twice: screens wrap content in `SafeArea` **and** pad with `GlassNavigationBar.totalHeight(context)`, which already includes the safe area.
- `DedicationSheet` is opened without `useRootNavigator`, so it likely renders behind the floating nav bar (`GoalSheet` sets it).
- `SectionTitle` trailing action (~36pt), `BookmarkCard` `IconButton`, Juz rows, and several `GestureDetector` tiles have no press feedback (theme sets `NoSplash`) or fall under 44pt.
- Press feedback exists only in `LahumaCard` (0.97 spring) and `LahumaIconButton` (0.92).
- `Dismissible` in bookmarks has a single `background` for both swipe directions.
- No `SystemChrome` / status-bar style handling; no reduce-motion check on the splash.
- Text scaling: nothing clamps or customises it, so OS scale multiplies every `Text` (including Quran text on top of the 20–40 reader size).

## 8. Risks

- **No `ios/` runner** — real-iPhone verification needs `flutter create --platforms=ios .` on a Mac (not run; needs approval).
- **`ScrollablePositionedList`** in the reader cannot host a sliver nav bar → standard `CupertinoNavigationBar`, no large title.
- **Custom audio UI** (`_ProgressBar` scrubber, Now Playing swipe + rubber-band, `_RingsPainter`, `_OctagonPainter`, rotating album art) has no Cupertino equivalent → restyle only, keep the gesture/animation code.
- **Business logic embedded in widgets** that must not move: `ReadingTracker` and scroll thresholds, audio provider writes in `_playSurah`, `mp3SessionProvider` microtask in `_PlayerBody.build`, `MainShell` provider watches (they keep audio alive), `goBranch(initialLocation: …)`, form regex and `_busy` state, `Dismissible` delete/undo calls.
- **Performance**: `BackdropFilter` appears in the nav bar and a mini-player; keep sigma modest and clip tightly. `ReciterPlayerScreen` builds up to 114 surah rows eagerly.
- **Router**: all routes use `builder:` (→ `MaterialPage`); the swipe-back currently comes from the theme's `CupertinoPageTransitionsBuilder`. Switching to `CupertinoPage` must keep `router_test.dart` green.
- **Tests**: `widget_test.dart` asserts `find.byType(MaterialApp)` and the home greeting `السلام عليكم`; `router_test.dart` checks route matching. The root therefore stays `MaterialApp.router` for now.
- **Fonts**: `google_fonts` is fetched at runtime (tests set `allowRuntimeFetching = false`). On Android the "system font" is Roboto, so non-iOS builds keep Cairo for body text.
- **Dead code** (see §4) is deleted only after explicit approval.
