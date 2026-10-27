# Lahuma mobile — missing features as mini tasks

Audit of `mobile/` (Flutter) on branch `feature/apple-design`, 2026-10-22, cross-checked against `backend/`, `client/`, the README roadmap and `docs/apple-redesign/`.
`flutter analyze`: 2 infos, no warnings.

## What the app already does

Guest-first Quran app: surah / juz' / reciter tabs, a reader with last-read tracking, auto-scroll, text size, jump to ayah, English translation (Sahih), Arabic tafsir (Muyassar), per-ayah audio (Alafasy), copy/share text, notes and bookmarks. It also has a daily wird with goal and streak, a reading intention (dedication) with an ayah tally, morning/evening adhkar with counters and favourites, an MP3Quran reciter player (shuffle, repeat, volume, queue), offline cache of opened surahs, optional email sign-in, Arabic/English and light/dark.

## How to read this list

- **Priority**: **P0** = bug or release blocker, **P1** = core or roadmap feature, **P2** = enhancement, **P3** = later idea.
- **Size**: **S** ≤ 1 day, **M** 2–4 days, **L** 1 week or more.
- Each task gives its evidence (*Where*) and a check you can test (*Done when*).

## Suggested first sprint

A1 → A2 → J1 → D1 → C1 → H1 → B1 → M1/M2 → X1. These are mostly small and fix real bugs or cheap wins.

---

## A. Audio and playback

- [x] **A1 · One audio source at a time** — P0 · S
  *Where:* there are three independent players. `AyahAudioNotifier.playFrom` pauses only `QuranAudioService` (`quran/presentation/providers/ayah_audio_provider.dart:688`), and `mp3PlaybackProvider` stops only `QuranAudioService` (`mp3quran/presentation/mp3quran_providers.dart`, last provider). So MP3Quran audio and ayah audio can play over each other.
  *Done when:* starting any player stops the other two (for example through a small `AudioFocus` coordinator provider), and a test covers each pair.
  *Done (2026-10-22):* `core/audio/audio_focus.dart`. All three players claim focus before they start or resume, and claiming stops the others. Tests: `test/audio_focus_test.dart`.

- [x] **A2 · Ayah recitation keeps playing with no controls after leaving the reader** — P0 · S
  *Where:* `ayahAudioProvider` is global (not autoDispose), the reader's `dispose` doesn't stop it, and `MainShell` only shows mini-players for the reciter and MP3 players (`core/shell/main_shell.dart`).
  *Done when:* leaving the reader mid-recitation shows an `AppMiniPlayerBar` (surah · ayah N, pause, stop), and tapping it reopens `/quran/:n?ayah=N`.
  *Done (2026-10-22):* `AyahMiniPlayer` in the shell. `AppMiniPlayerBar` gained an optional close button, which all three mini-players now use (`AudioFocus.stopAll`).

- [ ] **A3 · Background playback and lock-screen / notification controls** — P1 · M
  *Where:* there's no `audio_service` / `just_audio_background`. The Android manifest only has `INTERNET`, and iOS has no `UIBackgroundModes audio`.
  *Done when:* audio keeps playing with the screen off and shows title, reciter and artwork with play/pause/next/previous on the lock screen and in the notification. Do A1 first, since background plugins assume one player.

- [ ] **A4 · Choose the reciter for ayah-by-ayah audio** — P1 · S
  *Where:* `ar.alafasy` is hard-coded (`ayah_audio_provider.dart:670`).
  *Done when:* Settings and reader options offer a few cdn.islamic.network editions (Husary, Minshawi, Abdul Basit, Maher Al-Muaiqly…), the choice is saved in `SettingsRepository`, and playback uses it.

- [ ] **A5 · Memorisation repeat (hifz mode)** — P1 · M
  *Done when:* in the reader you can pick an ayah range (from–to), repeat each ayah ×N and the whole range ×M, and add an optional pause between ayahs. The README lists hifz as not implemented.

