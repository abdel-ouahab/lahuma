# Lahuma mobile — performance audit

Phase 1: a read-only audit of `mobile/`. Nothing has been measured yet, so every impact below is an estimate to be confirmed in Phase 2 (Baseline). No code has changed.

## The app as it is

- Flutter, Arabic RTL-first, light and dark themes, Cupertino-style design system (`lib/core/design/`). 230 Dart files, about 39.5k lines.
- State: Riverpod 2 (`StateNotifierProvider`, `FutureProvider`). Navigation: go_router 14.
- Network: Dio over REST, not GraphQL. Sources:
  - the Node backend (`backend/`, through `core/network/api_client.dart`);
  - api.alquran.cloud (Quran text and translations);
  - mp3quran (reciters);
  - Aladhan (prayer times);
  - Quran.com (reciter photos).
- Local storage: Hive (bookmarks, Quran cache, adhkar cache) and SharedPreferences.
- Heavy dependencies: `qcf_quran` (Mushaf, 604 page fonts), `video_player` (Now Playing backgrounds), `just_audio`, `google_fonts`, `sensors_plus`, `flutter_compass`.
- Heaviest screens:
  - Home: prayer hero with painters, lanterns and a 1 s countdown, plus a sliver feed of cards.
  - Surah reader: `ScrollablePositionedList`.
  - Mushaf: `qcf_quran` pages.
  - MP3Quran reciters: about 200 rows with network photos.
  - Now Playing: looping video.
  - Qibla: compass at sensor rate.
- There's no `integration_test/` or `test_driver/` yet.

## Findings, by estimated impact

| # | Impact | Area | Where | Issue |
|---|---|---|---|---|
| 1 | High | Startup | `lib/features/splash/splash_screen.dart:36` | Home always waits a fixed 1.8 s after the splash appears |
| 2 | High | Network / UX | `lib/features/quran/data/quran_remote_data_source.dart:15,30-41` | No timeouts, and the network is always tried first; the cache is only used after a failure |
| 3 | High | Battery / raster | `lib/features/prayer_times/presentation/widgets/prayer_lanterns.dart:15-23,66,89-96,121-129` | 60 Hz accelerometer stream for as long as Home is mounted; lantern repaints aren't isolated |
| 4 | Medium-high | Build time / network | `lib/core/design/app_typography.dart:41-42,53-77`, `lib/core/theme/app_text_styles.dart` | Every text-style getter calls `GoogleFonts.*()`; fonts aren't bundled, so they're fetched at runtime |
| 5 | Medium-high | Startup / memory | `lib/main.dart:32-33` | `quran_cache_box` is opened before `runApp`, and Hive loads the whole box into memory |
| 6 | Medium | Build time / battery | `lib/features/prayer_times/presentation/widgets/prayer_times_section.dart:40,58-66` | `setState` every second rebuilds the whole prayer section, even when Home is covered |
| 7 | Medium | Startup | `lib/main.dart:36-40`, `lib/core/notifications/local_notifications.dart:6,105` | Before `runApp`: the full timezone database is decoded, and the notification plugin and native route lookup are awaited |
| 8 | Medium | Network | `lib/features/mp3quran/presentation/mp3quran_reciters_screen.dart:421` | Reciter photos use `Image.network` without a disk cache, so they're downloaded again every session |
| 9 | Medium | App size | release APK; `android/app/build.gradle.kts` | Universal APK of 85.6 MB; QCF fonts are about 55 MB; no ABI split |
| 10 | Low-medium | UI thread | `lib/features/quran/data/quran_remote_data_source.dart:34,38` | `jsonEncode` / `jsonDecode` of whole surahs runs on the UI isolate |
| 11 | Low | Startup memory | `lib/features/splash/splash_screen.dart:106-110`, `assets/images/logo.png` | A 1024×1024 PNG (624 KB) is decoded at full size for a 200 pt logo |
| 12 | Low | App size | `qcf_quran` package assets | About 0.7 MB of the package's screenshots ship in the APK |
| 13 | Medium | App size | `assets/audio/adhan/default_regular_v2.mp3`, `android/app/src/main/res/raw/adhan_default_regular.mp3` | The same 2.6 MB adhan is shipped twice (identical MD5) |

### 1. Fixed 1.8 s splash delay (high)

`SplashScreen.initState` waits on `Future.delayed(1800 ms)` before `context.go('/home')`, however fast the app is ready. That makes 1.8 s the floor for time-to-Home on every cold start.

- **Fix options:**
  - shorten the delay;
  - go to Home as soon as the first Home frame is ready, with the logo animation (900 ms) as the minimum.
- **Ask first:** this changes how long the splash is visible, which is a UI decision.

### 2. Quran API: no timeouts, network first (high)

