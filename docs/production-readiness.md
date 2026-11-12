# Production readiness (audit of 2026-11-11)

What was checked across the mobile app, the backend and the admin panel, what was fixed, and what is still left before publishing.

## Health at the time of the audit

| Part | Check | Result |
|---|---|---|
| Mobile | `flutter analyze` | no errors; 2 warnings in a test (fixed), 9 infos in a diagnostic integration test |
| Mobile | `flutter test` | 437 / 437 passing |
| Mobile | `flutter build apk --release` | builds (R8 on); 137 MB universal APK |
| Backend | `tsc` + `jest` | clean, 21 / 21 → 30 / 30 after the new tests |
| Admin | `tsc -b` + `oxlint` + `vite build` | clean |

## Fixed

### Mobile

- **Release builds pointed at the emulator's dev server.** With no `--dart-define=API_BASE_URL`, a release talked to `http://10.0.2.2:4000` (and release blocks plain http), so sign-in, muezzin downloads and reciters would all fail in the store build. Android release builds now stop with a clear message unless `API_BASE_URL` is an `https://` URL.
- **An app bundle could be signed with the debug key.** `bundleRelease` now fails without `android/key.properties`; a Play upload signed with the debug key can never be updated.
- **Quran text requests had no timeout.** On a weak connection the reader could spin for minutes before falling back to the offline copy; now 10 s to connect, 20 s to receive.
- **A damaged Hive file stopped the app at the launch screen.** The bookmarks and Quran cache boxes are recreated if they can't be opened.
- **A damaged saved session threw at start-up.** It now signs out quietly to guest.
- **Uncaught async errors** are logged through `PlatformDispatcher.onError` instead of being lost.
- **The 10.0.2.2 ↔ localhost audio URL swap** now only runs in debug builds.
- **iOS privacy manifest** (`ios/Runner/PrivacyInfo.xcprivacy`): the app's own Swift code uses `UserDefaults`, which App Store Connect requires to be declared (reason `CA92.1`).
- **iOS export compliance:** `ITSAppUsesNonExemptEncryption = false` (HTTPS only), so App Store Connect stops asking at every upload.

### Backend

- **Validation errors answered 500 "Something went wrong".** A bad email or short password at sign-up now gets a 400 with the reason; malformed JSON gets a 400 too.
- **Emails were case-sensitive.** `Parent@Example.com` at sign-up and `parent@example.com` at login were different accounts. Emails are now trimmed and lower-cased, and looked up case-insensitively so older mixed-case accounts still sign in.
- **Admin-created users got a shared default password** (`LahumaUser123!`) when none was given. The password is now required (8–72 characters), and the role is validated.
- **No graceful shutdown.** Node as PID 1 ignored `SIGTERM`, so every `docker compose up` / restart killed the API mid-request after 10 s. It now drains and exits.
- **The Quran proxy had no upstream timeout** (10 s now, answered as 502).
- `X-Powered-By: Express` is no longer sent.

### Admin panel

- **Fake data shown as real.** When the API failed (or returned 401), the Users page silently showed five invented users; the dashboard always showed invented numbers ("42 active readers", "1,284 bookmarks") and an invented activity log. All of that is gone: the dashboard shows real users, admins, reciters, uploaded Surahs and the API's health, and errors are shown as errors.
- **"Add user" pretended to succeed.** On any failure it added a fake row. It now shows the server's error, and asks for the password.
- **The Settings page saved nothing.** Its form only flashed "Saved". It is now a read-only status page that says where the configuration really lives.
- **"Player concept" page removed:** a demo player streaming unrelated music from a third-party CDN.
- The fake per-user status toggle and the "Last active" column (which showed `updatedAt`) were removed.

## Still to do before publishing

1. **Bundle the fonts.** Cairo and Scheherazade New come from `google_fonts`, which downloads them from Google at run time. On a first launch without a connection the whole UI (and the Arabic text) falls back to the system font, and each new install contacts Google's servers. Put the TTFs in `mobile/assets/google_fonts/`, list that folder under `assets:`, and set `GoogleFonts.config.allowRuntimeFetching = false` in `main()`.
2. **Create the Android upload key** (`android/key.properties.example`) and keep it and its passwords backed up.
3. **iOS on a Mac:** signing team for Runner and the `PrayerBanner` extension (added to the project by hand), the *Time Sensitive Notifications* capability, `pod install`, and one archive build. Nothing checks `API_BASE_URL` on iOS: always pass it.
4. **Server:** `.env` with the real `DOMAIN` and `POSTGRES_PASSWORD`, `backend/.env` with a 32+ character `JWT_SECRET`, `npm run adhan:import` before building the image, then the seed (README › Production Deployment). Back up the `postgres_data` and `reciter_audio` volumes.
5. **Store listings need a privacy policy URL.** The app sends the approximate location to Aladhan for prayer times, and the email/name to your server for optional accounts.
6. **Google Play declarations:** exact alarms (`SCHEDULE_EXACT_ALARM`), the `specialUse` foreground service (Fajr Call), `CALL_PHONE` / `ANSWER_PHONE_CALLS`, and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` each need a justification in Play Console; expect review questions about the calling permissions.
7. **Size.** Per-device download from Play is about 85 MB (the Mushaf fonts of `qcf_quran` are 55 MB). Build with `--obfuscate --split-debug-info=build/symbols` and keep the symbols.
8. **On-device testing** of the parts that unit tests can't reach (several are marked untested in the docs): the adhan with the app killed, Fajr Call, the prayer banner / Live Activity, Now Playing controls and surah downloads, on at least one Android 14+ phone and one iPhone.
9. **Crash reporting** (Firebase Crashlytics or Sentry) is not set up; without it, store crashes are only visible in the Play / App Store consoles.
