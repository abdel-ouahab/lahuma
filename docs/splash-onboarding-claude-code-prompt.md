# Prompt for Claude Code: Animated Splash + Onboarding for Ihsan (إحسان)

> Paste everything below the line into Claude Code, opened at the root of the repo.

---

You are working in **Ihsan (إحسان)**, formerly Lahuma. It's a Quran app built as ongoing charity (sadaqah jariyah) for the user's parents. The Flutter app is in `mobile/`. This task is **mobile only**: don't touch `backend/` or `client/`.

Your job is to build two things to a professional, App Store–feature standard:

1. **An animated splash screen**: the logo reveal plus a loading state tied to real app start-up.
2. **Onboarding screens**, shown once, that introduce the main features: prayer times, listening to reciters, the Mushaf, Quran khatma, qibla, Fajr Call, tasbih and adhkar.

Work in phases (§6). **Don't write code until you have read §1, run the skills in §1, and sent me the plan from Phase 0.**

## 1. Read first and load these skills

Load **`/frontend-design`** and **`/apple-design-flutter`** (both in `.claude/skills/`) before you design anything. Follow them. They are the design brief for this task. Then read:

- `docs/apple-redesign/AUDIT.md` and `docs/apple-redesign/PROGRESS.md`: the design language already in use.
- `mobile/lib/core/design/`: `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_motion.dart`, `design.dart`, and `widgets/`. **These are the only design tokens you may use.** `app_colors.dart` is the only file allowed to contain hex values. If you need a new colour (for example a splash night gradient stop), add it there as a semantic token with light and dark values.
- `mobile/lib/features/splash/splash_screen.dart`: the current splash. **Keep its start-up behaviour exactly**: `localNotificationsProvider.takeLaunchRoute()` (a tapped Fajr Call or adhan notification opens on top of Home), `showAdhanClearedNoticeIfNeeded`, and the Reduce Motion handling.
- `mobile/lib/core/router/app_router.dart`: routes use `CupertinoPage`, and the splash is at `/` outside the shell.
- `mobile/lib/core/localization/` (`tr.dart` + `arb`): every string goes here in Arabic and English. No hard-coded UI strings.
- `mobile/lib/features/settings/data/settings_repository.dart`: where the "onboarding seen" flag goes.
- The feature screens you'll be showing in miniature, so the onboarding visuals look like the real app: `prayer_times/`, `mp3quran/`, `quran/` (Mushaf), `khatma/`, `qibla/` (`compass_dial.dart`), `fajr_call/`, `tasbih/` (`beads_painter.dart`) and `adhkar/`.
- `mobile/pubspec.yaml`: `flutter_animate` is already available. Prefer it, plus `CustomPainter` and implicit or explicit animations.

## 2. Design direction (non-negotiable)

- **Identity:** mosque green `accent`, gold used only for gilding (frames, rings, ornaments, never text on light surfaces), warm ivory in light mode, green-black "the same scene at night" in dark mode. Arabic-first and RTL. **Cairo** for UI text, **Scheherazade New** for Quranic and ornamental lines.
- **Feeling:** calm, reverent and premium, like a well-made iOS app, not a flashy game. Motion should breathe. Spring physics come from `AppMotion.spring`. Nothing bounces more than once.
- **Islamic geometry, drawn not downloaded:** an 8-point star (Rub el Hizb) or a girih-style line pattern drawn with `CustomPainter`, at low opacity, as a texture and as the frame of the logo reveal. No stock illustrations, no clip-art mosques, no emojis, no Lottie files from the internet, no generic purple or blue "AI" gradients.
- **Illustrations are living miniatures of the real features**, built from Flutter widgets and painters with the app's own tokens. They are not screenshots or images.
- **Both themes and both directions** must look intentional: light and dark, Arabic RTL and English LTR.
- **Accessibility:** respect `MediaQuery.disableAnimationsOf` everywhere (use `AppMotion.of`). Text scales up to at least 200% without clipping; the logo artwork may stay fixed. Every page has a semantic label. Contrast meets WCAG AA. Buttons are at least 44×44.

## 3. Splash screen

