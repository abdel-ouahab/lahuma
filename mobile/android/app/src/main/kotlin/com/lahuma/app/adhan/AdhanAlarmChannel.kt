package com.lahuma.app.adhan

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `lahuma/adhan_alarm`: Flutter ↔ the adhan alarm engine. Registered on
 * the app's engine (MainActivity) and on [AdhanWorker]'s headless one,
 * which passes [onDone]. Dart side:
 * `lib/features/adhan/data/adhan_alarm_platform.dart`.
 */
class AdhanAlarmChannel(
    context: Context,
    messenger: BinaryMessenger,
    private val onDone: (() -> Unit)? = null,
) : MethodChannel.MethodCallHandler {

    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)

    /**
     * Read before Dart runs, so before its launch sync re-arms anything.
     * The headless engine doesn't ask: a force-stopped app gets no work.
     */
    private var cleared = onDone == null && AdhanAlarms.wereCleared(this.context)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() = channel.setMethodCallHandler(null)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sync" -> {
                val store = AdhanAlarmStore(context)
                store.strings = AdhanStrings.fromMap(call.argument<Map<*, *>>("strings"))
                store.slots = call.argument<List<Map<*, *>>>("alarms").orEmpty()
                    .map { AdhanAlarmSlot.fromMap(it) }
                AdhanAlarms.rescheduleAll(context)
                result.success(true)
            }
            "test" -> {
                val slot = call.argument<Map<*, *>>("alarm")?.let { AdhanAlarmSlot.fromMap(it) }
                    ?: return result.success(false)
                val store = AdhanAlarmStore(context)
                store.strings = AdhanStrings.fromMap(call.argument<Map<*, *>>("strings"))
                store.tests = store.tests.filter { it.id != slot.id } + slot
                AdhanAlarms.rescheduleAll(context)
                result.success(true)
            }
            "stop" -> {
                AdhanPlaybackService.stop(context)
                result.success(null)
            }
            "takeCleared" -> {
                result.success(cleared)
                cleared = false
            }
            "ensureDaily" -> {
                AdhanWork.ensureDaily(context)
                result.success(null)
            }
            "reliability" -> result.success(
                mapOf(
                    "exactAlarms" to AdhanAlarms.canScheduleExact(context),
                    "ignoringBatteryOptimizations" to ignoringBatteryOptimizations(),
                    "manufacturer" to Build.MANUFACTURER,
                    "sdk" to Build.VERSION.SDK_INT,
                ),
            )
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations()
                result.success(null)
            }
            "openMakerSettings" -> result.success(openMakerSettings(call.argument<String>("maker") ?: ""))
            "openAppSettings" -> {
                open(appDetails())
                result.success(null)
            }
            "done" -> {
                result.success(null)
                onDone?.invoke()
            }
            else -> result.notImplemented()
        }
    }

    private fun ignoringBatteryOptimizations(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    @SuppressLint("BatteryLife") // the adhan must play on time in Doze
    private fun requestIgnoreBatteryOptimizations() {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri())
        if (!open(direct)) open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    /**
     * The maker's autostart / background page. These screens are private
     * and move between OS versions, so each is only tried, in order; when
     * none opens, the app's own settings page is shown (returns false).
     */
    private fun openMakerSettings(maker: String): Boolean {
        val candidates = when (maker) {
            "xiaomi" -> listOf(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
                ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"),
            )
            "oppo" -> listOf(
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            )
            "huawei" -> listOf(
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            )
            "samsung" -> listOf(
                ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
                ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            )
            else -> emptyList()
        }
        for (c in candidates) {
            val intent = Intent().setComponent(c)
            if (maker == "xiaomi" && c.className.endsWith("HiddenAppsConfigActivity")) {
                intent.putExtra("package_name", context.packageName)
                    .putExtra("package_label", context.applicationInfo.loadLabel(context.packageManager))
            }
            if (open(intent)) return true
        }
        open(appDetails())
        return false
    }

    private fun appDetails() = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri())

    private fun packageUri() = Uri.parse("package:${context.packageName}")

    private fun open(intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: SecurityException) {
        // A component that exists but isn't exported to us.
        Log.i("Adhan", "Not allowed to open ${intent.component}: $e")
        false
    }

    companion object {
        const val NAME = "lahuma/adhan_alarm"
    }
}
