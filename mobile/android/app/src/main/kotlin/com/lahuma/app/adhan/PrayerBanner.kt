package com.lahuma.app.adhan

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.lahuma.app.MainActivity
import com.lahuma.app.R
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** Texts for the prayer-times banner, sent from Flutter (in-app language). */
data class PrayerBannerStrings(
    /** Fajr, Dhuhr, Asr, Maghrib, Isha, in that order. */
    val names: List<String>,
    /** The countdown's format: `%s` is the time left ("in %s", «بعد %s»). */
    val countdown: String,
    val channel: String,
    val rtl: Boolean,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("names", JSONArray(names)).put("countdown", countdown)
        .put("channel", channel).put("rtl", rtl)

    companion object {
        val DEFAULT = PrayerBannerStrings(
            listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء"), "بعد %s", "مواقيت الصلاة", true,
        )

        private fun names(raw: Any?): List<String>? = when (raw) {
            is List<*> -> raw.map { "$it" }
            is JSONArray -> (0 until raw.length()).map { raw.optString(it) }
            else -> null
        }?.takeIf { it.size == PrayerBanner.PRAYERS }

        fun fromMap(m: Map<*, *>?) = if (m == null) DEFAULT else PrayerBannerStrings(
            names = names(m["names"]) ?: DEFAULT.names,
            countdown = (m["countdown"] as? String)?.takeIf { "%s" in it } ?: DEFAULT.countdown,
            channel = m["channel"] as? String ?: DEFAULT.channel,
            rtl = m["rtl"] as? Boolean ?: DEFAULT.rtl,
        )

        fun fromJson(o: JSONObject?) = if (o == null) DEFAULT else PrayerBannerStrings(
            names = names(o.optJSONArray("names")) ?: DEFAULT.names,
            countdown = o.optString("countdown", DEFAULT.countdown).takeIf { "%s" in it } ?: DEFAULT.countdown,
            channel = o.optString("channel", DEFAULT.channel),
            rtl = o.optBoolean("rtl", DEFAULT.rtl),
        )
    }
}

/** What Flutter last sent: the switch, the days ahead and the texts. */
class PrayerBannerStore(context: Context) {
    private val prefs = context.getSharedPreferences("lahuma_prayer_banner", Context.MODE_PRIVATE)

    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    /** Each day's five prayer times (epoch ms), in order. */
    var days: List<List<Long>>
        get() = runCatching {
            val arr = JSONArray(prefs.getString(KEY_DAYS, "[]"))
            (0 until arr.length()).map { i ->
                val d = arr.getJSONArray(i)
                (0 until d.length()).map { d.getLong(it) }
            }.filter { it.size == PrayerBanner.PRAYERS }
        }.getOrDefault(emptyList())
        set(value) = prefs.edit().putString(KEY_DAYS, JSONArray(value.map { JSONArray(it) }).toString()).apply()

    var strings: PrayerBannerStrings
        get() = PrayerBannerStrings.fromJson(prefs.getString(KEY_STRINGS, null)?.let {
            runCatching { JSONObject(it) }.getOrNull()
        })
        set(value) = prefs.edit().putString(KEY_STRINGS, value.toJson().toString()).apply()

    private companion object {
        const val KEY_ENABLED = "enabled"
        const val KEY_DAYS = "days"
        const val KEY_STRINGS = "strings"
    }
}

/**
 * The prayer-times banner: an ongoing, silent notification with the next
 * prayer, a countdown the system ticks by itself, and (expanded) the five
 * times of that day. One alarm at the next prayer moves it on; the adhan
 * alarm, the boot receiver and every Flutter sync refresh it too.
 *
 * A force-stop (a swipe from Recents on ColorOS) removes it with every
 * other notification; it comes back on the next launch.
 */
object PrayerBanner {
    const val PRAYERS = 5
    const val NOTIFICATION_ID = 0x9b22
    private const val CHANNEL = "prayer_banner"
    private const val ACTION_TICK = "com.lahuma.app.PRAYER_BANNER_TICK"
    private const val ACTION_DISMISSED = "com.lahuma.app.PRAYER_BANNER_DISMISSED"
    private const val TAG = "PrayerBanner"
    private const val ACCENT = 0xFF0F5A4A.toInt()

    private val NAME_IDS = intArrayOf(R.id.pb_name_0, R.id.pb_name_1, R.id.pb_name_2, R.id.pb_name_3, R.id.pb_name_4)
    private val TIME_IDS = intArrayOf(R.id.pb_time_0, R.id.pb_time_1, R.id.pb_time_2, R.id.pb_time_3, R.id.pb_time_4)

    /** The day to show and which of its prayers comes next, or null. */
    data class Next(val day: List<Long>, val index: Int) {
        val at get() = day[index]
    }

    fun next(days: List<List<Long>>, now: Long): Next? {
        for (d in days.sortedBy { it.first() }) {
            val i = d.indexOfFirst { it > now }
            if (i >= 0) return Next(d, i)
        }
        return null
    }

