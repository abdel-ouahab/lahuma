package com.lahuma.app.fajrcall

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.lahuma.app.MainActivity

/** The engine's notifications: ongoing loop, results, and manual fallback. */
object FajrNotify {
    const val ONGOING_ID = 0x7a11
    private const val CHANNEL_ONGOING = "fajr_call_engine"
    private const val CHANNEL_RESULTS = "fajr_call_results"
    const val EXTRA_ROUTE = "route"

    fun ensureChannels(context: Context, strings: FajrStrings) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        // Low: the in-call screen already rings; this one only carries Stop.
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ONGOING, strings.channelName, NotificationManager.IMPORTANCE_LOW),
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_RESULTS, strings.channelName, NotificationManager.IMPORTANCE_HIGH),
        )
    }

    /** Opens the app at [route] (handled by Flutter through the channel). */
    fun openApp(context: Context, route: String, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            context, requestCode,
            Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(EXTRA_ROUTE, route),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun ongoing(context: Context, strings: FajrStrings, text: String, stop: PendingIntent) =
        NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.sym_call_outgoing)
            .setContentTitle(strings.title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, strings.stop, stop)
            .build()

    fun done(context: Context, strings: FajrStrings, listId: String) {
        notify(
            context, listId.hashCode(),
            NotificationCompat.Builder(context, CHANNEL_RESULTS)
                .setSmallIcon(android.R.drawable.sym_call_outgoing)
                .setContentTitle(strings.title)
                .setContentText(strings.done)
                .setAutoCancel(true)
                .setContentIntent(openApp(context, "/home/fajr-call/$listId/log", listId.hashCode()))
                .build(),
        )
    }

    /** The loop could not start: let the user call from the wake list. */
    fun fallback(context: Context, listId: String, firedAt: Long) {
        val store = FajrStore(context)
        val strings = store.strings()
        ensureChannels(context, strings)
        val list = store.list(listId)
        notify(
            context, listId.hashCode(),
            NotificationCompat.Builder(context, CHANNEL_RESULTS)
                .setSmallIcon(android.R.drawable.sym_call_outgoing)
                .setContentTitle(listOfNotNull(strings.title, list?.name).joinToString(" · "))
                .setContentText(list?.loop?.contacts?.joinToString("، ") { it.name } ?: "")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(openApp(context, "/fajr-call/wake/$listId?at=$firedAt", listId.hashCode()))
                .build(),
        )
    }

    private fun notify(context: Context, id: Int, notification: android.app.Notification) {
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied: nothing to show.
        }
    }
}
