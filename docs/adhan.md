# Adhan (الأذان)

At each prayer time, **while the app is open**, Lahuma plays the full adhan of the muezzin the user picked through its own audio player (the adhan player screen, with a stop button). It never plays the adhan as a notification or alarm sound. In the background or with the app closed, nothing plays: the user gets a **silent** notification, and tapping it opens the app and plays the adhan.

The settings are under **Settings → الصلاة → الأذان** (`/settings/adhan`).

## How it works

| | Android | iOS |
|---|---|---|
| Prayer times | From the Home prayer-times feature (Aladhan API, method 19), cached a week ahead | Same |
| App open at prayer time | `AdhanForeground` opens the player screen, which plays the full mp3 with just_audio (media volume); the silent notification shows too | Same |
| App in the background or closed | Silent notification (channel `adhan_prayer_silent`, no sound); a tap opens the player | Silent notification (no sound), Time Sensitive |
| What plays | The downloaded full file, else the bundled `assets/audio/adhan/default_regular_v2.mp3` | Same |
| Days scheduled | 7 days, plus a reminder before every prayer | 7 days (35 adhans), plus reminders for the next 2 days only (10) |

- **In the app:** `AdhanForeground` (`presentation/adhan_foreground.dart`) is active while the app is in the foreground (resumed, or inactive behind the notification shade). It arms one timer for the next enabled adhan from the same plan as the notifications, and re-arms when the app comes back and when the settings or the times change. When it fires, it opens `/adhan/play?prayer=…`; if the player is already open (the notification was just tapped), it leaves it playing. The silent notification still shows, as it does with the app closed; tapping it while the player is open does nothing. Coming back to the app up to a minute after a prayer time still plays it; later, it doesn't.
- **Once per prayer:** the id of the last adhan played in the app is kept in prefs (`adhan.lastPlayed`). Ids grow with time, so a resume, a relaunch or the notification's tap never plays the same adhan twice.
- **Interruptions:** the player is the app's shared adhan player: it stops the Quran players before it starts (`AudioFocus`), and just_audio pauses it for calls. It keeps playing if the user leaves the app mid-adhan, until the system stops the app.
- **Fajr** uses the muezzin's Fajr recording (with «الصلاة خير من النوم»); the other four prayers use the regular one. The bundled default has a single recording, so it plays at Fajr too.
- **Prayer times are not calculated on the device.** The adhan schedules from the same timings Home shows (`upcomingPrayerDaysProvider`). The prayer-times notifier keeps 7 days cached: today and tomorrow come from `/timings`, and the rest of the week from the monthly `/calendar` endpoint (1–2 requests). With no location and nothing cached, nothing is scheduled, and the screen offers to set the location.
- **Notification ids** are stable: `yyyymmdd·10 + prayer` (Fajr 0 … Isha 4), and `+5` for the reminder. They range from 200 000 000 to 220 000 000, clear of Fajr Call's ids.
- **Rescheduling** (of the notifications) happens on every launch and resume, after a muezzin download, and when the enabled prayers, the reminder, the master switch, the prayer times (that is, the location) or the app language change. Each sync cancels every pending adhan id and schedules the week again.
- **Android channels:** `adhan_prayer_silent` (no sound, high importance) for the adhans and `adhan_reminder` (default notification sound) for the reminders. Each sync deletes any other `adhan_*` channel, including the old ones that had the adhan as their sound.
- **Exact timing:** every adhan and reminder is an alarm clock (`AndroidScheduleMode.alarmClock`, i.e. `setAlarmClock`) when "Alarms & reminders" is allowed (Android 12+). It shows the alarm icon in the status bar, but it is the only exact alarm that Doze and OEM battery savers leave alone. ColorOS (OPPO / OnePlus / realme), for one, turns `setExactAndAllowWhileIdle` alarms into a one-hour window, so the notification could arrive up to an hour late. Without the permission the alarms are inexact, with the same one-hour window.
- **No times, no wipe:** while the adhan is on but the prayer times haven't loaded yet (they load after the settings at launch), a reschedule keeps the pending adhans instead of cancelling them.
- **Permissions** are asked the first time the user turns the adhan on (or picks a muezzin while it is off), never at launch: notifications first, then a short explanation and the exact-alarm settings page on Android 12+. Afterwards the settings screen shows a warning row for each thing still missing, re-checked whenever the app resumes: notifications off (opens the prompt, or the app's settings page once refused) and exact alarms off. Neither is needed for the adhan to play while the app is open.
- **Test the adhan:** a row on the settings screen queues the chosen prayer's adhan in `AdhanForeground`, 10 seconds ahead, through the same path as a real one, and schedules its silent notification for the same moment. The sound plays only if the app is still open then; leaving the app drops it, but the notification still comes. Test ids are `220000000 + prayer`, above the planner's range, and don't count as the real prayer having played.

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
| Seed | [`backend/prisma/seed.ts`](../backend/prisma/seed.ts): 3 placeholder muezzins, upserted by fixed id |
| Env | `MEDIA_BASE_URL`: the public origin of the bucket. A stored URL starting with `/` is prefixed with it; an absolute URL is returned as is. |

```bash
cd backend
npx prisma migrate deploy      # or: npm run prisma:migrate   (dev)
npx prisma db seed             # or: npm run prisma:seed
```

There is no admin UI or upload endpoint for muezzins yet: add rows with Prisma Studio (`npx prisma studio`) or SQL.

### Storage bucket

Any public-read object storage works (S3, Cloudflare R2, GCS, Supabase Storage…). The seed expects this layout under `MEDIA_BASE_URL`:

```
adhan/<slug>/regular.mp3          full adhan
adhan/<slug>/fajr.mp3             full Fajr adhan
adhan/<slug>/regular_short.caf    ≤ 30 s
adhan/<slug>/fajr_short.caf       ≤ 30 s
```

with `<slug>` = `makkah`, `madinah`, `algiers`.

- Content types: `audio/mpeg` for mp3, `audio/x-caf` for caf, `audio/wav` for wav.
- **When you replace a file, bump `version` and change the URL** (for example `adhan/makkah/v2/regular.mp3`). Apps only download again when `version` changes, and a CDN may keep serving the old file from the same URL.
- No CORS rule is needed; only the mobile app fetches these files.

## Audio files

### The bundled default adhan

The default is «أذان إدريس من الجزائر» (3:38, mono 96 kbps, leading and trailing silence trimmed). It has no Fajr version, so all five prayers play it:

| File | Format | Used for |
|---|---|---|
| `mobile/android/app/src/main/res/raw/adhan_default_regular.mp3` | mp3, full length | Unused since the notifications are silent (kept for now) |
| `mobile/ios/Runner/adhan_default_regular.caf` | IMA4 caf, first 29 s with a fade | iOS notification fallback |
| `mobile/assets/audio/adhan/default_regular_v2.mp3` | mp3, full length | In-app player (tap) and preview, both platforms |

Only the asset copy is played now (just_audio). The `res/raw` and `.caf` copies, and the publishing of downloaded files as notification sounds (MediaStore, FileProvider, `Library/Sounds`), are left over from when the notification played the adhan; they can be removed in a cleanup.

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

1. **Backend:** set `MEDIA_BASE_URL` in `backend/.env`, run the migration and the seed (above), and upload the files to the bucket.
2. **Audio:** the bundled default is in place (see above); only the muezzins' files need uploading.
3. **Xcode:** nothing to add for the sound: the adhan plays from the Flutter asset. (`adhan_default_regular.caf` is still in the Runner target, unused.)
4. **Xcode:** the *Time Sensitive Notifications* capability (see [Fajr Call](fajr-call.md#ios)), if it isn't on already. Without it, a Focus mode can hide the prayer-time notification.
5. **Test on a device:** with the app open, use «تجربة الأذان» for each prayer and check the player opens and plays within 10 seconds, and that Stop stops it. Then set a prayer a minute ahead (or change the device time): with the app open it plays; in the background or closed, only a silent notification appears, and tapping it plays the adhan.

## Known limits

- **The app must be open** for the adhan to play by itself. With the screen locked or the app in the background, Android and iOS only show the silent notification; this is deliberate (no alarm or notification sound, no background workarounds).
- Leaving the app mid-adhan keeps it playing until the system stops the app; there is no media notification to stop it from outside.
- **Android:** on reinstall the app loses ownership of its old MediaStore entries. They stay in `Notifications/Lahuma/` until the user deletes them, and new ones are created.
- If the phone stays offline for more than a week, the schedule runs out after the last cached day. Opening the app with a connection tops it up.
