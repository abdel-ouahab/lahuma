# Mega-prompt for Claude Code — "Fajr Call" (نداء الفجر) feature for Lahuma

> Paste everything below the line into Claude Code, opened at the root of the `lahuma/` repo.

---

You are working in **Lahuma (لهما)**, a Quran app built as a continuous charity (sadaqah jariyah) for parents. The repo has a Flutter app in `mobile/`, a Node/Express/Prisma backend in `backend/` and a React admin panel in `client/`. This task is **mobile only**: don't change `backend/` or `client/`.

Your job is to add a new feature: **Fajr Call (نداء الفجر)**. At Fajr time, the app phones the people you chose (parents, family, friends) one by one to wake them for prayer. Then it shows you who answered.

Work carefully and in phases, as described below. **Before writing any code, read the files listed in §1. Then ask me the questions in §2 and wait for my answers.**

## 0. Where the idea comes from (product brief)

A competitor's promo video (the Tamaneena app, feature "صحبة الفجر") shows this flow:

1. *"صحّيني معك للفجر… كم مرة سمعتها من شخص تحبه؟"* sets up the emotional hook. Someone you love asks you to wake them for Fajr.
2. The user makes it a habit. They set a call time, either a fixed time or the Fajr time automatically, and choose family or friends from their contacts.
3. At that time **the app calls them one by one**, with a lantern hopping from house to house across the city.
4. **Nobody answered?** The user can turn on **retry**.
5. Afterwards, the user **checks the log** to see who answered.
6. Closing message: *"يمكن اتصال منك يكون سببًا في صلاة"*, then two friends walk to the mosque at dawn.