- [ ] **A6 · Playback speed** — P2 · S
  *Done when:* 0.75× / 1× / 1.25× / 1.5× is available in the MP3 Now Playing screen and the reader (`player.setSpeed`) and is remembered.

- [ ] **A7 · Sleep timer** — P2 · S
  *Done when:* Now Playing offers 15 / 30 / 60 min or end of surah, and playback fades out and pauses.

- [ ] **A8 · Download recitations for offline listening** — P1 · M
  *Done when:* you can download a surah, or a whole moshaf, from a reciter with progress. Files are stored in app documents (`path_provider`), downloaded rows show a badge, the player prefers the local file, and Settings → Storage lists downloads and can delete them.

- [ ] **A9 · Reciter and surah names in English** — P2 · S
  *Where:* `Mp3QuranApi.fetchReciters/fetchSuwar` always send `language=ar` (`mp3quran/data/mp3quran_api.dart`), so the English UI shows Arabic names.
  *Done when:* the app sends `eng` when the UI is English and refetches when the language changes.

- [ ] **A10 · Resume the last listening session** — P2 · S
  *Done when:* the last reciter, moshaf, surah and position are saved, and on the next launch the mini-player comes back paused at that position.

## B. Reciters uploaded through the admin panel

- [x] **B1 · Admin-uploaded reciters can't be reached in the app** — P0 · M
  *Where:* the admin panel uploads reciters to `/api/reciters`, but `ReciterListView` (`quran/presentation/widgets/reciter_list_view.dart`) isn't used anywhere. The Reciters tab shows only MP3Quran (`surah_list_screen.dart`, third tab). The only way to `/quran/reciters/:id` is the mini-player.
  *Done when:* the Reciters tab has a "Lahuma reciters" section above MP3Quran that opens `ReciterPlayerScreen` (redesigned with N1). If the feature is being dropped instead, the code and backend module are removed.
  *Done (2026-10-22):* a "Lahuma reciters" section heads the Reciters tab (`lahuma_reciters_section.dart`, `playableReciters`). It's hidden while the backend is unreachable or has no audio. `ReciterPlayerScreen` itself is not redesigned yet.

## C. Quran reader

- [ ] **C1 · Show juz', hizb, page and sajdah** — P1 · S
  *Where:* each ayah from the API already has `juz`, `page`, `hizbQuarter` and `sajda` (checked: Surah 32:15 → juz 21, page 416, obligatory sajda), but `Ayah.fromJson` drops them (`quran/domain/ayah.dart`).
  *Done when:* the nav bar shows the current juz' and hizb, ayahs with a sajdah show ۩ with a short label, and a divider marks where a new juz' starts.

- [ ] **C2 · Previous surah and swiping between surahs** — P1 · S
  *Where:* the footer only has "Next surah" (`surah_reading_screen.dart`, `_Footer`).
  *Done when:* you can go to the previous surah from the header or footer, and optionally swipe sideways in the RTL direction.

- [ ] **C3 · Keep the screen on while reading** — P1 · S
  *Done when:* `wakelock_plus` is turned on in the reader and during auto-scroll and audio, it's released when you leave, and a Settings toggle controls it.

- [ ] **C4 · Mushaf page mode (604 Madani pages)** — P1 · L
  *Done when:* the reader can switch between list and page modes. Page mode is fetched with `/page/{n}/quran-uthmani` (or page images), swipes RTL, and saves and resumes the last page. Bookmarks and last-read still work.

- [ ] **C5 · Tajweed colours** — P2 · M
  *Done when:* the `quran-tajweed` edition is parsed into coloured `TextSpan`s, there's a toggle in reader options, and a colour legend sheet explains the colours.

- [ ] **C6 · More translation languages** — P1 · M
  *Where:* only `en.sahih` exists (`QuranEditions` in `quran/domain/quran_repository.dart`).
  *Done when:* a picker offers French, Urdu, Indonesian, Turkish, Spanish and other editions. The choice is saved, used for the inline translation and the sheet, and cached offline like the rest.

