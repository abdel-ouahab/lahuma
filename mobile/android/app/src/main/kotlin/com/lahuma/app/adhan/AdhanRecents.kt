package com.lahuma.app.adhan

import android.app.ActivityManager
import android.content.Context
import android.util.Log

/**
 * Optionally keeps Ihsan out of the Recents list. On ColorOS (OnePlus,
 * Oppo, Realme) a swipe there force-stops the app, which cancels every
 * adhan until it is opened again. A playing adhan doesn't prevent it: its
 * foreground service was stopped too (OnePlus PJX110, Android 14,
 * `o-stop(40)`). Turned on from the adhan's reliability page or from the
 * "the adhan was stopped" notice.
 *
 * This only partly helps. Recents opened from Home or another app (and its
 * Clear all) leave Ihsan out. But Android always lists the task you are in,
 * so Recents opened from inside Ihsan still shows its card, and swiping it
 * force-stops the app all the same (seen 2026-11-09). Leaving the hidden
 * task with Home is safe: trimming it from Recents didn't stop the app.
 *
 * The flag belongs to the task, so MainActivity applies it again whenever
 * it starts. Also remembers whether a force-stop was ever seen, so the
 * option is offered on other phones that do the same.
 */
object AdhanRecents {
    private const val PREFS = "lahuma_adhan_recents"
    private const val KEY_HIDDEN = "hidden"
    private const val KEY_SEEN_CLEARED = "seenCleared"

    fun isHidden(context: Context): Boolean = prefs(context).getBoolean(KEY_HIDDEN, false)

    fun setHidden(context: Context, hidden: Boolean) {
        prefs(context).edit().putBoolean(KEY_HIDDEN, hidden).apply()
        apply(context)
    }

    /** True once a launch has found the adhans cancelled by a force-stop. */
    fun seenCleared(context: Context): Boolean = prefs(context).getBoolean(KEY_SEEN_CLEARED, false)

    fun markCleared(context: Context) {
        prefs(context).edit().putBoolean(KEY_SEEN_CLEARED, true).apply()
    }

    /** Sets the stored choice on this app's tasks. */
    fun apply(context: Context) {
        val hidden = isHidden(context)
        val am = context.getSystemService(ActivityManager::class.java) ?: return
        try {
            for (task in am.appTasks) task.setExcludeFromRecents(hidden)
        } catch (e: RuntimeException) {
            // A task that finished meanwhile.
            Log.w("Adhan", "Could not set excludeFromRecents: $e")
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
