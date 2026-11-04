# Adhan (الأذان)

At each prayer time Lahuma plays the full adhan of the muezzin the user picked. Each prayer is set to **adhan**, **silent notification** or **off**.

- **Android:** an exact alarm starts a native player, a `mediaPlayback` foreground service that plays it as a notification sound (notification volume, never the alarm). It plays the full adhan whether the app is open, in the background, swiped away, or the phone was restarted. Its notification has a Stop button.
- **iOS:** a notification whose sound is a clip of the adhan (30 seconds at most). Tapping it opens the app, which plays the full adhan. With the app open, the app plays the full adhan itself.

The settings are under **Settings → الصلاة → الأذان** (`/settings/adhan`). On Android, **ضمان رفع الأذان** (`/settings/adhan/reliability`) checks the permissions and explains each phone maker's battery settings. Turning the adhan on asks, after notifications and exact alarms, for the user to let Lahuma run in the background (an explanation, then the system "ignore battery optimisations" dialog), unless it already may.

## How it works

| | Android | iOS |
|---|---|---|
| Prayer times | Aladhan API (method 19), from the cache. A background run fetches whole months, and calculates locally only when it is offline with no cached day | Same, but there are no background runs |
| At prayer time, in any app state | `setAlarmClock` → `AdhanAlarmReceiver` → `AdhanPlaybackService` plays the full file with `MediaPlayer` on `USAGE_NOTIFICATION` | A Time Sensitive notification with the clip as its sound |
| App open | The native player plays it; the app doesn't play it a second time | `AdhanForeground` opens the player screen; the notification stays quiet in the foreground |
| What plays | The muezzin's downloaded full file (the Fajr file at Fajr), else `res/raw/adhan_default_regular.mp3` | Clip: the muezzin's short .caf, else `adhan_default_regular.caf`. Full: the download, or the bundled asset |
| Silent prayers and reminders | `flutter_local_notifications` alarm clocks | Same |
| Days scheduled | 7 days (up to 35 alarms), plus reminders | 7 days (35), plus reminders for 2 days (10): the adhan's 45 of the 64 slots |
| After a reboot, an update, or a clock or timezone change | `AdhanBootReceiver` re-arms the stored alarms at once, then a WorkManager job runs the Dart reschedule headlessly | iOS keeps the pending notifications itself |
| Safety net | A daily WorkManager job runs the same reschedule | Every launch and resume |

### Android engine (`android/app/src/main/kotlin/com/lahuma/app/adhan/`)

- `AdhanAlarmChannel` (`lahuma/adhan_alarm`): Dart sends the planned alarms (id, time, prayer, title, body, file) and the native strings. The Dart side is `lib/features/adhan/data/adhan_alarm_platform.dart`.
- `AdhanAlarmStore` keeps the alarms in their own prefs file, so a reboot can re-arm them without Flutter.
- `AdhanAlarms` sets one `setAlarmClock` per adhan. The request code is the planner's id, and each PendingIntent has its own data URI, so nothing collides with Fajr Call. Without "Alarms & reminders" it falls back to `setAndAllowWhileIdle`.
- `AdhanAlarmReceiver` starts `AdhanPlaybackService`. On Android 12–14, an alarm from `setAlarmClock` is one of the exemptions that let a background app start a foreground service. If the start is refused anyway (an inexact alarm, or an OEM), the receiver posts a notification on `adhan_alert` that opens `/adhan/play`. An alarm that arrives more than 10 minutes late is skipped.
- `AdhanPlaybackService` (`foregroundServiceType="mediaPlayback"`) calls `startForeground` first, then plays with `MediaPlayer` (`USAGE_NOTIFICATION`, a partial wake lock, transient audio focus). `setAlarmClock` only times it: ColorOS stretches `setExactAndAllowWhileIdle` to a one-hour window (seen on a OnePlus for the khatma reminder). It stops on any of these:
  - Stop, or a swipe of the notification;
  - the end of the file;
  - an error (a broken download falls back to the bundled file first);
  - losing audio focus, for example to a call;
  - 10 minutes, whatever happens.

  Its notification channel is `adhan_playing`: high importance and silent, since the service plays the sound.