### 3.1 Native splash (no white flash)
Add `flutter_native_splash` (dev dependency + config in `pubspec.yaml`). Use the same background as the first frame of the Flutter splash and a centred logo, including Android 12+ (`android_12:` block) and dark mode. The native splash should blend into the Flutter splash with no visible jump: same colour, same logo position and size.

### 3.2 Animated Flutter splash: one choreographed timeline (~1.6–2.0 s)
Use a single `AnimationController` with `Interval`s (or `flutter_animate` sequences), so it reads as one continuous gesture:

1. **0–500 ms**: a thin gold 8-point star outline **draws itself** around the logo position (stroke path animation with `PathMetric`). The geometric background pattern fades in to about 6% opacity.
2. **300–900 ms**: the logo scales from 0.86 to 1.0 with `AppMotion.spring` and fades in, then settles into the star.
3. **800–1200 ms**: a soft gold **light sweep** (a shimmer gradient masked to the logo) passes across it once.
4. **900–1400 ms**: the name **إحسان** (Scheherazade New, large) and the tagline *قرآنٌ يُتلى، وأجرٌ يُهدى* rise 12 px and fade in, staggered by 120 ms.
5. **Loading indicator**: below the tagline, a slim, elegant indicator, for example a gold arc or three slow-breathing dots in the geometry style. **It reflects real start-up work, not a fake timer.**

### 3.3 Real start-up work
Move start-up work into a `bootstrapProvider` (`FutureProvider`) in `features/splash/` that awaits what the app needs before Home: settings, locale and theme; the onboarding flag; cached prayer times; the notification launch route. Navigate when **both** the bootstrap is done **and** a minimum display time has passed (~1.6 s, so the animation finishes). Add a **maximum** (~5 s) after which the app proceeds anyway. Don't block on the network. If bootstrap fails, log the error and continue.

### 3.4 Exit
Fade or scale the content out (about 250 ms), then go:
- **First launch** → `/onboarding`
- **Otherwise** → `/home`, plus the existing launch-route push and adhan notice
- **Launched from a notification** (Fajr wake list, adhan) → **always skip onboarding**, even on first launch. The person needs that screen now.

With Reduce Motion on, show the final frame at once and navigate as soon as the bootstrap finishes.

## 4. Onboarding

### 4.1 Structure
A new feature folder, `mobile/lib/features/onboarding/` (`data/`, `presentation/screens/`, `presentation/widgets/`), with route `/onboarding` outside the shell. It is shown **once** (flag `onboarding_completed_v1` in `SettingsRepository`). Add **Settings → "Show the introduction again"**.

Eight features are too many for eight separate pages, so group them into **6 pages** plus a short final step:

| # | Page | Features | Living illustration (built in Flutter) |
|---|------|----------|-----------------------------------------|
| 1 | Welcome / the intention | Dedication to parents | The logo inside the gold star. A counter ticks "آية تُهدى لوالديك" upward; soft light rays |
| 2 | Read and listen | **Mushaf** + **listening to reciters** | A mini Mushaf page (real ayah text in the Quran font, framed in gold) with a small now-playing bar whose waveform moves |
| 3 | Your khatma | **Quran khatma** + daily wird | A progress ring filling to a juz' count, a small calendar strip with today highlighted, and a streak flame |
| 4 | Pray on time | **Prayer times** + **qibla** (+ adhan) | A prayer-times card with the next prayer highlighted and a countdown, next to the real `compass_dial` style whose needle swings and settles on the qibla |
| 5 | Fajr Call | **Fajr Call** | A night-to-dawn sky, a phone icon ringing outward, and contacts ("أمي", "أبي") ticking to "استيقظ ✓" one by one |
| 6 | Remembrance | **Tasbih** + **adhkar** | The real `beads_painter` beads sliding one at a time with a counter going 31 → 33, plus a morning/evening adhkar card |
| ✓ | Get started | — | A short closing line and a **"ابدأ"** button. Optionally the language and theme toggles. **No permission prompts here.** Location, notifications and phone permissions stay in their features |

