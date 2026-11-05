# Lahuma (لهما)

> لهما — قرآنٌ يُتلى، وأجرٌ يُهدى.

Lahuma is a Quran mobile application created with the intention of being a **continuous charity (Sadaqah Jariyah) for parents**. This repository contains the preliminary MVP: a Flutter mobile app and a Node.js/TypeScript backend.

## Overview

The MVP lets anyone browse and read the full Quran **as a guest, with no login required**, track their last reading position locally, and bookmark Ayahs. A minimal backend with email/password + JWT auth is scaffolded for future account sync (Phase 3) but is not required for using the app today.

## Features

- Splash: the native launch screen hands over to an animated one (the shamsa, the gilded medallion that opens a Mushaf, gathers around the إحسان wordmark) that waits for real start-up work (saved theme and language, the cached prayer times, a notification's screen) and never more than 5 s
- Introduction, shown once and again from Settings: six pages with living miniatures of the features (the Mushaf and reciters, the khatma, prayer times and the qibla, Fajr Call, the tasbih and adhkar), then language and look; Arabic RTL and English, light and dark, Reduce Motion and large text; no permission prompts until the features need them
- Home with "Last read", today's wird (daily goal + streak) and reading intention
- Surahs (search by name or number), 30 juz', and reciters tabs; reader opens at the exact ayah (last read, bookmark, juz')
- Reader: saves your real position, text size, jump to ayah, English translation (Sahih International), Arabic tafsir (Al-Muyassar), per-ayah audio that continues through the surah, copy/share, personal notes
- Reading intention: dedicate your recitation to your parents (or someone else); every ayah read is counted and the dua closes each surah
- Offline: any surah/translation/tafsir you've opened once is cached and readable without a connection
- Bookmarks with swipe-to-delete and undo
- Fajr Call (نداء الفجر): at Fajr the app phones your parents and loved ones one by one to wake them for prayer (Android), or reminds you with a one-tap call list (iOS / manual mode), then shows who was called and who is awake. Offline Fajr time (Algerian method by default), everything stays on the device. See [docs/fajr-call.md](docs/fajr-call.md)
- Adhan (الأذان): the full adhan at each prayer time, from five real muezzins (Algeria first) downloaded once from our backend, with the Fajr recording at Fajr. Android plays it natively with the app closed; iOS plays a 29.5 s clip as the notification sound and the full adhan on tap. See [docs/adhan.md](docs/adhan.md)
- Settings: language (Arabic/English, whole UI), theme, text size, goal, intention, optional account
- Optional account (sign in / create / sign out) against the backend; the whole app works as a guest
- Backend: register / login / get current user (JWT), plus a thin Quran API proxy

## Tech Stack

**Mobile:** Flutter, Dart, Material 3, Riverpod, GoRouter, Dio, SharedPreferences, Hive  
**Backend:** Node.js, TypeScript, Express, PostgreSQL, Prisma, JWT, Docker  
**Client Admin Panel:** React.js, Vite, TypeScript, React Router, Lucide Icons, Custom CSS Design System  

## Project Structure

```text
lahuma/
├── mobile/           # Flutter mobile application
├── backend/          # Node.js TypeScript API
├── client/           # React.js Admin Panel Dashboard
│   └── src/
│       ├── components/   # Sidebar, Navbar, StatCard, StatusBadge
│       ├── context/      # AuthContext, ThemeContext
│       ├── pages/        # Dashboard, Users, Quran, Settings, Login
│       ├── services/     # API client & backend connection
│       └── types/        # TypeScript interfaces
├── docker-compose.yml
└── README.md
```

## Requirements

- Flutter SDK ≥ 3.44 (Dart ≥ 3.12). Current plugin versions need it; `share_plus` 13 already required 3.38.
- Node.js ≥ 20
- Docker & Docker Compose
- PostgreSQL 16 (via Docker, or local install)
- ffmpeg and ffprobe, only to (re)build the muezzin audio (`npm run adhan:import`; Windows: `winget install Gyan.FFmpeg`)

