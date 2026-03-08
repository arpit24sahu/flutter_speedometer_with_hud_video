package com.arpit.speedometer.telemetry

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.util.Timer
import java.util.TimerTask
import kotlin.math.max

/**
 * Production-grade native telemetry handler for Android dashcam.
 *
 * Architecture:
 *   - Uses BOTH GPS_PROVIDER (for Doppler speed) and NETWORK_PROVIDER (for fast initial fix)
 *   - Seeds lat/lng from getLastKnownLocation() for instant display on launch
 *   - Kalman-filtered speed with IMU fusion for silky-smooth 30Hz updates
 *
 * Why dual providers:
 *   GPS_PROVIDER alone requires clear-sky satellite lock which can take 30+ seconds
 *   (or never arrive indoors). iOS CLLocationManager automatically fuses all sources,
 *   giving it an instant fix. We replicate this behavior by:
 *     1. Seeding from last known location immediately
 *     2. Accepting lat/lng from NETWORK_PROVIDER for quick initial fix
 *     3. Preferring GPS_PROVIDER updates when available (more accurate + Doppler speed)
 */
class NativeTelemetryHandler(private val context: Context) : EventChannel.StreamHandler, LocationListener, SensorEventListener {

    companion object {
        private const val TAG = "NativeTelemetry"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var locationManager: LocationManager? = null
    private var sensorManager: SensorManager? = null
    
    private var rotationSensor: Sensor? = null
    private var linearAccelSensor: Sensor? = null
    
    // Kalman Filter for speed (km/h)
    private val speedFilter = KalmanFilter1D(0.0, 5.0, 0.1, 2.0)
    
    private var currentLat: Double = 0.0
    private var currentLng: Double = 0.0
    private var currentCourse: Float = 0f
    private var lastGpsSpeedMs: Double = 0.0
    
    // Track whether we've received a real GPS fix for lat/lng
    private var hasGpsFix: Boolean = false
    
    private var lastPredictTimeMs: Long = 0
    private var broadcastTimer: Timer? = null
    
    private val rotationMatrix = FloatArray(16)
    private var currentLinearAccel = FloatArray(3)
    private var hasRotation = false

    // ─── Separate listener for NETWORK_PROVIDER ─────────────────
    // We need a separate listener because LocationManager requires
    // distinct listener instances for each provider.
    private val networkLocationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            // Only use network location for lat/lng if we don't have a GPS fix yet.
            // GPS fix is always more accurate — once we have one, network is redundant.
            if (!hasGpsFix) {
                currentLat = location.latitude
                currentLng = location.longitude
                Log.d(TAG, "Network location fix: lat=${location.latitude}, lng=${location.longitude}, accuracy=${location.accuracy}m")
            }
        }
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
        @Deprecated("Required for older APIs")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startTelemetry()
    }

    override fun onCancel(arguments: Any?) {
        stopTelemetry()
        eventSink = null
    }

    // ─── Lifecycle ──────────────────────────────────────────────

    private fun startTelemetry() {
        locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        
        rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rotationSensor == null) {
            rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        }
        linearAccelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        
        sensorManager?.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME)
        sensorManager?.registerListener(this, linearAccelSensor, SensorManager.SENSOR_DELAY_GAME)
        
        try {
            // Step 1: Seed from last known location for INSTANT display (no waiting)
            seedFromLastKnownLocation()
            
            // Step 2: Request GPS updates — primary source for speed (Doppler) + accurate position
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                1000L,
                0f,
                this,
                Looper.getMainLooper()
            )
            
            // Step 3: Also request NETWORK_PROVIDER for fast initial lat/lng fix.
            // Network location usually arrives within 1-2 seconds using cell/WiFi,
            // while GPS can take 30+ seconds for satellite lock.
            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    2000L,  // Slower interval — only needed until GPS locks
                    0f,
                    networkLocationListener,
                    Looper.getMainLooper()
                )
                Log.d(TAG, "Network provider registered for fast initial fix")
            }
            
            Log.d(TAG, "Location providers started (GPS + Network)")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
        }

        lastPredictTimeMs = System.currentTimeMillis()
        hasGpsFix = false
        
        broadcastTimer = Timer()
        // Run filter loop independently of GPS tick to provide silky smooth 30Hz updates to Flutter UI
        broadcastTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // All EventChannel responses must be dispatched on Main Thread
                android.os.Handler(Looper.getMainLooper()).post {
                    broadcastTelemetry()
                }
            }
        }, 0, 33)
    }

    /**
     * Seeds currentLat/currentLng from the device's last known location.
     *
     * This provides an instant non-zero lat/lng on the UI before any
     * provider delivers a fresh fix. Works even if the user was using
     * Maps or another GPS app recently.
     */
    private fun seedFromLastKnownLocation() {
        try {
            // Try GPS first (most accurate last-known)
            val lastGps = locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            if (lastGps != null) {
                currentLat = lastGps.latitude
                currentLng = lastGps.longitude
                Log.d(TAG, "Seeded from last GPS: lat=${lastGps.latitude}, lng=${lastGps.longitude}")
                return
            }
            
            // Fallback to network last-known
            val lastNetwork = locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (lastNetwork != null) {
                currentLat = lastNetwork.latitude
                currentLng = lastNetwork.longitude
                Log.d(TAG, "Seeded from last Network: lat=${lastNetwork.latitude}, lng=${lastNetwork.longitude}")
                return
            }
            
            // Fallback to passive provider (picks up locations from other apps)
            val lastPassive = locationManager?.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER)
            if (lastPassive != null) {
                currentLat = lastPassive.latitude
                currentLng = lastPassive.longitude
                Log.d(TAG, "Seeded from last Passive: lat=${lastPassive.latitude}, lng=${lastPassive.longitude}")
                return
            }
            
            Log.w(TAG, "No last known location available — waiting for provider fix")
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for last known location: ${e.message}")
        }
    }

    private fun stopTelemetry() {
        locationManager?.removeUpdates(this)
        locationManager?.removeUpdates(networkLocationListener)
        sensorManager?.unregisterListener(this)
        broadcastTimer?.cancel()
        broadcastTimer = null
    }

    // ─── GPS Provider Callbacks (primary — speed + position) ────

    override fun onLocationChanged(location: Location) {
        // ALWAYS accept lat/lng regardless of accuracy to prevent 0.00 showing on the UI
        currentLat = location.latitude
        currentLng = location.longitude
        
        // Mark that we now have a GPS fix — network listener can stop updating lat/lng
        if (!hasGpsFix) {
            hasGpsFix = true
            Log.d(TAG, "First GPS fix acquired: lat=${location.latitude}, lng=${location.longitude}, accuracy=${location.accuracy}m")
            
            // Unsubscribe network listener since GPS is now active
            try {
                locationManager?.removeUpdates(networkLocationListener)
                Log.d(TAG, "Network provider unsubscribed — GPS is primary")
            } catch (_: Exception) {}
        }

        // Reject wildly inaccurate points for speed and course (e.g., > 50 meters GPS drift)
        if (location.hasAccuracy() && location.accuracy > 50f) {
            return
        }
        
        if (location.hasBearing()) {
            currentCourse = location.bearing
        }

        val rawSpeedMs = if (location.hasSpeed()) location.speed.toDouble() else 0.0
        lastGpsSpeedMs = rawSpeedMs
        
        var rawSpeedKmh = rawSpeedMs * 3.6

        // Standstill Deadband: GPS drift often shows 0.3 - 0.7 m/s (1 - 2.5 km/h) when stopped
        // If speed is below ~3.0 km/h, snap to 0 to provide a solid standstill experience
        if (rawSpeedKmh < 3.0) {
            rawSpeedKmh = 0.0
        }

        // Quick snap for stopping: If GPS says we are solidly at 0, kill the filter momentum
        if (rawSpeedKmh == 0.0) {
            speedFilter.x = 0.0
        } else {
            speedFilter.update(rawSpeedKmh)
        }
    }
    
    // ─── IMU Fusion ─────────────────────────────────────────────

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            hasRotation = true
        } else if (event.sensor.type == Sensor.TYPE_LINEAR_ACCELERATION) {
            currentLinearAccel[0] = event.values[0]
            currentLinearAccel[1] = event.values[1]
            currentLinearAccel[2] = event.values[2]
            
            if (hasRotation) {
                processInertialData()
            }
        }
    }
    
    private fun processInertialData() {
        val now = System.currentTimeMillis()
        val dt = if (lastPredictTimeMs > 0) (now - lastPredictTimeMs) / 1000.0 else 0.02
        lastPredictTimeMs = now
        
        val ax = currentLinearAccel[0]
        val ay = currentLinearAccel[1]
        val az = currentLinearAccel[2]
        
        // Android rotationMatrix transforms from local phone frame to Earth frame:
        // X = East, Y = North, Z = Up
        // V_earth = R * V_local
        val ax_earth = rotationMatrix[0] * ax + rotationMatrix[1] * ay + rotationMatrix[2] * az
        val ay_earth = rotationMatrix[4] * ax + rotationMatrix[5] * ay + rotationMatrix[6] * az
        
        val courseRad = Math.toRadians(currentCourse.toDouble())
        val vx_dir = Math.sin(courseRad) // East
        val vy_dir = Math.cos(courseRad) // North
        
        var a_forward = ax_earth * vx_dir + ay_earth * vy_dir
        
        val accelMag = Math.sqrt((ax*ax + ay*ay + az*az).toDouble())
        if (lastGpsSpeedMs < 0.5 && accelMag < 0.6) {
            speedFilter.x = 0.0
            a_forward = 0.0
        }
        
        // Convert m/s^2 to km/h/s
        val a_forward_kmhs = a_forward * 3.6
        
        speedFilter.predict(a_forward_kmhs, dt)
        if (speedFilter.x < 0) speedFilter.x = 0.0
    }

    // ─── Required overrides for older Android APIs ──────────────
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Required for older APIs")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    // ─── Broadcast ──────────────────────────────────────────────

    private fun broadcastTelemetry() {
        val finalSpeed = max(0.0, speedFilter.x)
        val data = mapOf(
            "speedKmh" to finalSpeed,
            "lat" to currentLat,
            "lng" to currentLng
        )
        eventSink?.success(data)
    }
}