The screens in the video show these settings:
- **List:** a list name, a start time (fixed time, or "use Fajr time" which shows today's Fajr time) and contacts (name and number).
- **Advanced:** ring timeout (20 s), wait after an answer (30 s), gap between numbers (3 s), stop after the first answer, retry when there's no answer, repeat the whole loop, and repeat daily. These are toggles and sliders.
- **Call log:** totals for calls made, answered, not answered and failed, plus a results list with timestamps.

**Lahuma's angle:** Lahuma is about honouring parents. Frame this feature as *waking your parents and loved ones for Fajr, which is itself a good deed*, not as a generic alarm. Pre-fill the first list as "والداي" ("My parents"). Use copy that fits Lahuma's voice. **Don't copy Tamaneena's name, texts, illustrations or icon.** Write original Arabic copy and offer it to me for review.

## 1. Read first (don't skip)

- `README.md`, `docs/mobile-missing-features.md` (especially **F1 Reminders**, **G Dedication** and **M3/M5**) and `docs/apple-redesign/PROGRESS.md` and `AUDIT.md`.
- `.claude/skills/apple-design-flutter/SKILL.md`. **All new UI must follow it** and the design system in `mobile/lib/core/design/` (`AppScaffold`, `AppListSection`/`AppListTile`, `AppSwitch`, `AppButton`, `AppCard`, `showAppDatePicker`/`showAppPicker`/`showAppSheet`, `AppEmptyState`, `AppToast`, the colour and spacing tokens). Don't use raw `Colors.*`, Material `Scaffold` or `ListTile`, or inline `GoogleFonts`.
- `mobile/pubspec.yaml`, `mobile/lib/main.dart`, `mobile/lib/core/router/app_router.dart`, `mobile/lib/core/shell/main_shell.dart` and `mobile/lib/core/constants/storage_keys.dart`.
- Feature patterns to imitate: `features/dedication/` (repository + `StateNotifier` + provider), `features/wird/` and `features/adhkar/` (data, domain and presentation folders, plus tests in `test/`).
- Strings: the app uses inline bilingual strings, `context.tr('عربي', 'English')`, from `core/localization/tr.dart`. Use the same pattern. Arabic RTL is the primary layout, and English LTR must also work.
- `mobile/android/app/src/main/AndroidManifest.xml` (currently only `INTERNET`), `android/app/build.gradle*`, `MainActivity` and `ios/Runner/Info.plist`.
- Current branch: `feature/apple-design`. **Create `feature/fajr-call` from it** before changing anything.

Facts about the current app that you must work around:
- There are **no prayer times** anywhere in the app yet, so you'll need to calculate Fajr.
- There are **no local notifications** yet. F1 in the missing-features doc plans `flutter_local_notifications` + `timezone`. Build the notification layer so F1 can reuse it later.
- The app is guest-first. Everything must work with no account and no backend.

## 2. Questions to ask me before coding

Use your question tool and give a recommendation for each:

1. **Feature name** in the UI: "نداء الفجر" (my working name), "أيقظهما للفجر" or something else?
2. **Platform scope.** iOS does not allow an app to place phone calls automatically or in the background. Confirm this plan:
   - **Android:** a true automatic call loop.
   - **iOS and Android "manual mode":** a time-sensitive notification at Fajr that opens a "wake-up list" screen with a one-tap call button per person and a tick when they're awake.
3. **Answer detection on Android.** Third-party apps can't directly tell whether an *outgoing* call was answered. The options are below. Research the current Google Play policy and tell me what you found:
   - (a) Read `CallLog` (`READ_CALL_LOG`) after each call and treat `duration > 0` as answered. This is accurate, but `READ_CALL_LOG` is a Play-restricted permission and needs a Permissions Declaration that may be rejected for this use case.
   - (b) Without the call log, use `READ_PHONE_STATE` to log "called" and "ended", and let the user mark "woke up ✓" on the results screen.
   - (c) Ship (b) to Play first and keep (a) behind a build flag.
4. **Fajr calculation method.** Which method should be the default (Algeria, for example, uses its ministry's angles), should location come from GPS once or from a manual city, and what offset in minutes should apply before or after Fajr?
5. **Contacts.** Use the system contact picker (no `READ_CONTACTS` permission) plus manual entry (my preference), or a full in-app contact list?

## 3. Architecture

### 3.1 Flutter side: `mobile/lib/features/fajr_call/`
```
fajr_call/
  domain/      fajr_call_list.dart, fajr_contact.dart, call_attempt.dart, call_session.dart
  data/        fajr_call_repository.dart        (persist lists + results)
               prayer_times_service.dart        (Fajr calc, wraps the `adhan` package)
               fajr_call_platform.dart          (MethodChannel to native Android)
               fajr_notifications.dart          (flutter_local_notifications wrapper, reusable for F1)
  presentation/
    fajr_call_providers.dart
    screens/   fajr_call_lists_screen.dart, fajr_call_edit_screen.dart,
               fajr_call_log_screen.dart, fajr_wake_list_screen.dart (manual / iOS mode),
               fajr_call_permissions_screen.dart
    widgets/   ...
```

**Models** are hand-written with `copyWith`, `toJson` and `fromJson`. Don't use Freezed, to match the README.
- `FajrCallList`: `id`, `name`, `enabled`, `startMode` (`fixed` | `fajr`), `fixedTime` (hh:mm), `fajrOffsetMinutes` (int, can be negative), `repeatDaily`, optional `weekdays`, `contacts: List<FajrContact>`, `ringTimeoutSec` (default 20, range 10–60), `waitAfterAnswerSec` (default 30), `gapBetweenSec` (default 3), `stopAfterFirstAnswer` (default false), `retryOnNoAnswer` (default true), `maxRetries` (default 1), `repeatWholeLoop` (default false), `loopRepeats` (default 1) and `mode` (`auto` | `manual`).
- `FajrContact`: `name`, `phone` (normalised E.164 where possible; keep the raw input too) and `relation` (an optional enum: father, mother, sibling, spouse, friend, other).
- `CallAttempt`: `contact`, `startedAt`, `endedAt`, `status` (`answered` | `noAnswer` | `failed` | `called` | `markedAwake`) and `attemptNo`.
- `CallSession`: `listId`, `firedAt` and `attempts`, plus computed totals (total, answered, no answer, failed).

**Storage:** keep lists and recent sessions (cap them, for example at the last 30 sessions) in Hive or SharedPreferences JSON. Add keys to `StorageKeys` (`fajrCall.lists`, `fajrCall.sessions`, `fajrCall.prayerSettings`).

**Prayer times:** use the `adhan` Dart package. It calculates offline with no network. Store the coordinates, the calculation method, the madhab (not needed for Fajr, but keep it for future prayers) and the offset. Show "Fajr today: 4:36 ص" in the editor exactly as the video does. Put the Fajr calculation in its own service so a future prayer-times feature can reuse it.

### 3.2 Android native side (the core of the feature)

The call loop must run **when the app is killed, the screen is off and the phone is dozing at 4 a.m.** So it can't depend on a live Flutter engine. Put it in Kotlin under `android/app/src/main/kotlin/.../fajrcall/`:

- **Config handoff:** every time the user saves a list, Flutter sends the full config JSON over a `MethodChannel` (`lahuma/fajr_call`). Kotlin stores it in its own SharedPreferences and schedules the alarm. Native code is the source of truth at fire time.
- **Scheduling:** use `AlarmManager.setAlarmClock(...)` (or `setExactAndAllowWhileIdle`) for the next fire time. Flutter calculates the time and passes it as epoch millis; Kotlin doesn't calculate prayer times. After each fire, Kotlin asks for the next day's time:
  - Preferred: precompute and send the next 7–14 Fajr times in the config.
  - Fallback: if precomputed times run out, use the last time plus 24 hours and flag that the schedule needs a refresh.
- **Rescheduling:** handle `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED` and `MY_PACKAGE_REPLACED`.
- **Execution:** a **foreground service** with a visible ongoing notification ("نداء الفجر: جارٍ الاتصال بـ أمي…" with a Stop action). It runs a state machine:
  - Call each contact in order, waiting `gapBetweenSec` between numbers.
  - Each call rings for up to `ringTimeoutSec`.
  - If a call is answered, wait `waitAfterAnswerSec`. Then either stop (if `stopAfterFirstAnswer`) or continue.
  - Retry contacts with no answer up to `maxRetries`.
  - If `repeatWholeLoop` is on, repeat the whole loop `loopRepeats` times.
  - Write a `CallSession` result to native storage. Flutter reads and merges it on the next launch or resume.
- **Placing calls:** use `TelecomManager.placeCall()` with `CALL_PHONE`. It works from a service without starting an activity, which avoids Android 10+ background-activity-start limits. Verify this on API 29 through the latest API level. **Handle dual SIM:** let the user choose a SIM (`PhoneAccountHandle`) in the list settings, or use the default.
- **Ending a call after `ringTimeoutSec`:** use `TelecomManager.endCall()`, which needs `ANSWER_PHONE_CALLS` and is deprecated on newer APIs. Check what still works and document any fallback.
- **Call state:** use `TelephonyCallback` (API 31+) or `PhoneStateListener` (older) with `READ_PHONE_STATE`. Add answer detection according to my answer to question 3.
- **Foreground service type:** research the correct `foregroundServiceType` for this on Android 14+ (for example `phoneCall` vs `specialUse` and what each requires) and the Play policy for it. Explain your choice to me before committing.
- **Battery:** many devices common in Algeria (Xiaomi/Redmi, Oppo, Samsung, Infinix/Tecno) kill background work. Add a guided "battery optimisation" step (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intent, plus OEM autostart hints in copy) and check `canScheduleExactAlarms()` on Android 12+, sending the user to settings if needed.
- **Permissions to declare and request in context** (only what's needed, each with an explanation screen before the system dialog): `POST_NOTIFICATIONS`, `CALL_PHONE`, `READ_PHONE_STATE`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `FOREGROUND_SERVICE` (+ its type permission), `WAKE_LOCK`, optionally `ANSWER_PHONE_CALLS` and optionally `READ_CALL_LOG` (per question 3).

### 3.3 iOS and manual mode
- A **time-sensitive local notification** at the scheduled time (repeating daily, rescheduled with new Fajr times like Android). Add the iOS notification usage text and the Time Sensitive capability note to `Info.plist` and the docs. I'll need a Mac for signing, so just document it.
- Tapping the notification deep-links to `/fajr-call/wake/:listId`. That screen lists each person with a big **call** button (`url_launcher` `tel:`) and an "استيقظ ✓" tick. Ticks are saved as `markedAwake` attempts, so the log works the same on both platforms.
- On Android, `mode: manual` uses the same flow for users who don't want auto-calling.

## 4. Screens and UX (Apple design, RTL first, light and dark)

1. **Entry points**
   - Home: a `FeatureCard` in the shortcuts grid, plus a small status card under "وردك اليوم" when a list is enabled. Example: "نداء الفجر القادم: غدًا 4:36 ص · 3 أشخاص".
   - Settings: a row under a new "الفجر" section.
   - Routes: add `/fajr-call`, `/fajr-call/:id` and `/fajr-call/:id/log` inside the Home branch, and `/fajr-call/wake/:id` outside the shell (full screen, like the adhkar reader). Use `CupertinoPage` like every other route.
2. **Lists screen:** large title. Show an inset-grouped list of call lists, each with its next fire time and an `AppSwitch`. When there are none, show `AppEmptyState` with the Lahuma message (for example "أيقظ والديك للفجر… لعلّ اتصالك يكون سببًا في صلاة") and a "جهّز أول قائمة" button.
3. **Edit screen:** grouped sections that mirror the video's structure.
   - List name.
   - Call time: a segmented control for "وقت الفجر" / "وقت محدد"; the Fajr time shown live with an offset stepper; a time picker for a fixed time.
   - Contacts: the system picker plus manual add, swipe to delete, reorder by drag, and a relation icon.
   - Advanced (collapsible): three sliders with live "20 ث" labels and toggles (stop after first answer, retry when no answer + count, repeat loop + count, daily repeat, weekdays, SIM, auto/manual).
   - A sticky "حفظ القائمة" filled button.
   - A **"جرّب الآن" (test now)** action that runs the list immediately, after a confirmation that it will really call these people.
4. **Log screen:** four stat tiles (الإجمالي / ردّوا / لم يردّوا / فشل) followed by sessions grouped by date, with each attempt's status icon and time. Include a clear-log action. Put times and numbers in LTR runs inside RTL, using the existing `ltr()` / `LtrText` helpers.
5. **Permissions screen:** a step-by-step checklist (notifications → calls → exact alarms → battery) with a live ✓ for each step, shown the first time a list is enabled and reachable later.
6. **Consent and cost notes** (short, in the editor):
   - Make sure the people on the list agreed to be called at Fajr.
   - Calls go through the user's own SIM and may cost credit.
   - The app never uploads contacts. Everything stays on the device. State this explicitly; it's true because the backend isn't involved.
7. **Accessibility:** 44-point targets, Dynamic Type up to 1.6× without overflow, VoiceOver/TalkBack labels, and Reduce Motion respected. An optional subtle lantern-hop animation on the empty state is fine. Keep it original and honour Reduce Motion.

## 5. Packages

Tell me before adding each one, per the skill rule, and pin versions compatible with Flutter ≥ 3.22 / Dart ≥ 3.3:
- `adhan` for Fajr calculation.
- `flutter_local_notifications` + `timezone` (+ `flutter_timezone` if needed) for notifications, shared with future F1.
- `geolocator` only if I choose GPS in question 4. Otherwise use a manual city or coordinates.
- `url_launcher` for `tel:` in manual mode.
- `permission_handler` only if it's simpler than native checks over the MethodChannel.
- Contact picking: prefer a native `ACTION_PICK` intent (Android) and `CNContactPickerViewController` (iOS) through the channel, or a small maintained plugin. Justify the choice.

## 6. Tests and verification

- **Dart unit tests:** model JSON round-trips, next-fire-time calculation (fixed vs Fajr+offset, weekdays, DST/timezone, past-time → tomorrow), the repository, and the session totals.
- **Kotlin unit tests (JUnit):** extract the call-loop state machine into a pure class with a fake dialer and fake clock. Cover ordering, timeout, retry, stop-after-first-answer, loop repeats and the stop action.
- **Widget tests:** lists, edit and log screens in Arabic RTL and English LTR, light and dark, and at 1.6× text, following `test/design_system_preview_test.dart`. Add a router test for the new routes.
- Run `flutter analyze` (no new warnings) and `flutter test`. Run `./gradlew test` for the Kotlin tests.
- **Manual test script in the docs:** using two phones, schedule a list 2 minutes ahead, kill the app, turn the screen off, and confirm the calls, the log, reboot rescheduling and the stop button.

## 7. Phases (stop and report after each one)

1. **Phase A: domain, storage and Fajr time.** Models, repository, prayer-times service and tests. No UI.
2. **Phase B: UI in manual mode, cross-platform.** All screens, routes, entry points, notifications and the wake-list screen. After this, the feature is usable on both platforms.
3. **Phase C: Android auto-call engine.** Kotlin service, alarms, boot receiver, MethodChannel, permissions flow and Kotlin tests.
4. **Phase D: polish and docs.** Copy review with me, accessibility pass, and doc updates:
   - Add a "Fajr Call" section and its limits to the README.
   - Add the feature to `docs/mobile-missing-features.md` (new section, ticked items) and link it from F1.
   - Add Play-policy notes.
   - Add a line to `docs/apple-redesign/PROGRESS.md` for the new screens.

Commit in small conventional commits (`feat(fajr-call): …`). Don't push and don't open a PR unless I ask.

## 8. Out of scope (don't do these)
- Backend or account sync of lists. Phase 3 of the README can add it later.
- Calling or notifying through another Lahuma user's app (push-based "companion" wake-ups). Note it as a future idea only.
- Copying any Tamaneena branding, text, illustrations or exact copy.
- Refactoring unrelated screens, or the pending N3 dead-code deletions.

## 9. Definition of done
- On Android, an enabled auto list fires at Fajr (± the offset) with the app killed and the screen off. It calls the contacts in order with the configured timeouts, retries and loops; shows a stoppable ongoing notification; and writes a session that appears in the log.
- On iOS and in manual mode, a notification fires at the right time and opens the wake list, where calls work and ticks are logged.
- The Fajr time shown in the editor matches a trusted reference (for example the local mosque timetable) within 1–2 minutes for the chosen method.
- Every permission is requested in context with an explanation. Denial is handled gracefully and the feature degrades to manual mode.
- The UI matches the Apple design system in RTL and LTR, light and dark.
- Analyze and tests are clean, and the docs are updated.
