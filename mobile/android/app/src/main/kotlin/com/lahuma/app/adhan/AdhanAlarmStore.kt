package com.lahuma.app.adhan

import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

/** One adhan to play: what Flutter planned (`AdhanAlarm` in Dart). */
data class AdhanAlarmSlot(
    val id: Int,
    val at: Long,
    val prayer: String,
    val title: String,
    val body: String,
    /** A downloaded recording; null plays `res/raw/adhan_default_regular`. */
    val file: String?,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id).put("at", at).put("prayer", prayer)
        .put("title", title).put("body", body).put("file", file ?: JSONObject.NULL)

    fun putInto(intent: Intent): Intent = intent.putExtra(EXTRA_SLOT, toJson().toString())

    companion object {
        private const val EXTRA_SLOT = "adhanSlot"

        fun fromJson(o: JSONObject) = AdhanAlarmSlot(
            id = o.getInt("id"),
            at = o.getLong("at"),
            prayer = o.optString("prayer"),
            title = o.optString("title"),
            body = o.optString("body"),
            file = if (o.isNull("file")) null else o.optString("file").ifEmpty { null },
        )

        fun fromMap(m: Map<*, *>) = AdhanAlarmSlot(
            id = (m["id"] as Number).toInt(),
            at = (m["at"] as Number).toLong(),
            prayer = m["prayer"] as? String ?: "",
            title = m["title"] as? String ?: "",
            body = m["body"] as? String ?: "",
            file = (m["file"] as? String)?.ifEmpty { null },
        )

        fun fromIntent(intent: Intent?): AdhanAlarmSlot? =
            intent?.getStringExtra(EXTRA_SLOT)?.let {
                runCatching { fromJson(JSONObject(it)) }.getOrNull()
            }
    }
}

/** Texts sent from Flutter (the app language is an in-app setting). */
data class AdhanStrings(val stop: String, val channel: String, val fallbackChannel: String) {
    fun toJson(): JSONObject = JSONObject()
        .put("stop", stop).put("channel", channel).put("fallbackChannel", fallbackChannel)

    companion object {
        val DEFAULT = AdhanStrings("إيقاف", "الأذان", "وقت الصلاة")

        fun fromMap(m: Map<*, *>?) = if (m == null) DEFAULT else AdhanStrings(
            stop = m["stop"] as? String ?: DEFAULT.stop,
            channel = m["channel"] as? String ?: DEFAULT.channel,
            fallbackChannel = m["fallbackChannel"] as? String ?: DEFAULT.fallbackChannel,
        )

        fun fromJson(o: JSONObject?) = if (o == null) DEFAULT else AdhanStrings(
            stop = o.optString("stop", DEFAULT.stop),
            channel = o.optString("channel", DEFAULT.channel),
            fallbackChannel = o.optString("fallbackChannel", DEFAULT.fallbackChannel),
        )
    }
}

/**
 * The planned adhans, kept natively so a reboot can re-arm them without
 * Flutter. Separate prefs file from Fajr Call's (`FajrStore`).
 */
class AdhanAlarmStore(context: Context) {
    private val prefs = context.getSharedPreferences("lahuma_adhan_alarms", Context.MODE_PRIVATE)

    var slots: List<AdhanAlarmSlot>
        get() = read(KEY_SLOTS)
        set(value) = write(KEY_SLOTS, value)

    /** "Test the adhan" alarms; [slots] syncs leave them alone. */
    var tests: List<AdhanAlarmSlot>
        get() = read(KEY_TESTS)
        set(value) = write(KEY_TESTS, value)

    /** Ids armed with AlarmManager, so stale ones can be cancelled. */
    var armedIds: Set<Int>
        get() = prefs.getStringSet(KEY_ARMED, emptySet())!!.mapNotNull { it.toIntOrNull() }.toSet()
        set(value) = prefs.edit().putStringSet(KEY_ARMED, value.map { it.toString() }.toSet()).apply()

    /** When [armedIds] were last armed (wall clock, ms). */
    var armedAt: Long
        get() = prefs.getLong(KEY_ARMED_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_ARMED_AT, value).apply()

    var strings: AdhanStrings
        get() = AdhanStrings.fromJson(prefs.getString(KEY_STRINGS, null)?.let {
            runCatching { JSONObject(it) }.getOrNull()
        })
        set(value) = prefs.edit().putString(KEY_STRINGS, value.toJson().toString()).apply()

    private fun read(key: String): List<AdhanAlarmSlot> {
        val raw = prefs.getString(key, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { AdhanAlarmSlot.fromJson(arr.getJSONObject(it)) }
        }.getOrDefault(emptyList())
    }

    private fun write(key: String, value: List<AdhanAlarmSlot>) {
        val arr = JSONArray()
        value.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(key, arr.toString()).apply()
    }

    private companion object {
        const val KEY_SLOTS = "slots"
        const val KEY_TESTS = "tests"
        const val KEY_ARMED = "armed"
        const val KEY_ARMED_AT = "armedAt"
        const val KEY_STRINGS = "strings"
    }
}
