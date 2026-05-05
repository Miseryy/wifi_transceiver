package com.example.wifi_transceiver

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "wifi_transceiver/power"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireSleepLocks" -> {
                        startIntercomService()
                        result.success(null)
                    }
                    "releaseSleepLocks" -> {
                        stopIntercomService()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startIntercomService() {
        val intent = Intent(this, IntercomForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopIntercomService() {
        stopService(Intent(this, IntercomForegroundService::class.java))
    }
}
