package com.lahuma.app.adhan

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Runs the Dart reschedule (`adhanBackgroundMain` in `lib/main.dart`) in a
 * headless Flutter engine: no activity, no UI. Prayer times and the plan
 * live in Dart, so this is how a reboot, a timezone change or a quiet week
 * (the app never opened) still gets a fresh week of adhans.
 */
class AdhanWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val done = CountDownLatch(1)
        val main = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        var channel: AdhanAlarmChannel? = null
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                // Registers the pub plugins (prefs, notifications, timezone).
                val e = FlutterEngine(applicationContext)
                channel = AdhanAlarmChannel(applicationContext, e.dartExecutor.binaryMessenger) {
                    done.countDown()
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                )
                engine = e
            } catch (t: Throwable) {
                Log.w(TAG, "Background engine failed: $t")
                done.countDown()
            }
        }
        val finished = done.await(TIMEOUT_S, TimeUnit.SECONDS)
        main.post {
            channel?.dispose()
            engine?.destroy()
        }
        if (!finished) Log.w(TAG, "Background reschedule timed out")
        return if (finished) Result.success() else Result.retry()
    }

    private companion object {
        const val TAG = "Adhan"
        const val ENTRYPOINT = "adhanBackgroundMain"
        const val TIMEOUT_S = 90L
    }
}

object AdhanWork {
    private const val DAILY = "adhan_daily_reschedule"
    private const val NOW = "adhan_reschedule_now"

    /** The daily safety net; kept as is when already scheduled. */
    fun ensureDaily(context: Context) {
        val request = PeriodicWorkRequestBuilder<AdhanWorker>(1, TimeUnit.DAYS).build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(DAILY, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    /** One reschedule as soon as WorkManager allows (after a boot, etc.). */
    fun runNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<AdhanWorker>().build()
        WorkManager.getInstance(context).enqueueUniqueWork(NOW, ExistingWorkPolicy.REPLACE, request)
    }
}
