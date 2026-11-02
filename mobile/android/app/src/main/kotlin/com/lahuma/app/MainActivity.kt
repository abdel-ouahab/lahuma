package com.lahuma.app

import android.content.Intent
import com.lahuma.app.adhan.AdhanSoundChannel
import com.lahuma.app.fajrcall.FajrCallChannel
import com.lahuma.app.fajrcall.FajrNotify
import com.lahuma.app.qibla.QiblaChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var fajrCall: FajrCallChannel? = null
    private var adhanSound: AdhanSoundChannel? = null
    private var qibla: QiblaChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fajrCall = FajrCallChannel(this, flutterEngine.dartExecutor.binaryMessenger).also {
            // Launched from a Fajr Call notification: Flutter asks for it.
            it.launchRoute = intent?.getStringExtra(FajrNotify.EXTRA_ROUTE)
        }
        adhanSound = AdhanSoundChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        qibla = QiblaChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        fajrCall?.dispose()
        fajrCall = null
        adhanSound?.dispose()
        adhanSound = null
        qibla?.dispose()
        qibla = null
        super.cleanUpFlutterEngine(flutterEngine)
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
