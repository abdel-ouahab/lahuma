package com.lahuma.app.fajrcall

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** One auto list as Flutter sent it, with its precomputed fire times. */
data class FajrListConfig(
    val id: String,
    val name: String,
    /** The contacts' JSON exactly as Flutter sent them (kept for the log). */
    val contactJson: List<JSONObject>,
    val loop: CallLoop.LoopConfig,
    val phoneAccountId: String?,
    val fireTimes: List<Long>,
) {
    companion object {
        fun fromJson(o: JSONObject): FajrListConfig {
            val contactsJson = o.optJSONArray("contacts") ?: JSONArray()
            val contactJson = (0 until contactsJson.length()).map { contactsJson.getJSONObject(it) }
            val fire = o.optJSONArray("fireTimes") ?: JSONArray()
            return FajrListConfig(
                id = o.getString("id"),
                name = o.optString("name"),
                contactJson = contactJson,
                loop = CallLoop.LoopConfig(
                    contacts = contactJson.map {
                        CallLoop.Contact(it.optString("id"), it.optString("name"), it.optString("phone"))
                    },
                    ringTimeoutSec = o.optInt("ringTimeoutSec", 20),
                    autoHangUp = o.optBoolean("autoHangUp", true),
                    waitAfterAnswerSec = o.optInt("waitAfterAnswerSec", 30),
                    gapBetweenSec = o.optInt("gapBetweenSec", 3),
                    stopAfterFirstAnswer = o.optBoolean("stopAfterFirstAnswer", false),
                    retryOnNoAnswer = o.optBoolean("retryOnNoAnswer", true),
                    maxRetries = o.optInt("maxRetries", 1),
                    repeatWholeLoop = o.optBoolean("repeatWholeLoop", false),
                    loopRepeats = o.optInt("loopRepeats", 1),
                ),
                phoneAccountId = if (o.has("phoneAccountId")) o.optString("phoneAccountId") else null,
                fireTimes = (0 until fire.length()).map { fire.getLong(it) }.sorted(),
            )
        }
    }
}

/** Texts for the native notifications, in the app's language. */
data class FajrStrings(
    val channelName: String,
    val title: String,
    val calling: String,
    val waiting: String,
    val stop: String,
    val done: String,
) {
    fun callingName(name: String) = calling.replace("%s", name)

    companion object {
        fun fromJson(o: JSONObject?) = FajrStrings(
            channelName = o?.optString("channelName").orEmpty().ifEmpty { "نداء الفجر" },
            title = o?.optString("title").orEmpty().ifEmpty { "نداء الفجر" },
            calling = o?.optString("calling").orEmpty().ifEmpty { "جارٍ الاتصال بـ %s…" },
            waiting = o?.optString("waiting").orEmpty().ifEmpty { "بين اتصالين…" },
            stop = o?.optString("stop").orEmpty().ifEmpty { "إيقاف" },
            done = o?.optString("done").orEmpty().ifEmpty { "انتهى نداء الفجر." },
        )
    }
}

/**
 * Native storage: the config Flutter last sent (the source of truth at fire
 * time, when Flutter may not be running) and the sessions the engine wrote
 * that Flutter has not collected yet.
 */
class FajrStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("lahuma_fajr_call", Context.MODE_PRIVATE)

    fun saveConfig(json: String) = prefs.edit().putString(KEY_CONFIG, json).apply()

    private fun config(): JSONObject? =
        prefs.getString(KEY_CONFIG, null)?.let { runCatching { JSONObject(it) }.getOrNull() }

    fun lists(): List<FajrListConfig> {
        val arr = config()?.optJSONArray("lists") ?: return emptyList()
        return (0 until arr.length()).mapNotNull {
            runCatching { FajrListConfig.fromJson(arr.getJSONObject(it)) }.getOrNull()
        }
    }

    fun list(id: String) = lists().firstOrNull { it.id == id }

    fun strings() = FajrStrings.fromJson(config()?.optJSONObject("strings"))

    var scheduledIds: Set<String>
        get() = prefs.getStringSet(KEY_SCHEDULED, emptySet()) ?: emptySet()
        set(value) = prefs.edit().putStringSet(KEY_SCHEDULED, value).apply()

    /** Precomputed times ran out (or the timezone changed): Flutter should resync. */
    var needsRefresh: Boolean
        get() = prefs.getBoolean(KEY_REFRESH, false)
        set(value) = prefs.edit().putBoolean(KEY_REFRESH, value).apply()

    @Synchronized
    fun appendSession(session: JSONObject) {
        val arr = pendingSessions()
        arr.put(session)
        prefs.edit().putString(KEY_SESSIONS, arr.toString()).commit()
    }

    /** Returns the pending sessions as a JSON array and forgets them. */
    @Synchronized
    fun takeSessions(): String {
        val raw = pendingSessions().toString()
        prefs.edit().remove(KEY_SESSIONS).commit()
        return raw
    }

    private fun pendingSessions(): JSONArray =
        prefs.getString(KEY_SESSIONS, null)?.let { runCatching { JSONArray(it) }.getOrNull() }
            ?: JSONArray()

    private companion object {
        const val KEY_CONFIG = "config"
        const val KEY_SESSIONS = "sessions"
        const val KEY_SCHEDULED = "scheduledIds"
        const val KEY_REFRESH = "needsRefresh"
    }
}