- [ ] **C7 · More tafsirs** — P1 · S
  *Where:* only `ar.muyassar` exists.
  *Done when:* the tafsir sheet has a picker (Muyassar, Jalalayn, Qurtubi, Baghawi, Waseet), it remembers the last one, and each is cached.

- [ ] **C8 · Reading appearance** — P2 · S
  *Done when:* reader options offer a sepia / night page colour, line spacing, and a choice of Quran font (Scheherazade, or an Uthmanic Hafs style).

- [ ] **C9 · Share an ayah as an image** — P2 · S
  *Done when:* there's a "Share as image" action that renders a styled card (ayah, surah:ayah, logo) through `RepaintBoundary` to PNG and shares it with `share_plus`.

- [ ] **C10 · Share or copy with translation or tafsir** — P2 · S
  *Done when:* the share and copy actions can include the selected translation or tafsir under the ayah.

- [ ] **C11 · Show the last-read ayah when reopening** — P2 · S
  *Done when:* the saved ayah has a subtle marker for a few seconds after the reader opens through "Continue reading".

## D. Search and navigation

- [x] **D1 · Arabic surah search ignores diacritics** — P0 · S
  *Where:* `_filter` does `s.arabicName.contains(q)` (`surah_list_screen.dart`), but the API name is `سُورَةُ السَّجۡدَةِ`, with diacritics and a "سورة" prefix. So typing `السجدة` finds nothing.
  *Done when:* the query and the names are both run through `normalizeArabic` (which already exists in `mp3quran_providers.dart`; move it to `core/`), the "سورة" prefix is ignored, and a unit test covers it.
  *Done (2026-10-22):* `core/utils/arabic_text.dart` now also strips Quranic marks (`ۡ` etc.) and tatweel. `filterSurahs` lives in `quran_providers.dart`. Tests: `test/surah_search_test.dart`.

- [ ] **D2 · Full-text ayah search** — P1 · M
  *Done when:* a search screen finds ayahs by Arabic words (ignoring diacritics) and by translation text. It works online through `/search/{q}/all/{edition}` and offline after E1, highlights the matched words, and opens the reader at the ayah.

- [ ] **D3 · Hizb list and go to page** — P2 · S
  *Done when:* the Juz' tab can expand into 60 hizb (or quarters), and reader options have "Go to page 1–604" (uses the C1 data).

- [ ] **D4 · Surah list status and filters** — P2 · S
  *Done when:* rows show a last-read dot or a completed check, and the list can be filtered Meccan / Medinan.

## E. Offline

- [ ] **E1 · Download the whole Quran text** — P1 · M
  *Where:* in the README's known limitations, every surah needs a connection the first time.
  *Done when:* Settings has "Download for offline" (one call to `/quran/quran-uthmani`, plus the chosen translation and tafsir) with progress, a done state and the size used. A bundled JSON asset would also work.

- [ ] **E2 · Bundled surah index** — P1 · S
  *Where:* the Quran tab needs the network on first launch (`surahListProvider`), and the 114 names are already hard-coded a second time in `reciter_local_data_source.dart`.
  *Done when:* one bundled `surahs.json` (number, Arabic, English, translation, ayah count, revelation type) feeds the surah list, juz' labels and reciter lists, with no network needed.

- [ ] **E3 · Bundled adhkar fallback** — P1 · S
  *Where:* adhkar come from a pinned GitHub URL (`adhkar/data/adhkar_service.dart`), so they're empty offline on first launch. The same pinned file is already at `test/fixtures/adkar.json`.
  *Done when:* the file ships as an asset and is used when there's no cache and the fetch fails.

- [ ] **E4 · Storage management** — P2 · S
  *Done when:* Settings → Storage shows the size of the Quran cache, adhkar cache and downloads, and each can be cleared.

## F. Daily habit: wird, khatmah, statistics, reminders

