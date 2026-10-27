package com.lahuma.app.fajrcall

import android.Manifest
import android.annotation.SuppressLint
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.CallLog
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.PhoneNumberUtils
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.lahuma.app.BuildConfig
import org.json.JSONArray
import org.json.JSONObject

/**
 * Runs one Fajr Call loop in the foreground (type `specialUse`), with an
 * ongoing notification that carries a Stop action. Works with the app
 * killed and the screen off: it is started by [FajrAlarmReceiver] from an
 * alarm clock, holds a partial wake lock, places calls through Telecom and
 * follows them with the call-state listener.
 */
class FajrCallService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var loop: CallLoop? = null
    private var list: FajrListConfig? = null
    private var strings: FajrStrings? = null
    private var firedAt = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private var unregisterCallState: (() -> Unit)? = null
    private var currentPhone: String? = null
    private var currentStart = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                loop?.stop() ?: stopSelf()
                return START_NOT_STICKY
            }
            ACTION_RUN -> {
                if (loop != null) return START_NOT_STICKY // one loop at a time
                val store = FajrStore(this)
                val json = intent.getStringExtra(EXTRA_LIST_JSON)
                val config = if (json != null) {
                    runCatching { FajrListConfig.fromJson(JSONObject(json)) }.getOrNull()
                } else {
                    intent.getStringExtra(FajrAlarms.EXTRA_LIST_ID)?.let { store.list(it) }
                }
                val texts = intent.getStringExtra(EXTRA_STRINGS_JSON)
                    ?.let { FajrStrings.fromJson(runCatching { JSONObject(it) }.getOrNull()) }
                    ?: store.strings()
                firedAt = intent.getLongExtra(FajrAlarms.EXTRA_FIRED_AT, System.currentTimeMillis())
                if (config == null || config.loop.contacts.isEmpty()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                begin(config, texts)
            }
            else -> stopSelf()
        }
        // If the system kills the loop, do not replay it hours later.
        return START_NOT_STICKY
    }

    private fun begin(config: FajrListConfig, texts: FajrStrings) {
        list = config
        strings = texts
        FajrNotify.ensureChannels(this, texts)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(
            this, FajrNotify.ONGOING_ID,
            FajrNotify.ongoing(this, texts, texts.title, stopIntent()), type,
        )

        if (!FajrPermissions.canAutoCall(this)) {
            // Permissions were revoked since the list was saved.
            FajrNotify.fallback(this, config.id, firedAt)
            stopSelf()
            return
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "lahuma:fajr-call").apply {
            acquire(MAX_RUN_MS)
        }

        val l = CallLoop(
            config.loop,
            TelecomDialer(config.phoneAccountId),
            HandlerTimer(handler),
            System::currentTimeMillis,
            object : CallLoop.Listener {
                override fun onCalling(contact: CallLoop.Contact, attemptNo: Int) {
                    currentPhone = contact.phone
                    currentStart = System.currentTimeMillis()
                    update(texts.callingName(contact.name))
                }

                override fun onWaiting() = update(texts.waiting)

                override fun onFinished(attempts: List<CallLoop.Attempt>, stoppedByUser: Boolean) {
                    finish(attempts, stoppedByUser)
                }
            },
        )
        loop = l
        unregisterCallState = listenToCallState()
        // Safety net: never run longer than MAX_RUN_MS.
        handler.postDelayed({ loop?.stop() }, MAX_RUN_MS)
        l.start()
    }

    private fun update(text: String) {
        val texts = strings ?: return
        try {
            androidx.core.app.NotificationManagerCompat.from(this)
                .notify(FajrNotify.ONGOING_ID, FajrNotify.ongoing(this, texts, text, stopIntent()))
        } catch (_: SecurityException) {
        }
    }

    private fun stopIntent() = android.app.PendingIntent.getService(
        this, 1, Intent(this, FajrCallService::class.java).setAction(ACTION_STOP),
        android.app.PendingIntent.FLAG_IMMUTABLE,
    )

    // ── Call state ────────────────────────────────────────────────────────

    private fun onCallState(state: Int) {
        val l = loop ?: return
        when (state) {
            TelephonyManager.CALL_STATE_OFFHOOK -> l.onCallActive()
            TelephonyManager.CALL_STATE_IDLE -> {
                if (FajrPermissions.callLogUsable(this)) {
                    val phone = currentPhone
                    val since = currentStart
                    // The call log is written just after the call ends.
                    handler.postDelayed({ l.onCallIdle(answeredFromCallLog(phone, since)) }, 1_500)
                } else {
                    l.onCallIdle(null)
                }
            }
        }
    }

    @SuppressLint("MissingPermission") // checked by FajrPermissions.canAutoCall
    private fun listenToCallState(): () -> Unit {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) = onCallState(state)
            }
            tm.registerTelephonyCallback(ContextCompat.getMainExecutor(this), cb)
            ({ tm.unregisterTelephonyCallback(cb) })
        } else {
            @Suppress("DEPRECATION")
            val l = object : PhoneStateListener() {
                @Deprecated("Deprecated in Java")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) = onCallState(state)
            }
            @Suppress("DEPRECATION")
            tm.listen(l, PhoneStateListener.LISTEN_CALL_STATE)
            @Suppress("DEPRECATION")
            ({ tm.listen(l, PhoneStateListener.LISTEN_NONE) })
        }
    }

    /** Call-log builds only: was the last outgoing call to [phone] answered? */
    private fun answeredFromCallLog(phone: String?, since: Long): Boolean? {
        if (phone == null) return null
        return try {
            contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.DURATION),
                "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.DATE} >= ?",
                arrayOf(CallLog.Calls.OUTGOING_TYPE.toString(), (since - 10_000).toString()),
                "${CallLog.Calls.DATE} DESC",
            )?.use { c ->
                while (c.moveToNext()) {
                    @Suppress("DEPRECATION")
                    if (PhoneNumberUtils.compare(c.getString(0), phone)) return c.getLong(1) > 0
                }
                null
            }
        } catch (e: SecurityException) {
            null
        }
    }

    // ── Dialling ──────────────────────────────────────────────────────────

    private inner class TelecomDialer(private val accountId: String?) : CallLoop.Dialer {
        private val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        @SuppressLint("MissingPermission")
        override fun place(contact: CallLoop.Contact): Boolean {
            if (!FajrPermissions.has(this@FajrCallService, Manifest.permission.CALL_PHONE)) return false
            return try {
                val extras = Bundle()
                phoneAccount(accountId)?.let {
                    extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it)
                }
                // placeCall works from a service: no activity start, so the
                // Android 10+ background-activity limits don't apply.
                telecom.placeCall(Uri.fromParts("tel", contact.phone, null), extras)
                true
            } catch (e: Exception) {
                Log.w(TAG, "placeCall failed: $e")
                false
            }
        }

        @SuppressLint("MissingPermission")
        override fun hangUp(): Boolean {
            // endCall() is deprecated since API 29 with no replacement for apps
            // that are not the default dialler; it still works with
            // ANSWER_PHONE_CALLS on the devices we tested. When it is refused
            // the loop waits for the network to end the call.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
            if (!FajrPermissions.has(this@FajrCallService, Manifest.permission.ANSWER_PHONE_CALLS)) return false
            return try {
                @Suppress("DEPRECATION")
                telecom.endCall()
            } catch (e: Exception) {
                Log.w(TAG, "endCall failed: $e")
                false
            }
        }
    }

    private class HandlerTimer(private val handler: Handler) : CallLoop.LoopTimer {
        override fun schedule(delayMs: Long, action: () -> Unit): CallLoop.Cancellable {
            val r = Runnable(action)
            handler.postDelayed(r, delayMs)
            return object : CallLoop.Cancellable {
                override fun cancel() = handler.removeCallbacks(r)
            }
        }
    }

    // ── Finish ────────────────────────────────────────────────────────────

    private fun finish(attempts: List<CallLoop.Attempt>, stoppedByUser: Boolean) {
        val config = list ?: return
        FajrStore(this).appendSession(sessionJson(config, attempts, stoppedByUser))
        strings?.let { FajrNotify.done(this, it, config.id) }
        FajrCallChannel.notifySessionsChanged()
        cleanUp()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** The session in the JSON shape of Flutter's `CallSession`. */
    private fun sessionJson(
        config: FajrListConfig,
        attempts: List<CallLoop.Attempt>,
        stoppedByUser: Boolean,
    ): JSONObject {
        val contacts = config.contactJson.associateBy { it.optString("id") }
        val arr = JSONArray()
        for (a in attempts) {
            arr.put(JSONObject().apply {
                put("contact", contacts[a.contact.id] ?: JSONObject().apply {
                    put("id", a.contact.id)
                    put("name", a.contact.name)
                    put("phone", a.contact.phone)
                })
                put("startedAt", a.startedAt)
                put("endedAt", a.endedAt)
                put("status", when (a.status) {
                    CallLoop.Status.ANSWERED -> "answered"
                    CallLoop.Status.NO_ANSWER -> "noAnswer"
                    CallLoop.Status.FAILED -> "failed"
                    CallLoop.Status.CALLED -> "called"
                })
                put("attemptNo", a.attemptNo)
            })
        }
        return JSONObject().apply {
            put("id", "a_${config.id}_$firedAt")
            put("listId", config.id)
            put("listName", config.name)
            put("firedAt", firedAt)
            put("mode", "auto")
            put("attempts", arr)
            if (stoppedByUser) put("stoppedByUser", true)
        }
    }

    private fun cleanUp() {
        handler.removeCallbacksAndMessages(null)
        unregisterCallState?.invoke()
        unregisterCallState = null
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        loop = null
    }

    override fun onDestroy() {
        // Killed mid-loop: keep what was done so far.
        loop?.let { l -> if (!l.isDone) list?.let { FajrStore(this).appendSession(sessionJson(it, l.results, true)) } }
        cleanUp()
        super.onDestroy()
    }

    private fun phoneAccount(id: String?): PhoneAccountHandle? {
        if (id == null) return null
        val parts = id.split('|', limit = 2)
        if (parts.size != 2) return null
        val component = ComponentName.unflattenFromString(parts[0]) ?: return null
        return PhoneAccountHandle(component, parts[1])
    }

    companion object {
        private const val TAG = "FajrCall"
        const val ACTION_RUN = "com.lahuma.app.fajrcall.RUN"
        const val ACTION_STOP = "com.lahuma.app.fajrcall.STOP"
        const val EXTRA_LIST_JSON = "listJson"
        const val EXTRA_STRINGS_JSON = "stringsJson"

        /** A loop never runs longer than this (calls, retries and gaps). */
        const val MAX_RUN_MS = 30L * 60 * 1000

        fun startScheduled(context: Context, listId: String, firedAt: Long) {
            ContextCompat.startForegroundService(
                context,
                Intent(context, FajrCallService::class.java)
                    .setAction(ACTION_RUN)
                    .putExtra(FajrAlarms.EXTRA_LIST_ID, listId)
                    .putExtra(FajrAlarms.EXTRA_FIRED_AT, firedAt),
            )
        }

        fun startNow(context: Context, listJson: String, stringsJson: String?) {
            ContextCompat.startForegroundService(
                context,
                Intent(context, FajrCallService::class.java)
                    .setAction(ACTION_RUN)
                    .putExtra(EXTRA_LIST_JSON, listJson)
                    .putExtra(EXTRA_STRINGS_JSON, stringsJson)
                    .putExtra(FajrAlarms.EXTRA_FIRED_AT, System.currentTimeMillis()),
            )
        }

        fun stop(context: Context) {
            context.startService(Intent(context, FajrCallService::class.java).setAction(ACTION_STOP))
        }
    }
}

/** Permission checks shared by the service and the channel. */
object FajrPermissions {
    fun has(context: Context, permission: String) =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun canAutoCall(context: Context) =
        has(context, Manifest.permission.CALL_PHONE) && has(context, Manifest.permission.READ_PHONE_STATE)

    /** This build declares READ_CALL_LOG (the `fajrCallLog` Gradle flag). */
    val callLogBuild get() = BuildConfig.FAJR_CALL_LOG

    fun callLogUsable(context: Context) =
        callLogBuild && has(context, Manifest.permission.READ_CALL_LOG)

    /** The runtime permissions the call loop asks for, in this build. */
    fun callPermissions(): Array<String> = buildList {
        add(Manifest.permission.CALL_PHONE)
        add(Manifest.permission.READ_PHONE_STATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) add(Manifest.permission.ANSWER_PHONE_CALLS)
        if (callLogBuild) add(Manifest.permission.READ_CALL_LOG)
    }.toTypedArray()
}
