package com.lahuma.app.qibla

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `lahuma/qibla`: what the Qibla compass needs beyond flutter_compass.
 *
 * - `hasCompass`: whether the phone has a magnetometer at all, so Flutter
 *   can say so instead of waiting for readings that never come.
 * - `declination`: magnetic declination (degrees, east positive) at a place
 *   from the World Magnetic Model. flutter_compass reports magnetic north on
 *   Android; adding this gives true north, which the Qibla bearing uses.
 *
 * Dart side: `lib/features/qibla/data/compass_source.dart`.
 */
class QiblaChannel(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() = channel.setMethodCallHandler(null)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCompass" -> {
                val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                result.success(sensors?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null)
            }
            "declination" -> {
                val lat = call.argument<Double>("latitude")
                val lon = call.argument<Double>("longitude")
                if (lat == null || lon == null) return result.success(0.0)
                val field = GeomagneticField(
                    lat.toFloat(), lon.toFloat(), 0f, System.currentTimeMillis(),
                )
                result.success(field.declination.toDouble())
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "lahuma/qibla"
    }
}