- [ ] **F1 · Reminders (local notifications)** — P1 · M
  *Where:* README says "Daily reminders / push notifications are not implemented".
  *Done when:* there are wird, morning-adhkar, evening-adhkar and Friday Al-Kahf reminders, each with its own time and on/off switch (`flutter_local_notifications` + `timezone`). The app asks for Android 13 `POST_NOTIFICATIONS` and the iOS permission in context, and tapping a notification deep-links to the right screen.
  *Head start:* the notification layer now exists. `core/notifications/LocalNotifications` (timezone set-up, in-context permission, exact-alarm check, `scheduleAt`, and tap → route through `taps` / `takeLaunchRoute`) was built for O1 Fajr Call. The Android manifest receivers, desugaring and the iOS delegate are in place. F1 only needs its own channel and schedules.

- [ ] **F2 · Khatmah planner** — P1 · M
  *Done when:* you pick a finish target (7 / 15 / 30 / 60 days or a date) and get a daily portion in pages or juz'. Home shows today's portion and overall percent, completing a khatmah is celebrated and saved to history, and a khatmah can be dedicated (G2).

- [ ] **F3 · Reading history and statistics** — P1 · M
  *Where:* `WirdRepository` keeps only today's count and overwrites it each day (`wird/data/wird_repository.dart`).
  *Done when:* a count is saved per day, and a Statistics screen shows a 7- and 30-day chart, total ayahs, current and best streak, and surahs and khatmahs completed.

- [ ] **F4 · Flexible goal units** — P2 · S
  *Where:* the goal is fixed to `[5, 10, 20, 50, 100]` ayahs.
  *Done when:* the goal can be in ayahs, pages, juz' or minutes, including a custom value.

## G. Dedication and sadaqah (the app's core idea)

- [ ] **G1 · Duas for parents** — P1 · M
  *Where:* this is on the README Phase 4 roadmap, and it's the reason the app exists.
  *Done when:* there's a curated "Duas for parents" collection (for example رَّبِّ ٱرۡحَمۡهُمَا كَمَا رَبَّيَانِي صَغِيرٗا, plus the matching Quranic and prophetic duas from the adhkar dataset) on Home next to the intention card, with a counter and favourites. Every dua has a reference.

- [ ] **G2 · Several people to dedicate to** — P1 · S
  *Where:* there's one `target` + free-text `names` (`dedication/data/dedication_repository.dart`).
  *Done when:* you keep a list of people (name, relation, living or deceased), choose one or "all", each person has their own tally, and the reader's closing dua names them.

- [ ] **G3 · Dedication milestones and a share card** — P2 · S
  *Done when:* milestones are noted (100 / 1,000 ayahs, each khatmah), and you can share an image card ("I read a khatmah for my mother — remember her in your dua").

- [ ] **G4 · Family / group khatmah** — P3 · L
  *Done when:* you create a group khatmah, invite with a link, and the 30 juz' are split and tracked. Needs backend models; this is README Phase 4 "Community".

## H. Adhkar

- [ ] **H1 · Show the adhkar categories the dataset already has** — P1 · S
  *Where:* `AdhkarPeriod` is only morning and evening (`adhkar/domain/dhikr.dart`). The pinned dataset also has sleep (10), waking up (3), after prayer (9), tasabeeh (16), Quranic duas (26) and prophets' duas (13).
  *Done when:* the enum becomes a category model, the Adhkar screen lists every category, and counters and favourites work for each. Existing `morning-N` / `evening-N` ids still work.

- [ ] **H2 · Free tasbeeh counter** — P2 · S
  *Done when:* a misbaha screen has an optional target, haptics, reset and today's total.

- [ ] **H3 · Pick the adhkar period by time of day** — P2 · S
  *Done when:* Home and the Adhkar screen highlight morning before Asr and evening after.

## I. Bookmarks and notes

