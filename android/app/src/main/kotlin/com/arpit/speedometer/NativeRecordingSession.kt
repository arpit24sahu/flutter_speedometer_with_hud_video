package com.mycompany.indiandriveguide

import android.graphics.*
import android.media.*
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileWriter

class NativeRecordingSession(
    private val width: Int,
    private val height: Int,
    private val outputPath: String
) {
    private val TAG = "NativeRecordingSession"

    private var mediaCodec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var mediaMuxer: MediaMuxer? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var isRecording = false

    private val bufferInfo = MediaCodec.BufferInfo()

    private var encodingThread: HandlerThread? = null
    private var encodingHandler: Handler? = null

    // Metadata tracking
    private var metadataArray = JSONArray()
    private var metadataFile: File? = null

    fun start() {
        Log.i(TAG, "Starting NativeRecordingSession to $outputPath")
        metadataArray = JSONArray()
        metadataFile = File(outputPath.replace(".mp4", ".json"))
        
        startEncodingThread()
        prepareEncoder()
        isRecording = true
    }

    private fun prepareEncoder() {
        try {
            var actualWidth = width
            var actualHeight = height
            
            // Ensure even dimensions for stricter codecs
            if (actualWidth % 2 != 0) actualWidth -= 1
            if (actualHeight % 2 != 0) actualHeight -= 1

            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, actualWidth, actualHeight).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, 5000000) // 5 Mbps
                setInteger(MediaFormat.KEY_FRAME_RATE, 30)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }

            mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            mediaCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = mediaCodec?.createInputSurface()
            mediaCodec?.start()

            mediaMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            trackIndex = -1
            muxerStarted = false
        } catch (e: Exception) {
            Log.e(TAG, "Exception preparing encoder, trying fallback...", e)
            try {
                // FALLBACK: Moderate 2 Mbps, 24 FPS and ensuring even dimensions
                var fbWidth = width
                var fbHeight = height
                if (fbWidth % 2 != 0) fbWidth -= 1
                if (fbHeight % 2 != 0) fbHeight -= 1
                
                val fallbackFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, fbWidth, fbHeight).apply {
                    setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                    setInteger(MediaFormat.KEY_BIT_RATE, 2000000) // 2 Mbps
                    setInteger(MediaFormat.KEY_FRAME_RATE, 24)
                    setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
                }
                
                mediaCodec?.release()
                mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                mediaCodec?.configure(fallbackFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                inputSurface = mediaCodec?.createInputSurface()
                mediaCodec?.start()

                mediaMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                trackIndex = -1
                muxerStarted = false
            } catch (fallbackE: Exception) {
                Log.e(TAG, "Fallback encoder preparation also failed", fallbackE)
            }
        }
    }

    fun processFrame(bitmap: Bitmap, speed: Double, lat: Double, lng: Double, timestampNs: Long) {
        if (!isRecording || inputSurface == null) return

        encodingHandler?.post {
            try {
                // Drain any pending encoded data
                drainEncoder(false)

                // Lock canvas, draw the camera bitmap (No text burning)
                val canvas = inputSurface?.lockCanvas(null)
                if (canvas != null) {
                    canvas.drawBitmap(bitmap, 0f, 0f, null)
                    inputSurface?.unlockCanvasAndPost(canvas)
                }
                
                // Track metadata for this frame
                val frameMeta = JSONObject().apply {
                    put("timestampNs", timestampNs)
                    put("speed", speed)
                    put("lat", lat)
                    put("lng", lng)
                }
                metadataArray.put(frameMeta)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing frame to MediaCodec", e)
            }
        }
    }

    fun stop() {
        Log.i(TAG, "Stopping NativeRecordingSession")
        isRecording = false
        
        // Save metadata synchronously before tearing down
        try {
            metadataFile?.let { file ->
                FileWriter(file).use { writer ->
                    writer.write(metadataArray.toString())
                }
                Log.i(TAG, "Saved metadata to ${file.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving metadata", e)
        }
        
        encodingHandler?.post {
            drainEncoder(true)
            releaseEncoder()
            stopEncodingThread()
        }
    }

    private fun drainEncoder(endOfStream: Boolean) {
        val codec = mediaCodec ?: return

        if (endOfStream) {
            try {
                codec.signalEndOfInputStream()
            } catch (e: Exception) {
                Log.e(TAG, "Error signaling end of stream", e)
            }
        }

        while (true) {
            val encoderStatus = codec.dequeueOutputBuffer(bufferInfo, 10000)
            if (encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER) {
                // No output available yet
                if (!endOfStream) {
                    break // out of while
                } else {
                    Log.d(TAG, "no output available, spinning to await EOS")
                }
            } else if (encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (muxerStarted) {
                    throw RuntimeException("format changed twice")
                }
                val newFormat = codec.outputFormat
                trackIndex = mediaMuxer!!.addTrack(newFormat)
                mediaMuxer!!.start()
                muxerStarted = true
            } else if (encoderStatus < 0) {
                Log.w(TAG, "unexpected result from encoder.dequeueOutputBuffer: \$encoderStatus")
            } else {
                val encodedData = codec.getOutputBuffer(encoderStatus)
                    ?: throw RuntimeException("encoderOutputBuffer \$encoderStatus was null")

                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                    // Config data, ignore
                    bufferInfo.size = 0
                }

                if (bufferInfo.size != 0) {
                    if (!muxerStarted) {
                        throw RuntimeException("muxer hasn't started")
                    }
                    encodedData.position(bufferInfo.offset)
                    encodedData.limit(bufferInfo.offset + bufferInfo.size)
                    mediaMuxer!!.writeSampleData(trackIndex, encodedData, bufferInfo)
                }

                codec.releaseOutputBuffer(encoderStatus, false)

                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    if (!endOfStream) {
                        Log.w(TAG, "reached end of stream unexpectedly")
                    } else {
                        Log.d(TAG, "end of stream reached")
                    }
                    break // out of while
                }
            }
        }
    }

    private fun releaseEncoder() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing mediaCodec", e)
        }
        
        try {
            inputSurface?.release()
            inputSurface = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing inputSurface", e)
        }

        try {
            if (muxerStarted) {
                mediaMuxer?.stop()
            }
            mediaMuxer?.release()
            mediaMuxer = null
            muxerStarted = false
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing mediaMuxer", e)
        }
    }

    private fun startEncodingThread() {
        encodingThread = HandlerThread("NativeEncoder").also { it.start() }
        encodingHandler = Handler(encodingThread!!.looper)
    }

    private fun stopEncodingThread() {
        encodingThread?.quitSafely()
        try {
            encodingThread?.join()
            encodingThread = null
            encodingHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping encoding thread", e)
        }
    }
}
