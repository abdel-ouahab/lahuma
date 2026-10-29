# Fajr Call (نداء الفجر)

At Fajr, Lahuma calls the people you chose (your parents first) one by one to wake them for prayer, and then shows you who was called and who is awake.

> *أيقظ والديك للفجر… لعلّ اتصالك يكون سببًا في صلاة.*

Everything runs on the device. Lists, numbers, results and your location never leave the phone, and the backend is not involved. The feature works without an account.

## How it works

| | Android, auto mode | Manual mode (iOS, or Android by choice) |
|---|---|---|
| At the scheduled time | A foreground service calls each person in order, even with the app killed and the screen off. | A time-sensitive notification opens the **wake list**. |
| Calling | `TelecomManager.placeCall` from your SIM (or the one you picked). The app hangs up after the ring time. | One tap per person opens the dialler (`tel:`). |
| "Who answered" | See [Answer detection](#answer-detection). | You tick "استيقظ ✓" for each person. |
| Results | Written natively, merged into the log the next time the app opens or comes to the foreground. | Saved as you tap. |
| Stop | "إيقاف" on the ongoing notification. | Close the list. |

An auto list falls back to manual mode by itself when the device can't place calls (no telephony), when the call permissions are denied, or when Android refuses to start the service (for example, no "Alarms & reminders" permission). Nothing breaks: you still get the notification and the wake list.

### Schedule

- **Start time:** at Fajr ± an offset (−30 to +60 minutes, in steps of 5), or a fixed clock time. Optionally on chosen weekdays only, or once (the list switches itself off after it runs).
- **Fajr time** is calculated offline with [`adhan`](https://pub.dev/packages/adhan). The default method is Algeria's Ministry of Religious Affairs (Fajr 18°, Isha 17°). The method follows the location's country (Morocco 19°/17°, Tunisia 18°/18°, Umm al-Qura, Egypt…); there is no method setting. The location is the app's own, set in **Settings → Location** (المزيد ← الصلاة ← الموقع) from one coarse GPS fix or from a bundled list of the 58 wilayas plus major cities. Fajr Call has no location screen of its own: when a Fajr list needs one and none is set, it opens that same sheet.
- **Accuracy:** tests compare Algiers and Paris (including a daylight-saving change) against api.aladhan.com and require a match within 1 minute.
- Flutter computes the next **14 fire times** and sends them to Android with the config. Kotlin never calculates prayer times. If the app isn't opened for two weeks, Android repeats the last time every 24 hours (so it drifts by about a minute a day) until the app is opened and resyncs. Every launch and every resume resyncs.
- Manual mode schedules up to 14 notifications per list. On iOS, which allows 64 pending notifications per app, Fajr Call shares 19 of them across all lists; the [adhan](adhan.md) takes the other 45. Android has no such cap (60 per Fajr Call).

### The call loop (auto mode)

For each person in list order: dial → after `ringTimeoutSec` (10–180 s, default 20) the app hangs up → wait. Turning off **End the call automatically** (`autoHangUp`) skips the hang-up: the call runs until the other side or the network ends it, and without the call log it is logged as "called". The wait is `waitAfterAnswerSec` (default 30 s) after a call the other side ended or answered, and `gapBetweenSec` (default 3 s) otherwise.

- **Stop after the first answer** ends the loop as soon as someone is reached.
- **Retry when there's no answer** calls the people not reached again, up to `maxRetries` extra passes.
- **Repeat the whole list** adds `loopRepeats` more rounds for whoever is still not reached. Retries are not granted again in these rounds, to keep 4 a.m. calls to a minimum.
- A loop never runs longer than 30 minutes.

The loop is a pure Kotlin state machine (`CallLoop.kt`), tested with a fake dialler and a fake clock (`CallLoopTest.kt`).

### Answer detection

Android doesn't tell third-party apps when an *outgoing* call is answered. `READ_PHONE_STATE` reports OFFHOOK as soon as dialling starts.

- **Play build (default):**
  - A call that rang for the whole ring time and was hung up by the app is logged as **"لم يردّ" (no answer)**.
  - A call that ended earlier is logged as **"انتهت المكالمة" (call ended)**. It ended because the person answered or declined, or because the network ended it. "Stop after the first answer" and retries treat it as "reached".
  - The user's "استيقظ ✓" tick, on the log or the wake list, is the real signal.
- **Call-log build (`-PfajrCallLog=true`):** after each call the app reads the call log, and a duration above 0 means **"ردّ" (answered)**. Use it for sideloaded builds, or for a Play build if Google ever approves the declaration.

```bash
flutter build apk --release --android-project-arg=fajrCallLog=true
```

Without the flag, the manifest names an unused app-private permission (`com.lahuma.app.permission.FAJR_CALL_LOG_DISABLED`) in place of `READ_CALL_LOG`, so Play never sees the restricted permission.

### Hanging up

`TelecomManager.endCall()` (API 28+, `ANSWER_PHONE_CALLS`) is deprecated since API 29, and there's no replacement for apps that aren't the default dialler. The engine still uses it. When it is refused (the permission is denied, the API is older than 28, or an OEM blocks it), the loop waits up to 45 s for the network to end the call and then moves on. Test this on each new device or Android version.

Known gaps:
- If a refused hang-up only ends after that 45 s grace period, the late IDLE event can be misread as the next person's call ending.
- Because answers can't be seen live, the app hangs up at the ring time even if the person picked up a second earlier. Their phone has rung, so the wake-up worked. In the Play build that call is logged as "لم يردّ" if they were still on the line when the app hung up. The tick fixes the record.

## Architecture

```
mobile/lib/features/fajr_call/
  domain/        FajrCallList, FajrContact, CallAttempt, CallSession, PrayerSettings
  data/          FajrCallRepository     SharedPreferences JSON (sessions capped at 30)
                 PrayerTimesService     adhan wrapper, reusable for a prayer-times screen
                 FajrSchedule           next fire times in the device timezone (DST-safe)
                 FajrNotifications      manual-mode notifications
                 FajrCallPlatform       MethodChannel `lahuma/fajr_call`
                 LocationService, ContactPicker, places.dart (58 wilayas + cities)
  presentation/  FajrCallNotifier (+ providers), screens/, widgets/
mobile/lib/core/notifications/   LocalNotifications: shared with the F1 reminders
mobile/android/app/src/main/kotlin/com/lahuma/app/fajrcall/
  CallLoop.kt          pure state machine
  FajrCallService.kt   foreground service (specialUse), Telecom, call state, call log
  FajrAlarms.kt        one setAlarmClock per list; inexact fallback without exact-alarm access
  FajrReceivers.kt     alarm receiver; boot / update / time / timezone receiver
  FajrStore.kt         native config + sessions waiting for Flutter
  FajrNotify.kt        ongoing, results and fallback notifications
  FajrCallChannel.kt   MethodChannel handler
```

Routes: `/home/fajr-call`, `/home/fajr-call/new`, `/home/fajr-call/permissions`, `/home/fajr-call/:id`, `/home/fajr-call/:id/log` (Home branch) and `/fajr-call/wake/:id?at=<epoch ms>` (full screen, outside the shell).

## Permissions

Each permission is asked on the checklist screen, after an explanation. All are optional: without them the feature runs in manual mode.

| Permission | Why | Notes |
|---|---|---|
| `POST_NOTIFICATIONS` | Fajr reminder; ongoing "calling…" notification with Stop | Android 13+ runtime; iOS prompt |
| `SCHEDULE_EXACT_ALARM` | Start on the minute; lets the alarm start the service | Denied by default for new installs on Android 14+; the user turns on "Alarms & reminders" |
| `CALL_PHONE`, `READ_PHONE_STATE` | Place the calls and follow them | Runtime |
| `ANSWER_PHONE_CALLS` | Hang up after the ring time | Runtime, optional |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `WAKE_LOCK` | Run the loop with the screen off | Normal |
| `RECEIVE_BOOT_COMPLETED` | Re-arm alarms after a reboot | Normal |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Survive Doze and OEM battery killers | See Play notes |
| `ACCESS_COARSE_LOCATION` | One city-level fix for prayer times | Optional; a city list works without it |
| `READ_CALL_LOG` | Answered or not | Only with `-PfajrCallLog=true` |

There's no contacts permission. The system picker (`ACTION_PICK`, `CNContactPickerViewController`) returns only the number the user picks.

## Google Play notes

- **Foreground service type `specialUse`.** The `phoneCall` type needs `MANAGE_OWN_CALLS` (meant for self-managed VoIP apps) or the default-dialler role, neither of which fits. Declare `specialUse` in Play Console → *App content → Foreground service permissions*. Describe it as "At a user-scheduled time (Fajr), places sequential calls to contacts the user chose, to wake them, with a visible notification and Stop action", and attach a short video of a list running. The same text is in the manifest `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`.
- **Exact alarms.** Use `SCHEDULE_EXACT_ALARM`, not `USE_EXACT_ALARM` (which is limited to alarm-clock and calendar apps). The app works without it, just later and in manual mode.
- **`READ_CALL_LOG`** is in the restricted Call Log group. None of the listed exceptions clearly covers this use ("Device automation" is the closest), so the Play build leaves it out.
- **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** must be justified as core functionality (time-critical calls in Doze). If a review objects, remove the permission. `FajrCallChannel` already falls back to opening the battery-optimisation settings list, which needs no permission.
- **`CALL_PHONE`** is declared with `android.hardware.telephony` marked not required, so tablets are not filtered out. They simply don't get auto mode.
- **Data safety:** contacts and location are processed on the device only. Nothing is collected or shared.

## iOS (needs a Mac to build and sign)

iOS doesn't allow apps to place calls automatically, so iOS always uses manual mode.

- `Info.plist` already has `NSLocationWhenInUseUsageDescription` (localised in `ar.lproj` / `en.lproj`) and `LSApplicationQueriesSchemes: tel`.
- `AppDelegate.swift` sets `UNUserNotificationCenter.current().delegate`, so Fajr notifications show in the foreground and their taps reach Flutter.
- **Time Sensitive notifications:** in Xcode, open *Runner → Signing & Capabilities → + Capability → Time Sensitive Notifications*. This adds `com.apple.developer.usernotifications.time-sensitive` to `Runner.entitlements`. Without it, iOS delivers the Fajr notification as a normal one, which a Focus mode can silence.
- Contact picking uses `CNContactPickerViewController` through `flutter_native_contact_picker`, so no contacts usage string is needed.

## Manual test script (two phones)

Phone **A** runs Lahuma; phone **B** is the person being woken.

1. On A, open *Home → نداء الفجر → جهّز أول قائمة*. Add B from contacts, choose *وقت محدد* two minutes from now, keep *اتصال تلقائي*, then save.
2. On the permissions screen, allow notifications, calls, alarms & reminders and battery. All four should show ✓.
3. Kill the app (swipe it away from recents) and turn A's screen off.
4. At the time: A shows the ongoing "جارٍ الاتصال بـ …" notification and B rings for about 20 s. A hangs up; with retry on, B rings once more after the gap.
5. Answer on B during the retry and hang up after a few seconds. The loop moves on, and the result notification appears.
6. Open the results notification. The log should show the session: the first call "لم يردّ" and the second "انتهت المكالمة" (or "ردّ" in a call-log build). Tick B as awake and check the "استيقظوا" total changes.
7. Run again and tap **إيقاف** while it rings. The call ends, the loop stops, and the log shows "أُوقف".
8. Set a time three minutes ahead and reboot A. The list should still fire.
9. Revoke the call permissions in system settings and wait for the next time. A shows a notification that opens the wake list (manual fallback).
10. On iOS, or with *تنبيه وقائمة* on Android, wait for the notification. Tapping it opens the wake list; *اتصال* opens the dialler and ticks are kept in the log.

Also check: Arabic and English, light and dark, the largest text size, TalkBack/VoiceOver labels on the call and tick buttons, and Reduce Motion (the lantern stays still).

## Future ideas (out of scope here)

- Companion wake-ups through the other person's Lahuma app (push-based), so nobody's credit is used.
- Syncing lists to the account (README Phase 3).
- A prayer-times screen built on `PrayerTimesService`.

## Copy (for review)

| Where | Arabic | English |
|---|---|---|
| Feature name | نداء الفجر | Fajr Call |
| Empty state title | أيقظ والديك للفجر | Wake your parents for Fajr |
| Empty state text | اختر من تحب، وعند الفجر يتصل بهم التطبيق واحدًا تلو الآخر. لعلّ اتصالك يكون سببًا في صلاة. | Choose the people you love. At Fajr the app calls them one by one. Your call may be the reason they pray. |
| Empty state button | جهّز أول قائمة | Set up your first list |
| Lists subtitle | لعلّ اتصالًا منك يكون سببًا في صلاة. | A call from you may be the reason someone prays. |
| First list name | والداي | My parents |
| Consent note | تأكّد أنهم يوافقون على أن تتصل بهم عند الفجر. تبقى الأسماء والأرقام على جهازك ولا تُرفع إلى أي مكان. | Make sure they agree to be called at Fajr. Names and numbers stay on your phone and are never uploaded. |
| Cost note | يتصل الهاتف بهم واحدًا تلو الآخر من شريحتك، وقد يكلّف ذلك رصيدًا. | Your phone calls them one by one from your SIM, which may cost credit. |
| Notification | نداء الفجر · والداي — حان وقت الفجر. اضغط لتتصل بـ أمي، أبي | Fajr Call · My parents — It's time for Fajr. Tap to call … |
| Ongoing | جارٍ الاتصال بـ أمي… · إيقاف | Calling Mum… · Stop |
| Wake list | حان وقت الفجر · اتصل بكل واحد منهم، ثم علّم من استيقظ. | It's time for Fajr · Call each of them, then tick who is awake. |
| All awake | استيقظوا جميعًا. تقبّل الله منك ومنهم. | Everyone is awake. May Allah accept from you and them. |
| Home card | نداء الفجر القادم: غدًا 4:36 ص · شخصان | Next Fajr call: Tomorrow 4:36 AM · 2 people |
