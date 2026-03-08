package com.arpit.speedometer

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.arpit.speedometer.telemetry.NativeTelemetryHandler
import com.arpit.speedometer.telemetry.NativeCameraCapabilities

class MainActivity : FlutterActivity() {

    private lateinit var telemetryHandler: NativeTelemetryHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ──────────────────────────────────────────────────────────────
        // Setup EventChannel for Native Telemetry
        // ──────────────────────────────────────────────────────────────
        telemetryHandler = NativeTelemetryHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mycompany.indiandriveguide/telemetry")
            .setStreamHandler(telemetryHandler)

        // ──────────────────────────────────────────────────────────────
        // Setup MethodChannel for System Monitor
        // ──────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mycompany.indiandriveguide/system_monitor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getThermalState" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val powerManager = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                            result.success(powerManager.currentThermalStatus)
                        } else {
                            result.success(0) // THERMAL_STATUS_NONE
                        }
                    }
                    "getFreeDiskSpace" -> {
                        val stat = android.os.StatFs(filesDir.absolutePath)
                        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
                        val freeGb = freeBytes.toDouble() / (1024.0 * 1024.0 * 1024.0)
                        result.success(freeGb)
                    }
                    else -> result.notImplemented()
                }
            }

        // ──────────────────────────────────────────────────────────────
        // Setup MethodChannel for Dashcam Foreground Service
        // ──────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mycompany.indiandriveguide/dashcam_service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        // val intent = Intent(this, DashcamForegroundService::class.java)
                        // intent.action = DashcamForegroundService.ACTION_START
                        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        //     startForegroundService(intent)
                        // } else {
                        //     startService(intent)
                        // }
                        result.success(true)
                    }
                    "stopService" -> {
                        // val intent = Intent(this, DashcamForegroundService::class.java)
                        // stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ──────────────────────────────────────────────────────────────
        // Setup MethodChannel for Camera Capabilities
        // ──────────────────────────────────────────────────────────────
        val cameraCapabilities = NativeCameraCapabilities(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mycompany.indiandriveguide/camera_capabilities")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBackCameraLenses" -> {
                        val lenses = cameraCapabilities.getBackCameraLenses()
                        result.success(lenses)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