- [ ] **I1 · "My notes" list** — P1 · S
  *Where:* notes can only be seen inside the reader (`notes/presentation/notes_providers.dart`).
  *Done when:* the Bookmarks tab has a Bookmarks | Notes segmented control. Notes can be listed, searched, edited and deleted, and open the reader at the ayah.

- [ ] **I2 · Better bookmark cards** — P2 · S
  *Where:* cards show only the surah, ayah number and date (`bookmarks/presentation/bookmark_card.dart`). The surah name is stored in Arabic only.
  *Done when:* a snippet of the ayah text is saved and shown, and the surah name follows the UI language.

- [ ] **I3 · Bookmark collections and sorting** — P2 · S
  *Done when:* bookmarks can carry a colour or tag ("to memorise", "to reflect") and be filtered or sorted by date or mushaf order.

- [ ] **I4 · Backup and restore (export / import JSON)** — P2 · S
  *Done when:* bookmarks, notes, progress, wird, dedication and settings export to a file (share sheet) and import back. This protects your data until sync (J3) exists.

## J. Account and sync

- [x] **J1 · Check the session on startup** — P0 · S
  *Where:* `AuthNotifier._restore` trusts the stored user forever (`auth/presentation/auth_providers.dart`), while JWTs expire after `7d`.
  *Done when:* restore calls `GET /auth/me`, a 401 signs out quietly, and a Dio interceptor handles a 401 on any request the same way.
  *Done (2026-10-22):* `ApiException.statusCode`, a 401 interceptor on `ApiClient` (only for requests that sent the token), and `AuthApi.me()`. Tests: `test/auth_session_test.dart`.

- [ ] **J2 · Token in secure storage** — P1 · S
  *Where:* the token is in SharedPreferences (README known limitation).
  *Done when:* it's moved to `flutter_secure_storage`, with a one-time migration of the old key.

- [ ] **J3 · Cloud sync** — P1 · L. Split into:
  - [ ] **J3a** Backend: Prisma `Bookmark`, `Note`, `ReadingProgress`, `DailyStat`, `Dedication` and `UserSettings` models and CRUD endpoints scoped to `req.userId` (S–M)
  - [ ] **J3b** Bookmarks sync: upload and merge on first sign-in, then two-way sync by `updatedAt` (M)
  - [ ] **J3c** Notes sync (S)
  - [ ] **J3d** Progress, wird history (F3) and dedication tally sync (M)
  - [ ] **J3e** Settings sync, plus a "last synced" row and manual "Sync now" in the Account screen (S)

- [ ] **J4 · Delete account** — P1 · S
  *Where:* Apple App Store guideline 5.1.1(v) requires this for any app that lets people create an account.
  *Done when:* there's backend `DELETE /auth/me` (cascading the user's data) and a destructive row with confirmation in the Account screen.

- [ ] **J5 · Forgot / reset password** — P2 · S
  *Done when:* the backend emails a reset token, and the app has request and reset screens.

- [ ] **J6 · Edit profile** — P2 · S
  *Done when:* you can change your name, email and password from the Account screen.

- [ ] **J7 · Sign in with Apple / Google** — P3 · M

## K. Onboarding and Home

- [ ] **K1 · First-launch onboarding** — P1 · M
  *Where:* the splash goes straight to Home with silent defaults (Arabic, parents, 20 ayahs).
  *Done when:* 3–4 skippable steps cover language, who the reading is for (names, which feeds G2), daily goal, and reminders (F1). An `onboarding.done` flag stops it from showing again.

- [ ] **K2 · Ayah of the day** — P2 · S
  *Done when:* Home has a card whose ayah is chosen by the date, and you can open it in the reader or share it.

- [ ] **K3 · Home-screen widget** — P3 · M
  *Done when:* an Android and iOS widget shows today's wird progress or the ayah of the day (`home_widget`).

