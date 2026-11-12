package com.lahuma.app

import android.content.Intent
import android.os.Bundle
import com.lahuma.app.adhan.AdhanAlarmChannel
import com.lahuma.app.adhan.AdhanRecents
import com.lahuma.app.adhan.AdhanSoundChannel
import com.lahuma.app.fajrcall.FajrCallChannel
import com.lahuma.app.fajrcall.FajrNotify
import com.lahuma.app.qibla.QiblaChannel
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// AudioServiceActivity keeps one cached Flutter engine shared with the
// recitation media session (lock screen / notification controls).
class MainActivity : AudioServiceActivity() {
    private var fajrCall: FajrCallChannel? = null
    private var adhanSound: AdhanSoundChannel? = null
    private var adhanAlarm: AdhanAlarmChannel? = null
    private var qibla: QiblaChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fajrCall = FajrCallChannel(this, flutterEngine.dartExecutor.binaryMessenger).also {
            // Launched from a Fajr Call notification: Flutter asks for it.
            it.launchRoute = intent?.getStringExtra(FajrNotify.EXTRA_ROUTE)
        }
        adhanSound = AdhanSoundChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        adhanAlarm = AdhanAlarmChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        qibla = QiblaChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        fajrCall?.dispose()
        fajrCall = null
        adhanSound?.dispose()
        adhanSound = null
        adhanAlarm?.dispose()
        adhanAlarm = null
        qibla?.dispose()
        qibla = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The "hide from Recents" choice belongs to the task: set it on
        // each new one.
        AdhanRecents.apply(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(FajrNotify.EXTRA_ROUTE)?.let { fajrCall?.openRoute(it) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        fajrCall?.onRequestPermissionsResult(requestCode)
    }
}