    fun sync(context: Context, enabled: Boolean, days: List<List<Long>>, strings: PrayerBannerStrings) {
        val store = PrayerBannerStore(context)
        store.enabled = enabled
        store.days = days
        store.strings = strings
        refresh(context)
    }

    fun refresh(context: Context, now: Long = System.currentTimeMillis()) {
        val store = PrayerBannerStore(context)
        // A second ahead, so the tick at a prayer's minute moves past it.
        val next = if (store.enabled) next(store.days, now + 1_000) else null
        if (next == null) {
            cancel(context)
            return
        }
        val strings = store.strings
        try {
            ensureChannel(context, strings)
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, build(context, next, strings, now))
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS denied: nothing to show, but keep the tick.
            Log.i(TAG, "Not allowed to post: $e")
        } catch (e: Exception) {
            Log.w(TAG, "Could not post the banner: $e")
        }
        arm(context, next.at)
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        alarmManager(context).cancel(tick(context))
    }

    private fun ensureChannel(context: Context, strings: PrayerBannerStrings) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, strings.channel, NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun build(context: Context, next: Next, strings: PrayerBannerStrings, now: Long) =
        NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_ihsan)
            .setColor(ACCENT)
            .setContentTitle("${strings.names[next.index]}  ${hhmm(next.at)}")
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(views(context, R.layout.prayer_banner_small, next, strings, now))
            .setCustomBigContentView(views(context, R.layout.prayer_banner_big, next, strings, now))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openApp(context))
            // Android 14+ lets ongoing notifications be swiped: put it back.
            .setDeleteIntent(dismissed(context))
            .build()

    private fun views(context: Context, layout: Int, next: Next, strings: PrayerBannerStrings, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, layout)
        v.setTextViewText(R.id.pb_next_name, strings.names[next.index])
        v.setTextViewText(R.id.pb_next_time, hhmm(next.at))
        // The Chronometer counts down on its own; its base is on the
        // elapsed-realtime clock.
        val base = SystemClock.elapsedRealtime() + (next.at - now)
        v.setChronometer(R.id.pb_countdown, base, strings.countdown, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            v.setChronometerCountDown(R.id.pb_countdown, true)
        } else {
            // No count-down before Android 7: show the time instead.
            v.setViewVisibility(R.id.pb_countdown, View.GONE)
        }
        if (layout == R.layout.prayer_banner_big) {
            // In the app's language order: reversed when the app and the
            // system disagree on direction.
            val systemRtl = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL
            val reverse = strings.rtl != systemRtl
            val gold = ContextCompat.getColor(context, R.color.prayer_banner_gold)
            val muted = ContextCompat.getColor(context, R.color.prayer_banner_muted)
            for (col in 0 until PRAYERS) {
                val p = if (reverse) PRAYERS - 1 - col else col
                val color = if (p == next.index) gold else muted
                v.setTextViewText(NAME_IDS[col], strings.names[p])
                v.setTextViewText(TIME_IDS[col], hhmm(next.day[p]))
                v.setTextColor(NAME_IDS[col], color)
                v.setTextColor(TIME_IDS[col], color)
            }
        }
        return v
    }

    /** 24-hour HH:mm, as on Home. */
    private fun hhmm(at: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = at }
        return "%02d:%02d".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    /**
     * The tick that moves the banner on at [at]. ColorOS gives even
     * `setExactAndAllowWhileIdle` a one-hour window (seen on the OnePlus,
     * 2026-11-11), so the count-down would run below zero. So it's an alarm
     * clock, like the adhans, which costs the status-bar alarm icon. When
     * an adhan is armed for that minute, its receiver refreshes the banner
     * on time, and the tick stays a quiet backup.
     */
    private fun arm(context: Context, at: Long) {
        val am = alarmManager(context)
        val pi = tick(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            return
        }
        if (!AdhanAlarms.canScheduleExact(context)) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            return
        }
        if (adhanArmedAt(context, at)) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, openApp(context)), pi)
        }
    }

    private fun adhanArmedAt(context: Context, at: Long): Boolean {
        val store = AdhanAlarmStore(context)
        val armed = store.armedIds
        return store.slots.any { it.id in armed && kotlin.math.abs(it.at - at) < 1_000 }
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun tick(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, NOTIFICATION_ID,
        Intent(context, PrayerBannerReceiver::class.java).setAction(ACTION_TICK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun dismissed(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, NOTIFICATION_ID + 1,
        Intent(context, PrayerBannerReceiver::class.java).setAction(ACTION_DISMISSED),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context, NOTIFICATION_ID,
        Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    internal fun isOurs(action: String?) = action == ACTION_TICK || action == ACTION_DISMISSED
}

/** The next prayer came, or the banner was swiped away: post it again. */
class PrayerBannerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (PrayerBanner.isOurs(intent.action)) PrayerBanner.refresh(context)
    }
}
