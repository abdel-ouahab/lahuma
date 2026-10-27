package com.lahuma.app.fajrcall

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.lahuma.app.MainActivity

/**
 * Schedules one alarm per auto list at its next precomputed fire time.
 * Flutter computes the times (prayer times live in Dart); this only picks
 * the next one. When they run out it repeats the last one every 24 h and
 * flags [FajrStore.needsRefresh] until the app is opened again.
 */
object FajrAlarms {
    const val ACTION_FIRE = "com.lahuma.app.fajrcall.FIRE"
    const val EXTRA_LIST_ID = "listId"
    const val EXTRA_FIRED_AT = "firedAt"
    private const val DAY_MS = 24L * 60 * 60 * 1000

    /** The next fire time after [now], falling back to last + n × 24 h. */
    fun nextFireTime(fireTimes: List<Long>, now: Long): Pair<Long, Boolean>? {
        if (fireTimes.isEmpty()) return null
        fireTimes.firstOrNull { it > now }?.let { return it to false }
        var t = fireTimes.last()
        while (t <= now) t += DAY_MS
        return t to true
    }

    fun rescheduleAll(context: Context, now: Long = System.currentTimeMillis()) {
        val store = FajrStore(context)
        val lists = store.lists()
        for (id in store.scheduledIds - lists.map { it.id }.toSet()) cancel(context, id)
        var stale = false
        for (list in lists) {
            val next = nextFireTime(list.fireTimes, now)
            if (next == null || list.loop.contacts.isEmpty()) {
                cancel(context, list.id)
                continue
            }
            stale = stale || next.second
            set(context, list.id, next.first)
        }
        store.scheduledIds = lists.map { it.id }.toSet()
        store.needsRefresh = stale
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager(context).canScheduleExactAlarms()

    private fun fireIntent(context: Context, listId: String, at: Long?): PendingIntent {
        val intent = Intent(context, FajrAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_LIST_ID, listId)
        if (at != null) intent.putExtra(EXTRA_FIRED_AT, at)
        return PendingIntent.getBroadcast(
            context, listId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun set(context: Context, listId: String, at: Long) {
        val am = alarmManager(context)
        val pi = fireIntent(context, listId, at)
        if (canScheduleExact(context)) {
            // An alarm clock is exact even in Doze, and its firing lets the
            // receiver start the foreground service.
            val show = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pi)
        } else {
            // Without "Alarms & reminders" Android may deliver this late, and
            // won't let it start a foreground service: the receiver then
            // falls back to a notification that opens the wake list.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    fun cancel(context: Context, listId: String) {
        alarmManager(context).cancel(fireIntent(context, listId, null))
    }
}
