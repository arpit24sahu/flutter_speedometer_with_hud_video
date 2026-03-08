package com.arpit.speedometer.telemetry

class KalmanFilter1D(
    var x: Double,
    var p: Double,
    var q: Double,
    var r: Double
) {
    fun predict(u: Double, dt: Double) {
        x += (u * dt)
        p += q
    }

    fun update(measurement: Double) {
        val k = p / (p + r)
        x += k * (measurement - x)
        p = (1 - k) * p
    }
}
