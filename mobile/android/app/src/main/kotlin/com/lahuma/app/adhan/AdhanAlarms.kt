package com.lahuma.app.adhan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import com.lahuma.app.MainActivity

/**
 * Arms one exact alarm per planned adhan (a week: up to 35, plus tests).
 *
 * Each alarm is `setAlarmClock`. That is only how it is timed: the adhan
 * itself plays as a notification sound, not on the alarm stream. It is
 * used because it is exact in Doze and honoured by OEM battery savers
 * (ColorOS stretches `setExactAndAllowWhileIdle` to a one-hour window),
 * and because its firing is one of the cases in which Android 12+ lets a
 * background app start a foreground service, so [AdhanAlarmReceiver] may
 * start [AdhanPlaybackService]. The cost is the alarm icon in the status
 * bar. Without the exact
 * alarm permission (Android 12+, "Alarms & reminders") the alarm becomes
 * `setAndAllowWhileIdle`: it may be late and may not start the service,
 * and the receiver then posts a notification instead.
 *
 * The PendingIntent request code is the planner's id (200 000 000+), and
 * the data URI makes each one distinct, so none collides with Fajr Call's
 * alarms (another receiver, `listId.hashCode()` codes).
 */
object AdhanAlarms {
    const val ACTION_FIRE = "com.lahuma.app.adhan.FIRE"

    /** An alarm delivered later than this (inexact, held back) doesn't play the adhan… */
    const val MAX_LATE_MS = 10L * 60 * 1000

    /** …and later than this (the phone was off) it shows nothing at all. */
    const val MAX_NOTIFY_LATE_MS = 90L * 60 * 1000

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager(context).canScheduleExactAlarms()

    /** Re-arms every stored adhan still ahead, cancels the rest. */
    @Synchronized
    fun rescheduleAll(context: Context, now: Long = System.currentTimeMillis()) {
        val store = AdhanAlarmStore(context)
        val tests = store.tests.filter { it.at > now - MAX_LATE_MS }
        if (tests.size != store.tests.size) store.tests = tests
        val ahead = (store.slots + tests).filter { it.at > now }
        val keep = ahead.map { it.id }.toSet()
        for (id in store.armedIds - keep) cancel(context, id)
        for (slot in ahead) set(context, slot)
        store.armedIds = keep
        store.armedAt = now
    }

    /**
     * True when an adhan this app armed is still ahead but its alarm is
     * gone: the app was force-stopped, which cancels every alarm it has
     * until it is opened again. Settings → Force stop does it, and so do
     * ColorOS (OnePlus, Oppo, Realme) and other skins when the app is
     * swiped away from Recents. Call before anything re-arms them.
     *
     * Each adhan is an alarm clock, so the system's next alarm clock is
     * ours or comes before our next adhan; when there is none by then, ours
     * was cancelled. (A force-stop leaves PendingIntents in place, so
     * looking them up with FLAG_NO_CREATE proves nothing.) Another app's
     * earlier alarm clock hides ours: then this says false.
     *
     * A reboot also clears alarms, but [AdhanBootReceiver] re-arms those,
     * so alarms armed before the last boot don't count.
     */
    fun wereCleared(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        if (!canScheduleExact(context)) return false // not alarm clocks then
        val store = AdhanAlarmStore(context)
        val bootedAt = now - SystemClock.elapsedRealtime()
        if (store.armedAt < bootedAt) return false
        val armed = store.armedIds
        // Not one about to fire: it may be on its way to the receiver.
        val next = (store.slots + store.tests)
            .filter { it.id in armed && it.at > now + 60_000 }
            .minOfOrNull { it.at } ?: return false
        val clock = alarmManager(context).nextAlarmClock ?: return true
        return clock.triggerTime > next
    }

    private fun fireIntent(context: Context, id: Int, slot: AdhanAlarmSlot?): PendingIntent {
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .setData(Uri.parse("lahuma-adhan://alarm/$id"))
        slot?.putInto(intent)
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun set(context: Context, slot: AdhanAlarmSlot) {
        val am = alarmManager(context)
        val pi = fireIntent(context, slot.id, slot)
        if (canScheduleExact(context)) {
            // What the system clock UI opens when the alarm icon is tapped.
            val show = PendingIntent.getActivity(
                context, slot.id, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(slot.at, show), pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, slot.at, pi)
        }
    }

    private fun cancel(context: Context, id: Int) {
        alarmManager(context).cancel(fireIntent(context, id, null))
    }

    /** Called once a test alarm fired, so a reboot doesn't replay it. */
    fun forgetTest(context: Context, id: Int) {
        val store = AdhanAlarmStore(context)
        val left = store.tests.filter { it.id != id }
        if (left.size != store.tests.size) store.tests = left
    }
}
