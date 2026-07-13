package com.example.starsight.gesture

import android.content.Context
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult
import com.google.mediapipe.framework.image.BitmapImageBuilder
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.Executors

/**
 * Native Android view that owns the camera feed and runs MediaPipe's Gesture
 * Recognizer on each frame. Results are pushed to Flutter via the EventChannel
 * sink registered from MainActivity.
 */
class GestureRecognizerView(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private var eventSink: EventChannel.EventSink?
) : PlatformView {

    private val previewView = PreviewView(context)
    private var gestureRecognizer: GestureRecognizer? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    companion object {
        private const val TAG = "GestureRecognizerView"
        private const val MODEL_ASSET_PATH = "gesture_recognizer.task"
    }

    init {
        setupGestureRecognizer()
        setupCamera()
    }

    private fun setupGestureRecognizer() {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(MODEL_ASSET_PATH)
                .build()

            val options = GestureRecognizer.GestureRecognizerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(1)
                .setMinHandDetectionConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setResultListener(::onGestureResult)
                .setErrorListener { error ->
                    Log.e(TAG, "Gesture recognizer error: ${error.message}")
                }
                .build()

            gestureRecognizer = GestureRecognizer.createFromOptions(context, options)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize GestureRecognizer", e)
        }
    }

    private fun setupCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = androidx.camera.core.Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(analysisExecutor) { imageProxy ->
                        processFrame(imageProxy)
                    }
                }

            val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )
            } catch (e: Exception) {
                Log.e(TAG, "Camera binding failed", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun processFrame(imageProxy: ImageProxy) {
        try {
            val bitmap = imageProxy.toBitmap() // requires androidx.camera:camera-core 1.3+
            val mpImage = BitmapImageBuilder(bitmap).build()
            val timestampMs = System.currentTimeMillis()
            gestureRecognizer?.recognizeAsync(mpImage, timestampMs)
        } catch (e: Exception) {
            Log.e(TAG, "Frame processing failed", e)
        } finally {
            imageProxy.close()
        }
    }

    private fun onGestureResult(result: GestureRecognizerResult, input: com.google.mediapipe.framework.image.MPImage) {
        val gestures = result.gestures()
        if (gestures.isEmpty() || gestures[0].isEmpty()) return

        val topGesture = gestures[0][0] // highest-confidence gesture for the first hand
        val payload = mapOf(
            "gesture" to topGesture.categoryName(),
            "confidence" to topGesture.score(),
            "timestampMs" to System.currentTimeMillis()
        )

        // EventChannel sinks must be called on the main thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }

    override fun getView() = previewView

    override fun dispose() {
        gestureRecognizer?.close()
        analysisExecutor.shutdown()
    }
}