# Adhan (الأذان)

At each prayer time Lahuma plays the adhan of the muezzin the user picked, even with the app closed. Tapping the notification opens the app and plays the full-length adhan, with a stop button.

The settings are under **Settings → الصلاة → الأذان** (`/settings/adhan`).

## How it works

| | Android | iOS |
|---|---|---|
| Prayer times | From the Home prayer-times feature (Aladhan API, method 19), cached a week ahead | Same |
| Notification sound | The full adhan mp3, played on the alarm stream | The short (≤ 30 s) `.caf` / `.wav` clip, at the Time Sensitive level |
| Where the sound comes from | Copied into MediaStore `Notifications/Lahuma/` (Android 10+), or served by a FileProvider with a read grant (Android 7–9). Always a `content://` URI, never `file://`. | Copied into `Library/Sounds`, referenced by file name |
| Fallback | `res/raw/adhan_default_regular.mp3` | `Runner/adhan_default_regular.caf` |
| Days scheduled | 7 days, plus a reminder before every prayer | 7 days (35 adhans), plus reminders for the next 2 days only (10) |

- **Fajr** uses the muezzin's Fajr recording (with «الصلاة خير من النوم»); the other four prayers use the regular one. The bundled default has a single recording, so it plays at Fajr too.
- **Prayer times are not calculated on the device.** The adhan schedules from the same timings Home shows (`upcomingPrayerDaysProvider`). The prayer-times notifier keeps 7 days cached: today and tomorrow come from `/timings`, and the rest of the week from the monthly `/calendar` endpoint (1–2 requests). With no location and nothing cached, nothing is scheduled, and the screen offers to set the location.
- **Notification ids** are stable: `yyyymmdd·10 + prayer` (Fajr 0 … Isha 4), and `+5` for the reminder. They range from 200 000 000 to 220 000 000, clear of Fajr Call's ids.
- **Rescheduling** happens on every launch and resume, after a muezzin download, and when the enabled prayers, the reminder, the master switch, the prayer times (that is, the location) or the app language change. Each sync cancels every pending adhan id and schedules the week again.
- **Android channels:** one channel per muezzin, sound and version (`adhan_<muezzinId>_<regular|fajr>_v<version>`), because a channel's sound can't change once it exists. There are also `adhan_default_regular_v<n>`, `adhan_default_fajr_v<n>` (both with the bundled sound; `n` is `AdhanScheduler.defaultSoundVersion`) and `adhan_reminder`. Each sync deletes any other `adhan_*` channel. Channels use alarm audio usage and max importance.
- **Exact timing:** `exactAllowWhileIdle` when "Alarms & reminders" is allowed (Android 12+), otherwise inexact, which can run a few minutes late.
- **Permissions** are asked the first time the user turns the adhan on (or picks a muezzin while it is off), never at launch: notifications first, then a short explanation and the exact-alarm settings page on Android 12+.

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
| `mobile/android/app/src/main/res/raw/adhan_default_regular.mp3` | mp3, full length | Android notification fallback |
| `mobile/ios/Runner/adhan_default_regular.caf` | IMA4 caf, first 29 s with a fade | iOS notification fallback |
| `mobile/assets/audio/adhan/default_regular.mp3` | mp3, full length | In-app player (tap) and preview, both platforms |

The same mp3 goes in `res/raw` and `assets/audio/adhan`. Android needs the `res/raw` copy for the notification, and just_audio needs the asset copy.

To replace it, overwrite these three files (keeping the names) and bump `AdhanScheduler.defaultSoundVersion`, so Android creates the default channels again. To add a separate Fajr default, add `adhan_default_fajr.mp3` / `.caf` / `default_fajr.mp3` next to them, return the Fajr names from `AdhanScheduler.defaultSoundName` and `adhanDefaultAsset` again, and bump the version.

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
3. **Xcode:** add `adhan_default_regular.caf` to the **Runner** target. Drag it into the Runner group, tick *Copy items if needed* and *Runner* under *Target Membership*, and check it appears under *Build Phases → Copy Bundle Resources*. Files in the folder but not in the target aren't bundled, and iOS falls back to the system sound.
4. **Xcode:** the *Time Sensitive Notifications* capability (see [Fajr Call](fajr-call.md#ios)), if it isn't on already. Without it, a Focus mode can silence the adhan.
5. **Test on a device**, not an emulator, for the sound: set a prayer a few minutes ahead (or temporarily change the device time), lock the phone, and check the adhan plays, that a muezzin's Fajr recording plays at Fajr, and that a tap opens the player.

## Known limits

- **iOS** can only play ≤ 30 s at notification time; the full adhan needs the tap. It also respects the silent switch unless the app has Apple's Critical Alerts entitlement, which isn't requested here.
- **Android 7–9:** the FileProvider grant doesn't survive a reboot. The app publishes the sound again on every launch, so a reboot followed by an adhan before the app is next opened may play the default notification sound instead.
- **Android:** on reinstall the app loses ownership of its old MediaStore entries. They stay in `Notifications/Lahuma/` until the user deletes them, and new ones are created.
- If the phone stays offline for more than a week, the schedule runs out after the last cached day. Opening the app with a connection tops it up.
