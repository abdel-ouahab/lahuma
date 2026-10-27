package com.lahuma.app.fajrcall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** An alarm fired: start the call loop, then arm the next alarm. */
class FajrAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != FajrAlarms.ACTION_FIRE) return
        val listId = intent.getStringExtra(FajrAlarms.EXTRA_LIST_ID) ?: return
        val firedAt = intent.getLongExtra(FajrAlarms.EXTRA_FIRED_AT, System.currentTimeMillis())
        try {
            FajrCallService.startScheduled(context, listId, firedAt)
        } catch (e: Exception) {
            // Android 12+ refuses a foreground service from an inexact alarm
            // (no "Alarms & reminders" permission), and some OEMs refuse it
            // anyway: fall back to manual mode with a notification.
            Log.w("FajrCall", "Could not start the call loop: $e")
            FajrNotify.fallback(context, listId, firedAt)
        }
        FajrAlarms.rescheduleAll(context)
    }
}

/**
 * Re-arms the alarms after a reboot, an app update or a clock / timezone
 * change. Fixed-time lists are wall-clock times computed in the old zone,
 * so a timezone change also asks Flutter to resync on next launch.
 */
class FajrBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON" -> FajrAlarms.rescheduleAll(context)
            Intent.ACTION_TIMEZONE_CHANGED -> {
                FajrAlarms.rescheduleAll(context)
                FajrStore(context).needsRefresh = true
            }
        }
    }
}
