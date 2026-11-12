package com.lahuma.app.adhan

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * An adhan alarm fired: start the player in the foreground. Allowed on
 * Android 12–14 because the broadcast comes from an exact alarm
 * (`setAlarmClock`), one of the foreground-service start exemptions.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AdhanAlarms.ACTION_FIRE) return
        val slot = AdhanAlarmSlot.fromIntent(intent) ?: return
        AdhanAlarms.forgetTest(context, slot.id)
        // On time even where the banner's own tick is held back.
        PrayerBanner.refresh(context)
        val late = System.currentTimeMillis() - slot.at
        if (late > AdhanAlarms.MAX_NOTIFY_LATE_MS) {
            // The phone was off: by now the prayer's time is long past.
            Log.i(TAG, "Skipping ${slot.prayer} adhan, ${late / 60000} min late")
            return
        }
        if (late > AdhanAlarms.MAX_LATE_MS) {
            // An inexact alarm (no "Alarms & reminders" permission) or a
            // battery saver held it back. Too late to sound the adhan, but
            // the prayer's notification still comes.
            Log.i(TAG, "${slot.prayer} adhan ${late / 60000} min late: notification only")
            AdhanNotify.fallback(context, slot)
            return
        }
        try {
            AdhanPlaybackService.start(context, slot)
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException (inexact alarm, no
            // "Alarms & reminders" permission) or an OEM refusing it: a
            // notification that opens the in-app player instead.
            Log.w(TAG, "Could not start the adhan player: $e")
            AdhanNotify.fallback(context, slot)
        }
    }

    private companion object {
        const val TAG = "Adhan"
    }
}

/**
 * Re-arms the adhans after a reboot, an app update, a clock or timezone
 * change, or when the exact-alarm permission is granted, with no UI. The
 * stored times are re-armed at once; then [AdhanWork] runs the Dart
 * reschedule headlessly (a timezone change moves every prayer time, and
 * the week ahead needs topping up).
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                AdhanAlarms.rescheduleAll(context)
                PrayerBanner.refresh(context)
                AdhanWork.runNow(context)
                AdhanWork.ensureDaily(context)
            }
        }
    }
}