`QuranRemoteDataSource` builds its own `Dio` with only `baseUrl`, so connect and receive timeouts are unlimited. `_getData` always goes to the network and reads the Hive cache only after the request fails. On a weak or captive connection, opening a surah can hang until the OS gives up, even though the cache already has it. Every launch also downloads the surah list again.

- **Fix, without a behaviour change:** add timeouts like `ApiClient` (10 s / 10 s).
- **Fix, with a behaviour change:** serve the cached copy first and refresh it in the background. The Quran text never changes, so this is safe.
- **Ask first:** cache-first changes when the network is used.

### 3. Lanterns: sensor stream and repaint (high, to confirm)

`PrayerLanterns` subscribes to `accelerometerEventStream(SensorInterval.uiInterval)` (about 60 Hz) in `initState` and keeps the subscription until Home is disposed. The shell keeps Home mounted under pushed routes, so the subscription stays even when Home isn't visible.

In a hand, the sensor never settles. Each event moves `_target`, which restarts the ticker, so the pendulum keeps running and repaints. The `CustomPaint` has no `RepaintBoundary`, so every repaint also repaints the layer around it: the hero card and probably more of Home.

- **Fix, invisible to the user:**
  - wrap the lanterns in a `RepaintBoundary`;
  - pause the sensor subscription while the route isn't current (`TickerMode` / `RouteAware`) or the app isn't resumed;
  - ignore target changes below a small dead-band so the ticker can rest.
- **Measure:** Home idle, phone in hand: frames per second and raster time.

### 4. `GoogleFonts` on every style access, with runtime fetching (medium-high)

`AppTypography.largeTitle`, `body` and the other styles are getters, and each call goes to `GoogleFonts.cairo(...)` or `GoogleFonts.scheherazadeNew(...)`. That builds a new `TextStyle` and goes through google_fonts' loader every time, many times per frame on busy screens. `lib/core/theme/app_text_styles.dart` does the same.

`assets/fonts/` is empty and `allowRuntimeFetching` is left on, so the first launch downloads Cairo and Scheherazade from fonts.gstatic.com. Until they arrive, text shows in the fallback font and then reflows. With no connection, the brand fonts never show.

- **Fix:**
  - bundle the font files that are used under `assets/fonts/`, which google_fonts picks up automatically;
  - set `GoogleFonts.config.allowRuntimeFetching = false`;
  - turn the getters into cached `static final` styles. Desktop/iOS still picks the system font, so that branch keeps working.
- **Cost:** the APK grows by the size of the bundled fonts.
- **Measure:** frame build time on Home and the reader, and first-launch time with no network.

### 5. Hive cache box opened before `runApp` (medium-high, grows with use)

`main()` awaits `Hive.openBox<String>(quran_cache_box)`. A normal `Box` reads every entry into memory when it opens. The box holds whole surahs as JSON text, one entry per surah and edition, so startup time and memory grow with every surah the user opens.

- **Fix:** keep the behaviour the same and move the cost off the startup path:
  - open the box lazily on first use;
  - or use `LazyBox`, which reads one entry at a time.
- **Measure:** the box size on the phone, and startup with a full cache.

### 6. Countdown `setState` every second (medium)

`_PrayerTimesSectionState` runs `Timer.periodic(1 s)` and calls `setState`. That rebuilds the hero (painters, city chip, lanterns), the countdown card and the prayer strip. Only the countdown text and the ring progress actually change each second.

A `Timer` isn't paused by `TickerMode`, so it keeps rebuilding while another route covers Home, and while the app is in the background for as long as the process lives.

- **Fix:**
  - put the time in a `ValueNotifier` that only the countdown and ring listen to;
  - stop the timer while the app isn't resumed or Home isn't current.
- **Measure:** frame build time on an idle Home.

### 7. Work awaited before `runApp` (medium)

Before the first frame, `main()` does three things in order:

1. `tzdata.initializeTimeZones()` decodes the full IANA database (`timezone/data/latest.dart`) synchronously.
2. `FlutterTimezone.getLocalTimezone()` makes a platform call.
3. `_plugin.initialize` and `getNotificationAppLaunchDetails()` run, then `FajrCallPlatform().takeLaunchRoute()`.

The launch route is read only after the 1.8 s splash, so most of this could run in parallel with the first frame.

- **Fix:**
  - run independent awaits together (`Future.wait`);
  - start the notification setup before `runApp` but await it only where the route is needed;
  - possibly use `latest_10y.dart` (smaller). That needs a check that every saved timezone exists in it.
- **Measure:** time to first frame.

### 8. Reciter photos without a disk cache (medium, network)

`Image.network` with `cacheWidth` is already right for memory. But the image cache only lives in memory, so each session downloads every visible portrait again from Quran.com.