## Installation

```bash
git clone <this-repo>
cd lahuma
```

## Flutter Setup

```bash
cd mobile
flutter pub get
flutter run
```

The app points to `http://10.0.2.2:4000/api` by default (Android emulator loopback to host). Override at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
```

> Note: models are hand-written (no Freezed codegen) so the project builds immediately with `flutter pub get` alone. If you'd like to migrate `Surah`/`Ayah`/`Bookmark` to Freezed later, add `freezed`/`freezed_annotation` and run `dart run build_runner build`.

## Backend Setup

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run adhan:import   # downloads and processes the muezzins' adhans into public/adhan/ (needs ffmpeg)
npm run prisma:seed    # the muezzins, from prisma/data/muezzins.json
npm run dev
```

## Client Admin Panel Setup

```bash
cd client
npm install
npm run dev
```

Only accounts with the `ADMIN` role can sign in to the panel or use its API routes (reciter uploads, user management). Register an account, then promote it:

```bash
cd backend
npm run make-admin -- you@example.com
```

## Database Setup

```bash
docker compose up -d postgres
```

This starts PostgreSQL on `localhost:5432` with the credentials in `docker-compose.yml` (also reflected in `backend/.env.example`).

## Environment Variables

See `backend/.env.example`:

```env
PORT=4000
NODE_ENV=development
DATABASE_URL="postgresql://lahuma:lahuma@localhost:5432/lahuma?schema=public"
JWT_SECRET="change-me-in-production"
JWT_EXPIRES_IN="7d"
CORS_ORIGIN="*"
MEDIA_BASE_URL=""   # origin of the adhan files; empty = this backend, as the app reached it
```