- [ ] **K4 · Splash waits for real start-up work** — P2 · S
  *Where:* there's a fixed 1800 ms delay (`splash/splash_screen.dart`).
  *Done when:* the splash waits for providers to load (settings, onboarding flag) with a short minimum time, and skips the animation when Reduce Motion is on.

## L. Settings and About

- [ ] **L1 · Full About and legal section** — P1 · S
  *Where:* About is currently a text card (`settings/presentation/screens/settings_screen.dart`).
  *Done when:* it has the version (`package_info_plus`), privacy policy, terms, open-source licences (`showLicensePage`), credits for data sources (alquran.cloud, mp3quran.net, islamic.network, the adhkar dataset), contact / feedback, rate the app, and share the app (sharing it is itself a sadaqah).

- [ ] **L2 · Reading and audio settings in one place** — P2 · S
  *Done when:* Settings → Reading includes the default auto-scroll speed, ayah reciter (A4), translation (C6), tafsir (C7), keep screen on (C3) and Quran font (C8).

- [ ] **L3 · Digit style** — P2 · S
  *Done when:* you can choose Western or Arabic-Indic digits and the choice applies everywhere. The redesign audit found the two mixed.

## M. Release readiness

- [x] **M1 · Real app id and name** — P0 · S
  *Where:* `com.example.lahuma` (`android/app/build.gradle.kts` lines 8 and 19) and label `lahuma` (`AndroidManifest.xml`).
  *Done when:* the app has its final id and a localised display name "لهما" / "Lahuma", with the same values on iOS.
  *Done (2026-10-22):* Android `com.lahuma.app` (namespace, applicationId, `MainActivity` package) with the label in `values/` and `values-ar/strings.xml`. iOS bundle id `com.lahuma.app` and `CFBundleLocalizations` en/ar, with the name in `en.lproj` and `ar.lproj/InfoPlist.strings`. The Android side was checked in the built APK; the iOS side wasn't built (needs a Mac).

- [x] **M2 · Release signing** — P0 · S
  *Where:* the release build is signed with the debug key (`build.gradle.kts` line 32).
  *Done when:* `key.properties` and the keystore are loaded and gitignored, and the release `signingConfig` uses them.
  *Done (2026-10-22):* `build.gradle.kts` loads `android/key.properties` (template: `android/key.properties.example`). Without it, release builds fall back to the debug key and print a warning.

- [ ] **M3 · Plain HTTP only in debug** — P1 · S
  *Where:* `android:usesCleartextTraffic="true"` is set for every build.
  *Done when:* a debug-only network security config allows `10.0.2.2` and `localhost`, and release builds use an `https` `API_BASE_URL`.

- [ ] **M4 · Crash reporting** — P1 · S
  *Done when:* Sentry or Crashlytics is wired into `main.dart` (`FlutterError.onError`, `PlatformDispatcher.onError`), with no personal data sent.

- [ ] **M5 · iOS project settings** — P2 · S (needs a Mac)
  *Done when:* the display name, `CFBundleLocalizations` (ar, en), background audio mode (A3) and notification usage strings (F1) are set.

## N. Quality and tech debt

- [ ] **N1 · Finish the Apple redesign** — P1 · M
  *Where:* per `docs/apple-redesign/PROGRESS.md`, only Splash, Account and Home are converted. These still import Material: the Quran list, reader and its sheets (ayah actions, tafsir/translation, options, note dialog), Bookmarks, Settings, the MP3Quran list and player, the reciter player, and the goal and dedication sheets.

- [ ] **N2 · Tests for untested logic** — P1 · M
  *Done when:* there are unit tests for `ReadingTracker` crediting, the bookmarks, notes and dedication notifiers, auth restore/logout (J1), and `SurahDetail` basmala stripping, plus one integration test (open surah → scroll → bookmark → reopen from Bookmarks).

- [ ] **N3 · Delete dead code** — P2 · S
  *Where:* redesign audit §4 lists `GlassNavigationBar`, `LahumaBottomNavigation`, the old `core/widgets/app_button|app_text_field|app_card`, `AppTextStyles` and the standalone `Mp3QuranRecitersScreen` route.
  *Done when:* they're removed with approval. Keep or reuse `ReciterListView` for B1.

