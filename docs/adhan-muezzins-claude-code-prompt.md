# Prompt for Claude Code: Real muezzins for the Adhan feature

> Paste everything below the line into Claude Code, opened at the root of the repo.

---

You are working in **Ihsan (إحسان)**, formerly Lahuma, a Quran app. The Adhan feature is already built end to end (read `docs/adhan.md` first):

- **Backend:** `Muezzin` model in `backend/prisma/schema.prisma`, `GET /api/muezzins` in `backend/src/modules/muezzins/`, and `resolveMediaUrl` in `muezzins.service.ts`, which prefixes paths starting with `/` with `MEDIA_BASE_URL`.
- **Seed:** `backend/prisma/seed.ts` only has **3 placeholder muezzins whose files don't exist**.
- **Mobile:** `mobile/lib/features/adhan/` lists the muezzins, previews `regularUrl`, and downloads `regularUrl` + `fajrUrl` (Android), plus `regularShortUrl` + `fajrShortUrl` on iOS (30 seconds or less, `.caf`, used as notification sounds). Then it schedules the adhan.

**Your job:** replace the placeholders with **real muezzins and real audio**, taken from the open collection **Kiwifu/adhan-mp3** on GitHub. Prepare the files properly, serve them from our backend, and make sure the app downloads and plays them at prayer time on Android and iOS.

**Before writing code:** read the files above, then send me the plan in §6 Phase 0 and wait for my OK.

## 1. The source

- Repo: `https://github.com/Kiwifu/adhan-mp3`. 224 MP3s at the root. No JSON index. No formal license file; the README says the files are free for Islamic and prayer-time apps.
- **Pin this commit, never `main`:** `b9180a2bb769f74cff8e378ef2cc7aaf8db5cd5b`
- Download URL (choose one):
  - `https://raw.githubusercontent.com/Kiwifu/adhan-mp3/<commit>/<filename>`
  - `https://cdn.jsdelivr.net/gh/Kiwifu/adhan-mp3@<commit>/<filename>`
- Filenames contain Arabic, spaces-as-underscores and brackets, so **percent-encode them** (`encodeURIComponent`).
- **The app must never stream from GitHub or jsDelivr in production.** We download once, process the files, and host them ourselves.

## 2. The muezzins to import

Pair one **regular** adhan with one **Fajr** adhan (the one with «الصلاة خير من النوم»). Start with these. Exact filenames:

| slug | nameAr | nameFr | country | regular file | fajr file |
|---|---|---|---|---|---|
| `alafasy` | مشاري راشد العفاسي | Mishary Rashid Alafasy | KW | `Mishary_Rashid_Alafasy_1_-_Kuwait_(مشاري_راشد_العفاسي_-_الكويت).mp3` | `Mishary_Rashid_Alafasy_3_-_Fajr_Kuwait_(مشاري_راشد_العفاسي_-_فجر_الكويت).mp3` |
| `makkah` | أذان الحرم المكي | Adhan de La Mecque | SA | `Ali_Ibn_Ahmad_Mala_1_-_Al_Haram_Al_Maki_(علي_بن_أحمد_ملا_-_الحرم_المكي).mp3` | `Adhan_Fajr_Al_Haram_Al_Maki_(أذان_الفجر_الحرم_المكي).mp3` |
| `madinah` | أذان المسجد النبوي | Adhan de Médine | SA | `Adhan_Al_Haram_Al_Madani_-_Al_Madinah_1_(أذان_الحرم_المدني_-_المدينة_المنورة).mp3` | `Adhan_Fajr_Al_Haram_Al_Madani_(أذان_الفجر_الحرم_المدني).mp3` |
| `abdulbasit` | عبد الباسط عبد الصمد | Abdulbasit Abdusamad | EG | `Abdulbasit_Abdusamad_1_-_Egypt_(عبد_الباسط_عبد_الصمد_-_مصر).mp3` | `Abdulbasit_Abdusamad_7_-_Fajr_Egypt_(عبد_الباسط_عبد_الصمد_-_فجر_مصر).mp3` |
| `algeria` | أذان الجزائر | Adhan d'Algérie | DZ | `Riad_Al_Djazairi_-_Algeria_(رياض_الجزائري_-_الجزائر).mp3` | `Adhan_Fajr_Algeria_(أذان_الفجر_الجزائر).mp3` |

Notes:
- **Put `algeria` first** (`sortOrder` 0); most users are in Algeria.
- **Some files are suspiciously small** (0.3–0.5 MB) and may be short clips. Your script must measure every file (§3) and **report it to me before seeding**.
- **`makkah` and `algeria` pair two different muezzins.** Flag this in the report.
- Also list the repo's other candidates, especially more Algerian ones (`Waled_Mahsas_*`, `Haj_Sulaiman_Mukhtar_-_Algeria`, `Fajr_Adhan_by_Nasreddine_Toubar`), with their durations, so I can add more later.

## 3. Import script: `backend/src/scripts/importAdhans.ts`

Add an npm script, `npm run adhan:import`. It must be **idempotent** (re-running it skips files that are already done and unchanged) and driven by a manifest.

1. **Manifest:** `backend/prisma/data/muezzins.json` holds the §2 table, plus `source: { repo, commit, regularFile, fajrFile }` for each row. It is the single source of truth for both the script and the seed.
2. **Download** each file to `backend/media-src/adhan/<slug>/` (gitignored). Use retries and a timeout. Check the HTTP status and that the content type is audio.
3. **Probe with ffprobe:** duration, bitrate, sample rate, channels.
   - **Under 60 s** → mark as a probable clip, warn, and don't seed it unless the manifest says `"allowShort": true`.
   - **Over 6 min** → warn.