- `AdhanAlarmChannel` also checks, when the app's engine starts and before Dart re-arms anything, whether the next adhan still ahead has lost its alarm (`AdhanAlarms.wereCleared`). There is no API to list an app's own alarms, and a force-stop leaves PendingIntents in place, so the check uses `AlarmManager.getNextAlarmClock()`: every adhan is an alarm clock, so when the next alarm clock is later than our next adhan, or there is none, ours was cancelled. If another app's alarm clock comes first, the check can't tell, and stays quiet. That means the app was force-stopped since the last arm. Alarms armed before the last boot don't count, since a reboot clears them too and `AdhanBootReceiver` re-arms them. Dart reads the answer once (`takeCleared`). After the splash, `showAdhanClearedNoticeIfNeeded` tells the user no adhan played since, and offers the reliability steps. The notice shows at most once every 3 days.
- `AdhanBootReceiver` handles `BOOT_COMPLETED`, `QUICKBOOT_POWERON`, `MY_PACKAGE_REPLACED`, `TIME_SET`, `TIMEZONE_CHANGED` and `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`.
- `AdhanWorker` / `AdhanWork` start a headless Flutter engine at `adhanBackgroundMain` (`lib/main.dart`). That runs `AdhanBackgroundReschedule` (`lib/features/adhan/background/adhan_background.dart`), which reads the saved settings and muezzin, gets the times from `PrayerDaysSource` (no GPS, no BuildContext), then uses the same planner and scheduler as the app. The work is unique: `adhan_daily_reschedule` runs every 24 h, and `adhan_reschedule_now` runs after a boot and the other broadcasts above.

### Shared rules

- **Per-prayer mode:** `AdhanSettings.prayers` holds the prayers that aren't off, and `silent` the ones that get a silent notification. Settings saved before modes existed read as adhan for every enabled prayer.
- **Fajr** uses the muezzin's Fajr recording (with «الصلاة خير من النوم»); the other four use the regular one. The bundled default has a single recording, so it plays at Fajr too.
- **Prayer times:** the adhan schedules from the same timings Home shows. `LocalPrayerTimes` (the `adhan` package, Fajr 18°, Isha 17°) is only the offline fallback in background runs. Its days aren't cached, so Aladhan replaces them once online. It can differ from Aladhan by a minute or two.
- **Ids** are stable: `yyyymmdd·10 + prayer` (Fajr 0 … Isha 4), and `+5` for the reminder. They range from 200 000 000 to 220 000 000, clear of Fajr Call's ids. Test alarms are `220000000 + prayer`.
- **Rescheduling** happens:
  - on every launch and resume;
  - after a muezzin download;
  - on any settings change;
  - when the prayer times (that is, the location) or the app language change;
  - in the Android background runs.

  Each sync replaces every adhan alarm and notification.
- **Android channels:** `adhan_prayer_silent` (silent prayers, and every adhan if the engine is missing), `adhan_reminder`, and the engine's `adhan_playing` and `adhan_alert`. Each sync deletes any other `adhan_*` channel.
- **Permissions** are asked when the adhan is turned on: notifications first (Android 13+), then exact alarms (Android 12+, `SCHEDULE_EXACT_ALARM`, granted from "Alarms & reminders"). Battery optimisation is asked from the reliability screen, after an explanation. The settings screen warns about each one still missing.
- **Test the adhan** plays the chosen prayer in 10 seconds. On Android it is a native test alarm, so it plays even if the app is closed. A long press on the row shows **اختبار: الأذان بعد دقيقة** (always shown in debug builds). It arms a Dhuhr test one minute ahead, long enough to swipe the app away first.

## Muezzins and downloads

- `GET /api/muezzins` (public) returns the active muezzins, ordered by `sortOrder`. The app caches the list in SharedPreferences (`adhan.muezzins`), so the picker works offline after the first load.
- Each row has a play/stop preview that streams `regularUrl` with just_audio (it takes audio focus from the Quran players).
- Picking a muezzin downloads all its files with a progress bar. Android downloads `regularUrl` and `fajrUrl`; iOS also downloads the two short files. A download is all or nothing. If it fails, the previous choice (or the bundled default) stays and the row says so.
- Files live in `<app support>/adhan/<muezzinId>/v<version>/`. Picking another muezzin, or "الأذان الافتراضي", deletes the other files, their MediaStore entries and their `Library/Sounds` copies.
- When the server's `version` for the selected muezzin is higher than the downloaded one, the app downloads it again in the background on the next launch, then reschedules.

