package com.lahuma.app

import android.content.Intent
import com.lahuma.app.fajrcall.FajrCallChannel
import com.lahuma.app.fajrcall.FajrNotify
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var fajrCall: FajrCallChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fajrCall = FajrCallChannel(this, flutterEngine.dartExecutor.binaryMessenger).also {
            // Launched from a Fajr Call notification: Flutter asks for it.
            it.launchRoute = intent?.getStringExtra(FajrNotify.EXTRA_ROUTE)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        fajrCall?.dispose()
        fajrCall = null
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