4. **Process with ffmpeg** (fail with a clear message if ffmpeg isn't installed):
   - **Full files** → `backend/public/adhan/<slug>/regular.mp3` and `fajr.mp3`: trim leading and trailing silence (`silenceremove`), normalise loudness (`loudnorm` to about −16 LUFS, true peak −1.5 dB), mono, 44.1 kHz, MP3 at 96–128 kbps. A 300 ms fade-in and a 1.5 s fade-out.
   - **iOS short clips** → `regular_short.caf` and `fajr_short.caf`: the first **≤ 29.5 s**, with a 2 s fade-out ending at the cut. CAF container, a codec iOS accepts as a notification sound (`ima4`/`adpcm_ima_qt` or linear PCM; keep each file small). Match the format of the existing `mobile/ios/Runner/adhan_default_regular.caf` (probe it).
5. Write a **SHA-256 of each output**. If a file's hash changed since the last run, bump that muezzin's `version` in the manifest, so the app re-downloads it (see the version logic in `docs/adhan.md`).
6. Print a summary table: slug, file, source duration → output duration, size, warnings.

## 4. Backend

- **Serve the files:** add `app.use("/adhan", express.static(...public/adhan, { maxAge: "30d", immutable: true }))` in `server.ts`. Use correct MIME types (`audio/mpeg`, `audio/x-caf`) and support HTTP `Range` (express.static does).
  - **In development**, `MEDIA_BASE_URL=http://10.0.2.2:4000` (Android emulator) or the machine's LAN IP for a real phone. Update `.env.example` and the docs.
  - **In production**, the same `/adhan/<slug>/…` tree is uploaded to the bucket and `MEDIA_BASE_URL` points to it. Add an `npm run adhan:upload` stub or document the `aws s3 sync` / `rclone` command, whichever fits our storage.
- **Seed:** rewrite the muezzin part of `prisma/seed.ts` to read `prisma/data/muezzins.json`. Keep the stored paths **relative** (`/adhan/<slug>/regular.mp3`, …). Keep the existing fixed ids for the 3 old slugs (`makkah`, `madinah`, `algiers` → now `algeria`), so installed apps that selected them keep a valid id. Give the new rows new fixed ids. Deactivate (`isActive: false`) any manifest row that failed checks.
- **Optional, ask me first:** an admin endpoint `POST /api/admin/muezzins/:id/bump-version` and a simple **Muezzins** page in `client/` (list, toggle active, reorder, play preview), following the style of `RecitersPage.tsx`.
- **Tests** (Jest): `resolveMediaUrl` with the new paths; `GET /api/muezzins` returns the seeded rows in `sortOrder` with absolute URLs; the static route serves an `.mp3` with `audio/mpeg` and answers a `Range` request with 206.

## 5. Mobile: verify, then fix only what's needed

The client already exists, so **don't rewrite it**. Check each point and fix only what fails:

1. The picker (Settings → الصلاة → الأذان) shows the 5 muezzins in order, in Arabic (`nameAr`), with French or English when the app is in English if that's how it's localised today, and a country flag or label if the design has one.
2. Preview streams `regularUrl` from our backend and takes audio focus correctly.
3. Selecting a muezzin downloads both files (and both `.caf` files on iOS) with progress, all or nothing, into `<app support>/adhan/<id>/v<version>/`, deleting the previous muezzin's files.
4. **Android:** the Fajr alarm plays `fajr.mp3` and the others play `regular.mp3` through `AdhanPlaybackService`. "Test the adhan" works with the app swiped away.
5. **iOS:** the notification uses the short `.caf` from `Library/Sounds`, and tapping it plays the full file.
6. A version bump on the server makes the app re-download it on the next launch, then reschedule.
7. **Offline:** after one successful download, the picker list and the adhan work with no network.
8. **Error state:** if `MEDIA_BASE_URL` is wrong or a file returns 404, the row shows a clear, localised error and the previous choice stays.
9. `usesCleartextTraffic` is already on for dev HTTP. Make sure release builds use HTTPS only (debug manifest or network security config), and note it.

Optionally (ask me): replace the bundled fallback (`res/raw/adhan_default_regular.mp3` and `ios/Runner/adhan_default_regular.caf`) with the processed `algeria` regular adhan, so the default sounds local.

## 6. Phases

- **Phase 0 (plan):** read the files, then send me the plan, the exact ffmpeg commands you'll use, and any open questions. **Wait for my OK.**
- **Phase 1:** manifest + import script. Run it and **send me the summary table** (durations, clips, warnings). **Wait for my OK on the final list.**
- **Phase 2:** backend static route, seed, env and docs, tests. Run `npm test`, then `npx prisma db seed`, then `curl /api/muezzins` and `curl -I` on one file.
- **Phase 3:** mobile checks 1–9 from §5 with fixes. Run `flutter analyze` and `flutter test`, then test on an Android emulator, and on iOS if available.
- **Phase 4:** update `docs/adhan.md` (source, commit, processing pipeline, how to add a muezzin), plus a **Credits** section listing every muezzin and source file, and the README.

**Rules:**
- Don't commit downloaded source files (`media-src/`).
- Commit the processed files in `backend/public/adhan/` only if the total is under ~25 MB. Otherwise gitignore them and rely on the import script plus bucket upload. Tell me which you chose.
- Work on the branch `feature/real-muezzins` and commit after each phase.