- [ ] **N4 · One shared `ApiClient`** — P2 · S
  *Where:* `reciterDataSourceProvider` creates its own `ApiClient()` (`quran/presentation/providers/reciter_providers.dart`).
  *Done when:* it uses `apiClientProvider`, so the auth header and interceptors (J1) apply everywhere.

- [ ] **N5 · Remove the localhost workaround and the unused audio asset** — P2 · S
  *Where:* the `10.0.2.2` ↔ `localhost` swap and the asset fallback in `quran/services/quran_audio_service.dart`, and `assets/audio/Quran reciters/Ahmed bin Ali Al-Ajmi/001.mp3`, which is bundled but unused.

- [ ] **N6 · Choose one way to handle strings** — P2 · S
  *Where:* `AppLocalizations` is generated from ARB files but never used, and every string is an inline `context.tr(ar, en)`.
  *Done when:* there's a single approach. Moving to ARB makes it possible to add a third UI language (French, Urdu…).

## O. Fajr Call (نداء الفجر)

At Fajr the app calls the people you chose, one by one, to wake them for prayer. See [fajr-call.md](fajr-call.md) for the design, limits, Play-policy notes and the manual test script.

- [x] **O1 · Domain, storage and offline Fajr time** — P1 · M
  *Done:* lists, contacts, attempts and sessions as JSON models; SharedPreferences repository (30 sessions); `PrayerTimesService` (`adhan`, Algeria 18°/17° by default); `FajrSchedule` with DST-safe fire times. Fajr matches api.aladhan.com within 1 minute in the tests.
- [x] **O2 · Manual mode on both platforms** — P1 · M
  *Done:* lists, editor, log, wake list and permissions screens (Apple design, RTL / LTR, light / dark, 1.6× text); a time-sensitive notification opens the wake list (`tel:` and "استيقظ ✓"); Home shortcut and next-call card; Settings row.
- [x] **O3 · Android auto-call engine** — P1 · L
  *Done:* Kotlin foreground service (`specialUse`), `setAlarmClock` per list, boot / time / timezone / update rescheduling, `TelecomManager.placeCall` with dual-SIM choice, `endCall` with a fallback, call-state listener, optional call-log answer detection (`-PfajrCallLog=true`), and JUnit tests for the call loop.
- [ ] **O4 · Device check on OEM Android** — P1 · S
  *Done when:* the manual test script in `fajr-call.md` passes on a Xiaomi/Redmi, a Samsung and an Infinix/Tecno phone on Android 13–16, including `endCall` and the battery steps.
- [ ] **O5 · iOS signing** — P2 · S (needs a Mac)
  *Done when:* the Time Sensitive Notifications capability is added in Xcode and the wake-list flow is checked on an iPhone.

## X. Backend work that blocks mobile features

- [x] **X1 · Admin-only routes** — P0 · S
  *Where:* any account registered from the mobile app gets a JWT that passes `requireAuth`. That's enough to call `POST`/`DELETE /reciters`, upload audio, and `GET`/`POST /users` (`backend/src/modules/reciters/reciters.routes.ts`, `users/users.routes.ts`).
  *Done when:* `User` has a `role` and a `requireAdmin` middleware guards these routes. This has to land before mobile sign-up goes public.
  *Done (2026-10-22):* `Role` enum (USER / MODERATOR / ADMIN) plus migration `20261022120000_add_user_role`, `requireAdmin`, and `npm run make-admin -- <email>`. `/auth/*` now returns `role`, and the admin panel refuses non-admin logins. **Run `npm run prisma:migrate` and promote your admin account before using the panel again.**

- [ ] **X2 · Rate limits beyond auth** — P2 · S
  *Where:* the README says only the auth routes are rate-limited. Sync endpoints (J3) will need limits too.