### 4.2 Each page
- Top: **Skip / تخطي** (hidden on the last page). Middle: illustration (about 55% of the height). Then title (Cairo, bold, about 26) and a 1–2 line body (Cairo, about 16, secondary label colour).
- Bottom: a **custom page indicator** (the active dot stretches into a gold-rimmed pill) and a primary button, **التالي** / **ابدأ**, from the app's own button widgets.
- **Motion:** parallax between pages (illustration moves at about 0.6× page speed, text at 1×). Each illustration **plays its animation when its page becomes active** and pauses offscreen. Wrap each in `RepaintBoundary`. The background tint shifts subtly from page to page (dawn tones on the Fajr page).
- **RTL:** in Arabic the first page is on the right and swiping left moves forward. Check this explicitly. The arrows in the Next button follow `Directionality`.
- Light haptic (`HapticFeedback.selectionClick`) on page change; medium on "ابدأ".
- On iOS, mention on the Fajr Call page that automatic calling is Android-only. Write a short, honest sub-line for iOS ("تذكير بقائمة اتصال بنقرة واحدة").

### 4.3 Draft copy
Send this copy to me for review and polish it. Keep it short.

| # | Arabic title | Arabic body | English title | English body |
|---|---|---|---|---|
| 1 | إحسان | اجعل تلاوتك صدقةً جاريةً لوالديك؛ كلُّ آيةٍ تقرؤها تُهدى لهما. | Ihsan | Make your recitation a lasting charity for your parents. Every ayah you read is a gift to them. |
| 2 | اقرأ واستمع | مصحفٌ واضح مع التفسير والترجمة، وتلاوات كبار القرّاء. | Read and listen | A clear Mushaf with tafsir and translation, and recitations from great reciters. |
| 3 | ختمتك في موعدها | خطّة ختمة تناسب وقتك، وورد يومي يذكّرك بلطف. | Finish your khatma | A khatma plan that fits your time, with a daily wird and gentle reminders. |
| 4 | صلاتك في وقتها | مواقيت دقيقة حسب موقعك، أذانٌ في وقته، وقبلةٌ أينما كنت. | Pray on time | Accurate prayer times for where you are, the adhan on time, and the qibla wherever you go. |
| 5 | نداء الفجر | عند الفجر نتصل بمن تحب واحدًا تلو الآخر؛ لعلّ اتصالك يكون سببًا في صلاة. | Fajr Call | At Fajr we call your loved ones one by one. Your call might be the reason for a prayer. |
| 6 | ذكرٌ لا ينقطع | أذكار الصباح والمساء، وسبحةٌ تحفظ عدّك. | Keep remembering | Morning and evening adhkar, and a tasbih that keeps your count. |
| ✓ | بسم الله، لنبدأ | — | Let's begin | — |

## 5. Engineering standards

- Riverpod for state (`onboardingControllerProvider`, `bootstrapProvider`); GoRouter for navigation. Put the first-launch decision in the splash. Don't add a global redirect that would fight notification deep links.
- `const` constructors, no rebuilds of the whole `PageView` per frame (use `AnimatedBuilder` scoped to the page controller), dispose every controller. Keep it at 60 fps on a mid-range Android phone; check with the performance overlay in profile mode.
- No new heavy dependencies besides `flutter_native_splash`. Ask me before adding anything else.
- `flutter analyze` must stay clean.
- **Tests** (`mobile/test/`): first launch → onboarding; second launch → home; launch from a notification skips onboarding; Skip and Start both set the flag; RTL page order; Reduce Motion skips the animations; bootstrap timeout still navigates.

## 6. Phases

- **Phase 0 (plan):** after reading §1 and loading the skills, send me (a) your design concept in a few sentences, (b) a frame-by-frame splash timeline, (c) a sketch of each onboarding page (ASCII is fine), and (d) the final copy. **Wait for my OK.**
- **Phase 1:** native splash, then the animated splash with `bootstrapProvider` and routing.
- **Phase 2:** the onboarding shell (PageView, indicator, buttons, flag, route, Settings entry), with placeholder illustrations.
- **Phase 3:** the six living illustrations, one at a time.
- **Phase 4:** polish (haptics, parallax, dark mode, English LTR, large text, Reduce Motion), then tests.
- **Phase 5:** run `flutter analyze` and `flutter test`. Take screenshots of every screen in light and dark, Arabic and English, using golden tests or an emulator. Update `docs/apple-redesign/PROGRESS.md` and the README's features list. Then give me a short summary of what changed and anything you'd still improve.

Commit after each phase with a clear message on a branch named `feature/splash-onboarding`.