Leave `MEDIA_BASE_URL` empty in development; in production set it to the public HTTPS origin (see [docs/adhan.md](docs/adhan.md#hosting-the-files)).

## Running the Application

```bash
# Full backend stack
docker compose up -d

# Or run backend locally against Dockerized Postgres
docker compose up -d postgres
cd backend && npm run dev

# Mobile
cd mobile && flutter run
```

Stop everything:

```bash
docker compose down
```

## Running Tests

```bash
# Backend
cd backend && npm test

# Mobile
cd mobile && flutter test
```

## API Endpoints

| Method | Path                | Auth required | Description             |
|--------|---------------------|----------------|--------------------------|
| POST   | `/api/auth/register`| No             | Create an account        |
| POST   | `/api/auth/login`   | No             | Log in, receive JWT      |
| GET    | `/api/auth/me`      | Yes            | Get current user         |
| GET    | `/api/quran/surahs` | No             | List all Surahs (proxy)  |
| GET    | `/api/quran/surahs/:number` | No     | Get one Surah's Ayahs    |
| GET    | `/api/muezzins`     | No             | Active muezzins, in order, with absolute audio URLs |
| GET    | `/adhan/<slug>/v<n>/<file>` | No     | Muezzin audio (mp3 / caf), cached as immutable, Range supported |
| GET    | `/health`            | No             | Health check              |

The mobile app currently talks to the Quran data provider (`api.alquran.cloud`) directly from `QuranRemoteDataSource`; the backend's `/api/quran/*` proxy is available for when you want centralized caching or an offline bundle later — swapping it in only requires a new `QuranRepository` implementation.

## Known Limitations

- First read of each surah needs a connection (api.alquran.cloud); after that it is cached. No bundled offline dataset yet.
- Per-ayah audio streams from cdn.islamic.network (Alafasy) and needs a connection.
- Signing in does not sync anything yet: bookmarks, progress, wird and notes are device-local. The auth token is kept in SharedPreferences, not secure storage.
- Reading credit is counted when you scroll past an ayah (capped per scroll event); it is an honest approximation, not a guarantee of reading.
- Daily reading / adhkar reminders are not implemented yet (F1). The local-notification layer they need exists and is used by Fajr Call. There are no push notifications.
- Fajr Call: automatic calling is Android-only (iOS doesn't allow it). The Play build can't tell whether a call was answered, so the log relies on the user's "awake" tick (see [docs/fajr-call.md](docs/fajr-call.md#answer-detection)). Hanging up uses a deprecated Android API that may be refused on some devices. Calls use the user's own credit. Some OEM battery savers need the autostart / unrestricted settings.
- Memorization (hifz) review is not implemented.
- Rate limiting is applied to auth routes only.

## Fajr Call (نداء الفجر)

At Fajr, Lahuma calls the people you chose (your parents first) one by one to wake them for prayer.

- **Android, auto mode:** a foreground service places the calls with the app killed and the screen off, hangs up after the ring time, retries the people not reached, and shows a Stop button. Results appear in the log.
- **iOS, and Android manual mode:** a time-sensitive notification opens a wake list. Each person has a call button and an "استيقظ ✓" tick.
- **Fajr time** is calculated offline (`adhan`; Algeria's 18°/17° by default, otherwise the method of the location's country) from the location set in Settings (one coarse GPS fix or a city list). A list can also use a fixed time, an offset, or chosen weekdays.
- **Privacy:** lists, numbers, results and location stay on the device. Contacts come from the system picker, so no contacts permission is needed.
- **Permissions** are asked one by one with an explanation. Without them the feature degrades to manual mode.
- **Answer detection:** the Play build can't detect answers; a build made with `--android-project-arg=fajrCallLog=true` reads the call log to tell answered calls apart.

Design, Play-policy notes, iOS signing steps and a two-phone test script: [docs/fajr-call.md](docs/fajr-call.md).

```bash
# Kotlin unit tests (call loop)
cd mobile/android && ./gradlew :app:testDebugUnitTest
```

## Adhan (الأذان)

At each prayer time the app plays the full adhan of the muezzin the user picked, under **Settings → الصلاة → الأذان**.

- **Muezzins:** five real recordings from [Kiwifu/adhan-mp3](https://github.com/Kiwifu/adhan-mp3), pinned to a commit and listed in `backend/prisma/data/muezzins.json`: Algeria, Mishary Rashid Alafasy, Al-Haram al-Makki, Al-Masjid an-Nabawi, Abdulbasit Abdusamad. Each has a regular and a Fajr adhan. The bundled default is the Algeria recording.
- **Pipeline:** `npm run adhan:import` downloads them once, trims the silence, normalises the loudness (−16 LUFS), and writes a mono 96 kbps mp3 plus a 29.5 s IMA4 `.caf` for iOS per adhan into `backend/public/adhan/<slug>/v<version>/` (gitignored, about 29 MB). It is idempotent and bumps a muezzin's version when its audio changes, so the app downloads it again.
- **Serving:** the backend serves `/adhan/…` itself; a bucket works too (`rclone sync`). The app downloads the files once and works offline.
- **Release builds** are HTTPS only on Android (cleartext is allowed in debug and profile builds only).

Pipeline, hosting, how to add a muezzin, the test checklist and the credits for every recording: [docs/adhan.md](docs/adhan.md).

## Future Roadmap

### Phase 2
- Quran audio & multiple reciters
- Tafsir
- Ayah sharing
- Daily Quran reminders / daily ورد
- Advanced search

### Phase 3
- Account-based sync (bookmarks, reading progress → `Bookmark`, `ReadingProgress`, `UserSettings` Prisma models)
- Cloud bookmarks
- Reading statistics
- Khatmah tracking
- Push notifications

### Phase 4
- Adhkar & Duas (including Duas for parents)
- Sadaqah features
- Community initiatives

## Next Recommended Steps

1. Sync bookmarks, progress, wird and notes to the account. Add `Bookmark`/`ReadingProgress`/`UserSettings` Prisma models once sync is prioritized.
2. Bundle an offline Quran dataset for full offline reading.
3. Add integration tests for the auth flow and E2E tests for Quran reading + bookmarking.