## Backend

| | |
|---|---|
| Model | `Muezzin` in [`backend/prisma/schema.prisma`](../backend/prisma/schema.prisma) |
| Migration | `20261029120000_add_muezzins` |
| Endpoint | `GET /api/muezzins` → `{ muezzins: [...] }` |
| Manifest | [`backend/prisma/data/muezzins.json`](../backend/prisma/data/muezzins.json): the muezzins, their source files, and what the import produced |
| Import | `npm run adhan:import` ([`src/scripts/importAdhans.ts`](../backend/src/scripts/importAdhans.ts)): downloads, processes and publishes the files into `public/adhan/` |
| Seed | [`backend/prisma/seed.ts`](../backend/prisma/seed.ts): upserts the manifest's rows by fixed id; a row that failed the import is seeded inactive |
| Files | `GET /adhan/<slug>/v<version>/<file>`, served by the backend from `public/adhan/` (30-day `immutable` cache, `Range` support) |
| Env | `MEDIA_BASE_URL`: the public origin of the files. A stored URL starting with `/` is prefixed with it; an absolute URL is returned as is. |

```bash
cd backend
npm run adhan:import           # needs ffmpeg; fills public/adhan/ (gitignored)
npx prisma migrate deploy      # or: npm run prisma:migrate   (dev)
npx prisma db seed             # or: npm run prisma:seed
```

`MEDIA_BASE_URL` in development:

| Device | `MEDIA_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:4000` |
| Real phone on the same Wi-Fi | `http://<this machine's LAN IP>:4000` (and run the app with `--dart-define=API_BASE_URL=http://<LAN IP>:4000/api`) |
| iOS simulator | `http://localhost:4000` |

The server reads `.env` once at start, so restart it after changing this.

There is no admin UI for muezzins: change the manifest, re-run the import, then the seed.

### Hosting the files

The layout under `MEDIA_BASE_URL` is:

```
adhan/<slug>/v<version>/regular.mp3          full adhan
adhan/<slug>/v<version>/fajr.mp3             full Fajr adhan
adhan/<slug>/v<version>/regular_short.caf    ≤ 29.5 s, iOS notification sound
adhan/<slug>/v<version>/fajr_short.caf       ≤ 29.5 s
```

The version is in the path because the files are cached as `immutable`: a re-processed file gets a new URL, and the import bumps `version` so apps download it again. The import keeps only the current version of each muezzin in `public/adhan/`.

**Production, served by the backend (the default).** Set `MEDIA_BASE_URL` to the API's public HTTPS origin. `public/adhan/` is gitignored (about 29 MB), so run `npm run adhan:import` on the machine that builds the image: `docker compose build` copies `public/adhan/` into the image (`.dockerignore` leaves out `media-src/`). Or copy the tree to the server and mount it at `/app/public/adhan`.

**Production, from a bucket or CDN (later).** Any public-read object storage works (S3, Cloudflare R2, GCS…). Upload the same tree, then point `MEDIA_BASE_URL` at the bucket's origin:

```bash
# rclone (any S3-compatible remote, configured with `rclone config`)
rclone sync backend/public/adhan <remote>:<bucket>/adhan   --header-upload "Cache-Control: public, max-age=2592000, immutable"
# AWS CLI
aws s3 sync backend/public/adhan s3://<bucket>/adhan   --cache-control "public, max-age=2592000, immutable"
```

Check that the bucket serves `audio/mpeg` for mp3 and `audio/x-caf` for caf (set it with `--header-upload "Content-Type: …"` per extension if not). No CORS rule is needed; only the mobile app fetches these files.

## Audio files

### The bundled default adhan

The default is «أذان إدريس من الجزائر» (3:38, mono 96 kbps, leading and trailing silence trimmed). It has no Fajr version, so all five prayers play it:

