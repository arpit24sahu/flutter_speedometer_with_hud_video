package com.arpit.speedometer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent

import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class DashcamForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    
    companion object {
        private const val CHANNEL_ID = "dashcam_recording_channel"
        private const val NOTIFICATION_ID = 1001
        
        const val ACTION_START = "START_DASHCAM_SERVICE"
        const val ACTION_STOP = "STOP_DASHCAM_SERVICE"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopForegroundService()
        }
        return START_STICKY
    }

    private fun startForegroundService() {
//        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("Dashcam Recording")
//            .setContentText("Recording in progress...")
//            .setSmallIcon(android.R.drawable.ic_menu_camera)
//            .setOngoing(true)
//            .build()
//
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
//            var type = 0
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
//                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
//                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
//            } else {
//                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
//            }
//            try {
//                startForeground(NOTIFICATION_ID, notification, type)
//            } catch (e: Exception) {
//                try {
//                    startForeground(NOTIFICATION_ID, notification)
//                } catch (e2: Exception) {
//                    android.util.Log.e("DashcamService", "Failed to start foreground internally fallback", e2)
//                }
//            }
//        } else {
//            try {
//                startForeground(NOTIFICATION_ID, notification)
//            } catch (e: Exception) {
//                android.util.Log.e("DashcamService", "Failed to start foreground totally", e)
//            }
//        }
    }

    private fun stopForegroundService() {
        releaseWakeLock()
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
//            stopForeground(STOP_FOREGROUND_REMOVE)
//        } else {
//            @Suppress("DEPRECATION")
//            stopForeground(true)
//        }
        stopSelf()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DashcamForegroundService::WakeLock").apply {
            acquire(30 * 60 * 1000L) // 30 minutes max timeout instead of 4 hours
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Dashcam Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows ongoing notification while dashcam is recording"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
