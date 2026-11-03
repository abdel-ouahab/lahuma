package com.lahuma.app.adhan

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.lahuma.app.R
import java.io.File

/**
 * Plays the full adhan in the foreground (type `mediaPlayback`) on the
 * alarm stream (`USAGE_ALARM`: alarm volume, heard in silent mode), with an
 * ongoing notification that carries Stop. Started by [AdhanAlarmReceiver]
 * from an exact alarm, so it works with the app killed and in Doze.
 *
 * Stops on Stop, a swipe of the notification, the end of the recording,
 * a playback error, losing audio focus (an incoming call), or after
 * [MAX_MS] whatever happens.
 */
class AdhanPlaybackService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val stopAfter = Runnable { finish() }

    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private val onFocus = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            finish()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val slot = AdhanAlarmSlot.fromIntent(intent)
                if (slot == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                // First, within the 5 s Android allows after the start.
                val strings = AdhanAlarmStore(this).strings
                ServiceCompat.startForeground(
                    this, AdhanNotify.PLAYING_ID,
                    AdhanNotify.playing(this, slot, strings, stopIntent(this)),
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    } else 0,
                )
                play(slot.file)
            }
            ACTION_STOP -> finish()
            else -> stopSelf()
        }
        // Killed by the system: don't replay an adhan later.
        return START_NOT_STICKY
    }

    private fun play(file: String?) {
        release()
        val mp = MediaPlayer()
        player = mp
        try {
            mp.setAudioAttributes(attributes)
            mp.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            if (file != null && File(file).canRead()) {
                mp.setDataSource(file)
            } else {
                resources.openRawResourceFd(R.raw.adhan_default_regular).use {
                    mp.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            }
            mp.setOnPreparedListener {
                // Refused during a phone call: don't play over it.
                if (requestFocus()) it.start() else finish()
            }
            mp.setOnCompletionListener { finish() }
            mp.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "Playback error $what/$extra")
                // A broken download still has the bundled adhan behind it.
                if (file != null) handler.post { play(null) } else finish()
                true
            }
            mp.prepareAsync()
            handler.removeCallbacks(stopAfter)
            handler.postDelayed(stopAfter, MAX_MS)
        } catch (e: Exception) {
            Log.w(TAG, "Could not play the adhan: $e")
            if (file != null) play(null) else finish()
        }
    }

    private fun requestFocus(): Boolean {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(onFocus, handler)
                .build()
            focus = request
            am.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(onFocus, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
        return granted != AudioManager.AUDIOFOCUS_REQUEST_FAILED
    }

    private fun abandonFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(onFocus)
        }
        focus = null
    }

    private fun release() {
        player?.let {
            runCatching { it.stop() }
            it.release()
        }
        player = null
    }

    private fun finish() {
        handler.removeCallbacks(stopAfter)
        release()
        abandonFocus()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopAfter)
        release()
        abandonFocus()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "Adhan"
        const val ACTION_PLAY = "com.lahuma.app.adhan.PLAY"
        const val ACTION_STOP = "com.lahuma.app.adhan.STOP"

        /** Longer than any adhan; a stuck player still stops. */
        private const val MAX_MS = 10L * 60 * 1000

        /**
         * Throws `ForegroundServiceStartNotAllowedException` (Android 12+)
         * when the app has no exemption, e.g. from an inexact alarm.
         */
        fun start(context: Context, slot: AdhanAlarmSlot) {
            val intent = slot.putInto(Intent(context, AdhanPlaybackService::class.java).setAction(ACTION_PLAY))
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AdhanPlaybackService::class.java))
        }

        fun stopIntent(context: Context): PendingIntent = PendingIntent.getService(
            context, 0,
            Intent(context, AdhanPlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
