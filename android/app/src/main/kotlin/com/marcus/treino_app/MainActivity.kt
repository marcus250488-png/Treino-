package com.marcus.treino_app

import android.content.Intent
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meutreino/tela")
            .setMethodCallHandler { call, result ->
                if (call.method == "manterTela") {
                    val ligar = call.arguments as? Boolean ?: false
                    if (ligar) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meutreino/sono")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "iniciar" -> {
                        val i = Intent(this, SonoSensorService::class.java).setAction(SonoSensorService.ACTION_START)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(SonoSensorService.status(this))
                    }
                    "parar" -> {
                        startService(Intent(this, SonoSensorService::class.java).setAction(SonoSensorService.ACTION_STOP))
                        result.success(SonoSensorService.status(this))
                    }
                    "status" -> result.success(SonoSensorService.status(this))
                    else -> result.notImplemented()
                }
            }
    }
}
