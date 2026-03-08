package com.arpit.speedometer.telemetry

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.util.Log

/**
 * Queries Camera2 API to determine the exact back cameras available 
 * (both Logical and Physical) and returns their focal lengths.
 */
class NativeCameraCapabilities(private val context: Context) {

    companion object {
        private const val TAG = "CameraCapabilities"
    }

    /**
     * Returns a list of maps containing raw physical/logical lens data.
     * We do no guesswork here; all OOP logic is pushed to Dart for
     * cross-platform code sharing and robust fallback handling.
     */
    fun getBackCameraLenses(): List<Map<String, Any>> {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val result = mutableListOf<Map<String, Any>>()
        
        try {
            for (id in cameraManager.cameraIdList) {
                val chars = cameraManager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                
                if (facing != CameraCharacteristics.LENS_FACING_BACK) continue

                val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                if (focalLengths == null || focalLengths.isEmpty()) continue

                // 1. Add this logical camera
                result.add(mapOf(
                    "cameraId" to id,
                    "focalLength" to focalLengths[0].toDouble(),
                    "isLogical" to true
                ))
                
                // 2. Add its internal physical cameras (Android 9+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    for (pId in chars.physicalCameraIds) {
                        try {
                            val pChars = cameraManager.getCameraCharacteristics(pId)
                            val pFocal = pChars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                            if (pFocal != null && pFocal.isNotEmpty()) {
                                result.add(mapOf(
                                    "cameraId" to pId,
                                    "focalLength" to pFocal[0].toDouble(),
                                    "isLogical" to false,
                                    "logicalParentId" to id
                                ))
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to read physical camera $pId: ${e.message}")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Camera2 query failed: ${e.message}")
        }
        
        // Remove duplicates in case a physical camera is also exposed as a logical one
        return result.distinctBy { it["cameraId"] }
    }
}