- **Fix:** a disk cache for these images. Either add `cached_network_image`, or write a small file cache with `path_provider` + Dio (already dependencies).
- **Ask first:** adding a package.

### 9. APK size (medium)

The last release APK (`build/app/outputs/flutter-apk/app-release.apk`, built on 29 Oct) is 85.6 MB with 1,003 entries. The biggest parts:

- the 604 QCF page fonts from `qcf_quran`, about 55 MB on disk;
- `libapp.so` (13 MB) and `libflutter.so` (11.7 MB) for arm64.

`build.gradle.kts` has no ABI split. Shrinking/minify settings still need checking in Phase 2 with `--analyze-size`.

- **Fix:**
  - ship an App Bundle (Play delivers one ABI per device), or build with `--split-per-abi`;
  - check that R8/resource shrinking is on.
- **Not changed:** the QCF fonts are the Mushaf itself. Downloading them on demand would change behaviour.

### 10. Surah JSON on the UI isolate (low-medium)

After each fetch, `jsonEncode(data)` serialises the whole surah on the UI isolate, and the cache path `jsonDecode`s it there too. Al-Baqarah with translations is a few hundred KB, which can drop frames during the page transition. Dio itself already decodes large responses in the background (`BackgroundTransformer`).

- **Fix:** `Isolate.run` / `compute` for the encode and decode over a size threshold.

### 11. Splash logo decoded at 1024² (low)

The logo is drawn at 200 pt (600 px at 3x) but decoded at 1024×1024, about 4 MB of pixels, during the most crowded moment of startup.

- **Fix:** `cacheWidth`/`cacheHeight` from the device pixel ratio, or ship a 600 px PNG. It looks the same.

### 12. `qcf_quran` ships its screenshots (low)

The package declares `assets/` as a whole, so `Screenshot_*.png` (about 0.7 MB) goes into the APK.

- **Fix:** none without forking or overriding the package. Note it only.

### 13. The default adhan ships twice (medium, app size)

Found in the Phase 2 size report. Flutter plays `assets/audio/adhan/default_regular_v2.mp3` in the app, and the native adhan service plays `res/raw/adhan_default_regular.mp3`. The two files are byte-for-byte identical (MD5 `2383bd38…`), so the APK carries 2.6 MB twice.

- **Fix:** keep one copy. Either the native service opens the Flutter asset (`FlutterLoader.getLookupKeyForAsset` + `AssetManager.openFd`), or Flutter plays the raw resource through a native call.
- **Ask first:** it touches the adhan engine, so it needs a device test of the closed-app adhan.

## Checked and fine

- Long lists are lazy:
  - the reciters screen uses `ListView.builder`;
  - the reader uses `ScrollablePositionedList.builder`;
  - the surah list and bookmarks are builders too.
- The `ListView(children:)` cases are short settings or permission pages.
- The `listEntrance` animations stop after the first few rows (`_kStaggeredRows`) and respect Reduce Motion.
- Every `CustomPainter` has a precise `shouldRepaint`, except the static `_RingsPainter`, which correctly returns false.
- The shell's mini-player watches only fields that change rarely. The playback state has no position stream.
- Controllers, tickers and subscriptions that I read are disposed (lanterns, pulse, countdown timer, Fajr Call lantern, Qibla).
- No `DateFormat` or `RegExp` is built in `build()`. JSON parsing is limited to small SharedPreferences values, apart from #10.

## Seen but not to be changed (would change the look)

- The mini-player's `BackdropFilter` (blur σ 20, `lib/core/design/widgets/app_mini_player.dart:73-74`) sits over scrolling content while audio plays, which costs raster time on each scroll frame. It's part of the design, so I'll only measure it.
- Now Playing's looping video backdrop is a deliberate design choice (see the player-backdrop decisions). I'll measure it, not change it.

## Decisions needed before Phase 3