| File | Format | Used for |
|---|---|---|
| `mobile/android/app/src/main/res/raw/adhan_default_regular.mp3` | mp3, full length | Android native player |
| `mobile/ios/Runner/adhan_default_regular.caf` | IMA4 caf, first 29 s with a fade | iOS notification sound |
| `mobile/assets/audio/adhan/default_regular_v2.mp3` | mp3, full length | In-app player (tap) and preview, both platforms |

The Android MediaStore / FileProvider publishing of downloaded files (`AdhanSoundChannel`) is left over from when a channel played the adhan; the native player reads the downloaded files directly. A replaced default must also replace the `res/raw` copy.

To replace it, add the new recording to `assets/audio/adhan/` under a **new name** (bump the `_v` suffix), point `adhanDefaultAsset` at it and delete the old file. just_audio copies an asset to its cache the first time it plays it and keeps playing that copy, so a recording replaced under the same name keeps playing the old one on phones that already played it. To add a separate Fajr default, add a Fajr file the same way and return it from `adhanDefaultAsset` for Fajr.

Android resource names must stay lowercase letters, digits and `_`. Don't add a second file with the same base name (for example both `.mp3` and `.wav`), or the build fails. `res/raw/keep.xml` stops R8 from stripping these sounds in release builds, since they're referenced only by name from Dart.

### Converting

Full length, for Android and the in-app player (mono, 96 kbps keeps a 3-minute adhan near 2 MB):

```bash
ffmpeg -i adhan.wav -ac 1 -ar 44100 -b:a 96k regular.mp3
```

Short clip for iOS. iOS plays the default sound instead if the file is longer than 30 seconds, so trim it to 29 s with a fade, then convert it to IMA4 CAF:

```bash
# trim (any platform)
ffmpeg -i regular.mp3 -t 29 -af "afade=t=out:st=26:d=3" -ac 1 -ar 22050 regular_short.wav
# convert (macOS)
afconvert regular_short.wav regular_short.caf -d ima4 -f caff
```

Without a Mac, ffmpeg can write the CAF directly:

```bash
ffmpeg -i regular.mp3 -t 29 -af "afade=t=out:st=26:d=3" -ac 1 -ar 22050 -c:a adpcm_ima_qt -f caf regular_short.caf
```

iOS notification sounds must be `.caf`, `.wav` or `.aiff` (Linear PCM, IMA4, µLaw or aLaw), never mp3. «الصلاة خير من النوم» comes late in the Fajr adhan, so a 29-second clip from the start won't include it. If you want the phrase in the notification itself, cut the Fajr short clip around it. The full recording still plays when the user taps.

## Manual steps

