package com.lahuma.app.adhan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.lahuma.app.MainActivity
import com.lahuma.app.R
import com.lahuma.app.fajrcall.FajrNotify

/**
 * The adhan engine's notifications. Channel ids start with `adhan_` and are
 * listed in `AdhanScheduler.nativeChannels`, so the Dart side's cleanup of
 * old `adhan_` channels keeps them.
 */
object AdhanNotify {
    /** The player's ongoing notification (Fajr Call's is 0x7a11). */
    const val PLAYING_ID = 0xad4a
    private const val CHANNEL_PLAYING = "adhan_playing"
    private const val CHANNEL_ALERT = "adhan_alert"

    /** Mosque green, the glyph and app-name tint (Dart: LocalNotifications.accent). */
    private const val ACCENT = 0xFF0F5A4A.toInt()

    fun ensureChannels(context: Context, strings: AdhanStrings) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        // High (heads-up) but silent: the service plays the adhan itself.
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_PLAYING, strings.channel, NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(false)
            },
        )
        // The player couldn't start: the default sound, so it's noticed.
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ALERT, strings.fallbackChannel, NotificationManager.IMPORTANCE_HIGH),
        )
    }

    private fun openApp(context: Context, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            context, requestCode,
            Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** While the adhan plays: Stop, and a swipe (Android 14+) stops too. */
    fun playing(context: Context, slot: AdhanAlarmSlot, strings: AdhanStrings, stop: PendingIntent): Notification {
        ensureChannels(context, strings)
        return NotificationCompat.Builder(context, CHANNEL_PLAYING)
            .setSmallIcon(R.drawable.ic_stat_ihsan)
            .setColor(ACCENT)
            .setContentTitle(slot.title)
            .setContentText(slot.body)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openApp(context, slot.id))
            .setDeleteIntent(stop)
            .addAction(android.R.drawable.ic_media_pause, strings.stop, stop)
            .build()
    }

    /**
     * The prayer's notification without the player: it could not start, the
     * alarm came too late to play it, or (with [quiet]) it has finished and
     * this stays behind. A tap opens the in-app adhan.
     */
    fun fallback(context: Context, slot: AdhanAlarmSlot, quiet: Boolean = false) {
        val strings = AdhanAlarmStore(context).strings
        ensureChannels(context, strings)
        // slot.body is the player's line ("the adhan is playing", or the
        // muezzin): not true here. Fajr's "prayer is better than sleep" stays.
        val body = if (slot.prayer == "fajr") slot.body else strings.tapToListen
        val n = NotificationCompat.Builder(context, CHANNEL_ALERT)
            .setSmallIcon(R.drawable.ic_stat_ihsan)
            .setColor(ACCENT)
            .setContentTitle(slot.title)
            .setContentText(body)
            .setSubText(strings.fallbackChannel)
            .setWhen(slot.at)
            .setShowWhen(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            // After the adhan: no second sound or pop-up.
            .setSilent(quiet)
            .setContentIntent(FajrNotify.openApp(context, "/adhan/play?prayer=${slot.prayer}", slot.id))
            .build()
        try {
            NotificationManagerCompat.from(context).notify(slot.id, n)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied: nothing to show.
        }
    }
}