1. **Splash (#1):** may time-to-Home be shorter than 1.8 s? If yes, what should the minimum be?
2. **Quran cache (#2):** cache-first for Quran text and the surah list? Timeouts alone don't change behaviour.
3. **Photo cache (#8):** add `cached_network_image`, or a small cache built on existing dependencies?
4. **Fonts (#4):** OK to bundle the Cairo and Scheherazade New files (APK grows) and turn off runtime fetching?
5. **Branch:** `feature/khatma` has a lot of uncommitted work. Phase 2 needs `perf/optimization`; should it start from `main`, or from `feature/khatma` once your work is committed?

## Measurement plan (Phase 2)

- Add `integration_test` and write `integration_test/perf_test.dart` with these scenarios:
  - cold start to Home;
  - fling the reciters list and the surah reader up and down;
  - Home → Quran → Mushaf → Reciters and back;
  - Home idle for 10 s, for #3 and #6.
- Add `test_driver/perf_driver.dart` to write timeline summaries to `build/perf/`.
- Run it in profile mode on the OnePlus PJX110 (Android 14).
- Also record: `flutter build apk --analyze-size`, cold-start time from `adb shell am start -W`, and the size of `quran_cache_box` on the device.
- Network-dependent scenarios will be noisy, so they'll run with the cache warm, and with and without Wi-Fi.

## Baseline

Measured on 2026-11-04 on branch `perf/optimization` at `5f61239`, in profile mode, on the only device connected: an **x86_64 Android emulator** (Android 9, reporting itself as a Samsung SM-G998B). You chose the emulator because the OnePlus was disconnected.

Emulator raster times include the emulated GPU waiting for vsync. They read about 16.5 ms whenever something redraws continuously, and most of those frames count as "missed raster budget". **Use frame counts and build times to compare, not absolute raster times.** Every Phase 3 comparison runs on the same emulator.

How to run it again:

```
cd mobile
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
```

The summaries are written to `mobile/build/perf/*.timeline_summary.json`, and `metrics.json` holds the time to Home.

### Startup

| Metric | Value |
|---|---|
| `main()` → Home on screen (includes the 1.8 s splash) | 2,782 ms |
| Android cold start, `am start -W` TotalTime (6 runs) | 1,222 / 1,227 / 1,236 / 1,302 / 1,370 / 1,510 ms, median **1,269 ms** |
| Engine → first Flutter frame (`--trace-startup`, 3 runs) | 643 / 618 / 2,520 ms; median **643 ms** (the 3rd run was an outlier) |
| Engine → first frame rasterised | 746 / 717 / 2,589 ms |
| Framework init → first frame (mostly `main()` before `runApp`) | 296 / 260 / 591 ms |

### Frames per scenario (ms)

| Scenario | Frames | Build avg / p90 / p99 / worst | Raster avg / p90 / p99 / worst | Missed build / raster |
|---|---|---|---|---|
| startup | 18 | 4.1 / 9.7 / 29.3 / 29.3 | 29.6 / 39.3 / 253.6 / 253.6 | 2 / 8 |
| home_idle (10 s) | **255** | 0.4 / 0.8 / 1.8 / 2.2 | 16.5 / 16.9 / 18.0 / 27.4 | 0 / 233 |
| home_scroll | 83 | 1.9 / 3.9 / 4.6 / 5.2 | 17.8 / 21.7 / 26.3 / 38.2 | 0 / 61 |
| navigation | 137 | 1.4 / 3.1 / 7.1 / 13.9 | 7.5 / 16.6 / 18.0 / 28.6 | 0 / 35 |
| surah_list_scroll | 235 | 0.2 / 0.2 / 1.1 / 1.7 | 3.8 / 4.4 / 5.9 / 7.0 | 0 / 0 |
| reader_scroll | 56 | 2.7 / 3.6 / 5.2 / 6.0 | 3.3 / 3.5 / 5.1 / 6.8 | 0 / 0 |
| reciters_images | 225 | 0.2 / 0.2 / 0.8 / 1.3 | 16.5 / 16.9 / 17.2 / 18.0 | 0 / 214 |

What the baseline shows:

- **Home redraws about 25 times a second while nothing happens** (255 frames in 10 s). The countdown needs about 10. This is the clearest target, and it supports #3 (lanterns) and #6 (countdown).
- Build times are low everywhere (p99 under 8 ms outside startup), so #4 shows up mostly as first-launch font fetching, not as slow frames on this device.
- Startup's worst raster frame is 254 ms: the first frame with all the Home painters.
- The reciters scenario also redraws continuously at about 16.5 ms per frame after the photos have loaded. Phase 3 will check what keeps redrawing there.

### App size

| Build | Size |
|---|---|
| Release APK, arm64 only (`--analyze-size --target-platform android-arm64`) | **90.1 MB** (90,143,712 bytes) |
| Of which `flutter_assets` (mostly the QCF Mushaf fonts) | 59.4 MB |
| Of which `libapp.so` (Dart AOT) | 13.8 MB |
| Of which `libflutter.so` (engine) | 11.8 MB |
| Of which `res/raw` adhan mp3 (a duplicate, see #13) | 2.6 MB |
| Profile APK (all ABIs) | 162.7 MB |

The detailed size report is in `C:\Users\pcomr\.flutter-devtools\apk-code-size-analysis_01.json`; open it with `dart devtools --appSizeBase=<that file>`.

### Not measured yet

- Memory, since the summaries carry no Dart heap figures. Phase 3 will use `flutter run --profile` and the DevTools memory view.
- `quran_cache_box` size on a phone that has used the app for a while (#5). The emulator's cache is nearly empty.