1. **Backend:** set `MEDIA_BASE_URL` in `backend/.env`, run the import, the migration and the seed (above).
2. **Audio:** the bundled default is in place (see above); the muezzins' files come from the import.
3. **Xcode:** check that `adhan_default_regular.caf` is in the Runner target's *Copy Bundle Resources*. It is the notification sound.
4. **Xcode:** turn on the *Time Sensitive Notifications* capability (see [Fajr Call](fajr-call.md#ios)) if it isn't on already. Without it, a Focus mode can hide the prayer-time notification.
5. **Test on a device:** follow the checklist below.

## Manual test checklist (Android)

Use a real phone, on Android 12, 13 and 14 if possible. Turn the adhan on, allow notifications and "Alarms & reminders", and keep the notification volume up. `adb logcat -s Adhan flutter` shows what happens.

1. **App killed**
   1. Long-press «تجربة الأذان» to show the debug row, then tap **اختبار: الأذان بعد دقيقة**.
   2. Check that the test alarm is listed: `adb shell dumpsys alarm | grep -A3 com.lahuma.app`.
   3. Press Home, then run `adb shell am kill com.lahuma.app`. This kills the process the way Android does in the background, and the alarms stay.
   4. Within a minute, the adhan plays at notification volume with a «إيقاف» notification.

   A swipe from Recents is a different test. On stock Android it only kills the process, like `am kill`. ColorOS (OnePlus, Oppo, Realme) force-stops the app instead (`Force stopping com.lahuma.app … o-stop` in logcat), and that cancels every alarm. See **Force stop** below.
2. **Stop**
   1. While a test plays, tap «إيقاف»: the sound stops and the notification goes.
   2. Start another test and swipe the notification away (Android 14): it stops too.
   3. Let a third test run to the end: the notification disappears by itself.
3. **Reboot**
   1. With the adhan on, run `adb reboot`.
   2. After unlocking, without opening the app, check that `adb shell dumpsys alarm | grep -c lahuma-adhan` counts the week's alarms (up to 35).
   3. Check that `adb shell dumpsys jobscheduler | grep -i lahuma` shows the WorkManager jobs.
   4. A test alarm armed before the reboot still plays.
4. **Doze**
   1. Arm the 1-minute test and turn the screen off.
   2. Run `adb shell dumpsys deviceidle force-idle`.
   3. The adhan still plays on time.
   4. Afterwards, run `adb shell dumpsys deviceidle unforce`.
5. **Exact alarms denied**
   1. Revoke "Alarms & reminders" in system settings: the adhan settings show a warning.
   2. A test may now come late, or only as a notification (`adhan_alert`) that opens the in-app player.
   3. Grant the permission again: the alarms are re-armed (the permission-changed broadcast).
6. **Force stop**
   1. Arm the 1-minute test, then run `adb shell am force-stop com.lahuma.app`, or swipe Lahuma away from Recents on ColorOS.
   2. Nothing plays, and `adb shell dumpsys alarm | grep -c adhan.FIRE` prints 0.
   3. Open the app: after the splash, «توقّف الأذان» says the adhans were stopped, and «الخطوات» opens the reliability screen. The count is back up.
   4. Force-stop and open the app again: no notice this time, because it waits 3 days.
7. **Modes:** set Dhuhr to «إشعار صامت» and Asr to «متوقف». `dumpsys alarm` lists no Asr alarm, and Dhuhr arrives as a silent notification.
8. **Timezone:** change the phone's timezone. The alarms are re-armed and, after the background run, move to the new local times.
9. **iOS**
   1. Run the 10-second test with the app in the background: the 29-second clip plays.
   2. Tap the notification: the full adhan plays.
   3. With the app open, only the in-app player is heard.

## Known limits

**Android**
- A **force stop** cancels all of an app's alarms until it is opened again. That is Android's rule, and no app can work around it. It happens through Settings → Force stop and some OEM "clean" buttons. On ColorOS (OnePlus, Oppo, Realme) a plain swipe from Recents does it too. This was seen on a OnePlus PJX110 with Android 14 and battery saver on. Stock Android only kills the process on a swipe. The app can't prevent it, but on the next launch it notices and tells the user (see `wereCleared` above). ColorOS also refuses to lock an app in Recents while Power saving mode is on.
- Some OEM battery savers (Xiaomi, Oppo/Realme, Huawei, older Samsung) still kill the alarms or the service unless the user follows the steps on the reliability screen. The makers' settings pages are private and change between versions, so the app only tries them and falls back to its own settings page.
- Without "Alarms & reminders" (Android 12+; off by default for new installs on Android 14), the alarm is inexact and Android won't let it start the player. The user then gets a notification that opens the adhan in the app.
- The adhan plays at **notification volume**, not as an alarm, so silent mode and Do Not Disturb mute it.
- The status bar shows the alarm-clock icon for the next adhan. That is the cost of `setAlarmClock`.
- A background run uses the saved location, so a trip is only noticed when the app is opened. There is no background GPS.
- If the phone stays offline for weeks, background runs use the cached months, then the local calculation, which can differ from Aladhan by a minute or two.
- Android 15+ forbids starting a `mediaPlayback` service from `BOOT_COMPLETED`. The engine never does: it only starts the service from the alarm.
- On reinstall, the app loses ownership of its old MediaStore entries in `Notifications/Lahuma/`, left over from when a channel played the adhan.

**iOS**
- No app code runs at a scheduled time, and a notification sound is 30 seconds at most, so only the clip plays by itself. The full adhan needs a tap, or the app open. The clip has no Stop; it ends on its own.
- iOS keeps 64 pending notifications per app, shared with Fajr Call (15) and the khatma (4). The adhan keeps 7 days (35) plus 2 days of reminders (10). If the app isn't opened for a week, the schedule runs out.
- The silent switch mutes the clip, and a Focus can hide it unless Time Sensitive notifications are allowed.
