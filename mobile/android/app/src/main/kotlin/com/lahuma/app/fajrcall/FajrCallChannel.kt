package com.lahuma.app.fajrcall

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.telecom.TelecomManager
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * `lahuma/fajr_call`: Flutter ↔ the Android call engine. See
 * `lib/features/fajr_call/data/fajr_call_platform.dart` for the Dart side.
 */
class FajrCallChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, NAME)
    private val context: Context get() = activity.applicationContext
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** A route from a native notification, until Flutter asks for it. */
    var launchRoute: String? = null

    init {
        channel.setMethodCallHandler(this)
        current = this
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (current === this) current = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "sync" -> {
                FajrStore(context).saveConfig(call.argument<String>("config") ?: "{}")
                FajrAlarms.rescheduleAll(context)
                result.success(null)
            }
            "runNow" -> {
                if (!FajrPermissions.canAutoCall(context)) return result.success(false)
                val list = call.argument<String>("list") ?: return result.success(false)
                val strings = call.argument<Map<String, String>>("strings")
                    ?.let { JSONObject(it as Map<*, *>).toString() }
                try {
                    FajrCallService.startNow(context, list, strings)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            "stop" -> {
                FajrCallService.stop(context)
                result.success(null)
            }
            "takeSessions" -> result.success(FajrStore(context).takeSessions())
            "permissions" -> result.success(permissions())
            "requestCallPermissions" -> requestCallPermissions(result)
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations()
                result.success(null)
            }
            "openAppSettings" -> {
                open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri()))
                result.success(null)
            }
            "phoneAccounts" -> result.success(phoneAccounts())
            "takeLaunchRoute" -> {
                result.success(launchRoute)
                launchRoute = null
            }
            else -> result.notImplemented()
        }
    }

    private fun isSupported(): Boolean {
        val pm = context.packageManager
        val calling = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_CALLING)
        } else {
            pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        }
        return calling && context.getSystemService(Context.TELECOM_SERVICE) != null
    }

    private fun permissions(): Map<String, Boolean> {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "callPhone" to FajrPermissions.has(context, Manifest.permission.CALL_PHONE),
            "phoneState" to FajrPermissions.has(context, Manifest.permission.READ_PHONE_STATE),
            "answerCalls" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                FajrPermissions.has(context, Manifest.permission.ANSWER_PHONE_CALLS)),
            "callLog" to FajrPermissions.callLogUsable(context),
            "callLogAvailable" to FajrPermissions.callLogBuild,
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(context.packageName),
        )
    }

    private fun requestCallPermissions(result: MethodChannel.Result) {
        val missing = FajrPermissions.callPermissions()
            .filterNot { FajrPermissions.has(context, it) }
        if (missing.isEmpty()) return result.success(permissions())
        pendingPermissionResult?.success(permissions())
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), REQUEST_CODE)
    }

    /** Forwarded from MainActivity. Returns true when it was ours. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermissionResult?.success(permissions())
        pendingPermissionResult = null
        // The engine may now run lists that were falling back to manual.
        FajrAlarms.rescheduleAll(context)
        return true
    }

    @SuppressLint("BatteryLife") // core to the feature: calls at 4 a.m. in Doze
    private fun requestIgnoreBatteryOptimizations() {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri())
        if (!open(direct)) open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    @SuppressLint("MissingPermission")
    private fun phoneAccounts(): List<Map<String, String>> {
        if (!FajrPermissions.has(context, Manifest.permission.READ_PHONE_STATE)) return emptyList()
        val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            ?: return emptyList()
        return try {
            telecom.callCapablePhoneAccounts.map { handle ->
                val label = telecom.getPhoneAccount(handle)?.label?.toString() ?: handle.id
                mapOf(
                    "id" to "${handle.componentName.flattenToString()}|${handle.id}",
                    "label" to label,
                )
            }
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    private fun packageUri() = Uri.parse("package:${context.packageName}")

    private fun open(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    /** Asks Flutter to open [route] (a notification was tapped). */
    fun openRoute(route: String) = channel.invokeMethod("openRoute", route)

    companion object {
        const val NAME = "lahuma/fajr_call"
        private const val REQUEST_CODE = 0x7a1
        private var current: FajrCallChannel? = null

        /** Tells a running Flutter UI that new results are waiting. */
        fun notifySessionsChanged() {
            Handler(Looper.getMainLooper()).post {
                current?.channel?.invokeMethod("sessionsChanged", null)
            }
        }
    }
}
