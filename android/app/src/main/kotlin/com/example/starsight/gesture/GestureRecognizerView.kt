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
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.framework.image.BitmapImageBuilder
import kotlin.math.hypot
import kotlin.math.min
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
    private var eventSink: EventChannel.EventSink?,
    private val requiredHands: Int = 1
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
                .setNumHands(requiredHands)
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
            // CRITICAL: camera frames arrive in raw sensor orientation, not
            // "however the screen is currently rotated." Without telling
            // MediaPipe the actual rotation, the landmark y-coordinates it
            // returns don't correspond to real-world up/down — which silently
            // breaks any geometry check that assumes "up" means "toward the
            // top of the screen" (like our fingersUp check in isPrayingPose).
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val bitmap = imageProxy.toBitmap() // requires androidx.camera:camera-core 1.3+
            val mpImage = BitmapImageBuilder(bitmap).build()
            val timestampMs = System.currentTimeMillis()
            val processingOptions = ImageProcessingOptions.builder()
                .setRotationDegrees(rotationDegrees)
                .build()
            gestureRecognizer?.recognizeAsync(mpImage, processingOptions, timestampMs)
        } catch (e: Exception) {
            Log.e(TAG, "Frame processing failed", e)
        } finally {
            imageProxy.close()
        }
    }

    // MediaPipe Hand Landmarker indices we care about.
    // Full 21-point map: https://ai.google.dev/mediapipe/solutions/vision/hand_landmarker
    private object Lm {
        const val WRIST = 0
        const val INDEX_MCP = 5
        const val MIDDLE_MCP = 9
        const val PINKY_MCP = 17
        const val INDEX_TIP = 8
        const val MIDDLE_TIP = 12
        const val RING_TIP = 16
        const val PINKY_TIP = 20
    }

    // Tuned thresholds for "praying hands": palms close together, roughly level,
    // fingers pointing upward. These are ratios relative to hand size (palm width),
    // NOT raw pixel/normalized distances, so they hold up across distance-from-camera.
    // Expect to tune these against real footage of kids' hands/arm lengths.
    private object PrayThresholds {
        const val MAX_PALM_GAP_RATIO = 1.3f      // palm-center distance / avg hand width
        const val MAX_HEIGHT_DELTA_RATIO = 0.8f  // vertical offset between palms / avg hand width
    }

    private fun dist(a: NormalizedLandmark, b: NormalizedLandmark): Float =
        hypot((a.x() - b.x()).toDouble(), (a.y() - b.y()).toDouble()).toFloat()

    /** Average y of the four fingertips (excludes thumb, which points sideways when praying). */
    private fun avgFingertipY(hand: List<NormalizedLandmark>): Float =
        (hand[Lm.INDEX_TIP].y() + hand[Lm.MIDDLE_TIP].y() + hand[Lm.RING_TIP].y() + hand[Lm.PINKY_TIP].y()) / 4f

    /**
     * Custom geometric check for praying hands. The stock MediaPipe Gesture
     * Recognizer has no "praying" category — it only classifies ONE hand at a
     * time into 7 fixed buckets (Open_Palm, Closed_Fist, Thumb_Up, etc). So
     * instead of trusting a label, we look directly at both hands' landmarks:
     * palms close together, roughly level with each other, fingers pointing up.
     */
    private fun isPrayingPose(allLandmarks: List<List<NormalizedLandmark>>): Boolean {
        if (allLandmarks.size < 2) {
            Log.d(TAG, "PrayCheck only ${allLandmarks.size} hand(s) detected, need 2")
            return false // need both hands in frame
        }

        val handA = allLandmarks[0]
        val handB = allLandmarks[1]

        val palmA = handA[Lm.MIDDLE_MCP]
        val palmB = handB[Lm.MIDDLE_MCP]

        val widthA = dist(handA[Lm.INDEX_MCP], handA[Lm.PINKY_MCP])
        val widthB = dist(handB[Lm.INDEX_MCP], handB[Lm.PINKY_MCP])
        val avgWidth = (widthA + widthB) / 2f
        if (avgWidth <= 0f) return false // degenerate landmarks, bail out

        val palmGap = dist(palmA, palmB)
        val heightDelta = kotlin.math.abs(palmA.y() - palmB.y())

        val palmsTogether = palmGap < avgWidth * PrayThresholds.MAX_PALM_GAP_RATIO
        val roughlyLevel = heightDelta < avgWidth * PrayThresholds.MAX_HEIGHT_DELTA_RATIO
        val fingersUpA = avgFingertipY(handA) < handA[Lm.WRIST].y()
        val fingersUpB = avgFingertipY(handB) < handB[Lm.WRIST].y()

        // Temporary diagnostic logging — filter logcat on "PrayCheck" to see
        // the real ratios your camera/hands are producing. Once praying
        // reliably triggers, feel free to delete this block (or gate it
        // behind BuildConfig.DEBUG).
        Log.d(
            TAG,
            "PrayCheck gapRatio=${"%.2f".format(palmGap / avgWidth)} " +
                "(need < ${PrayThresholds.MAX_PALM_GAP_RATIO}) " +
                "heightRatio=${"%.2f".format(heightDelta / avgWidth)} " +
                "(need < ${PrayThresholds.MAX_HEIGHT_DELTA_RATIO}) " +
                "fingersUpA=$fingersUpA fingersUpB=$fingersUpB " +
                "-> together=$palmsTogether level=$roughlyLevel"
        )

        return palmsTogether && roughlyLevel && fingersUpA && fingersUpB
    }

    private fun onGestureResult(result: GestureRecognizerResult, input: com.google.mediapipe.framework.image.MPImage) {
        val gestures = result.gestures()
        val landmarks = result.landmarks()
        if (gestures.isEmpty()) return

        val payload: Map<String, Any> = if (isPrayingPose(landmarks)) {
            // Confidence isn't meaningful for a hand-crafted pose check the same
            // way it is for a model's softmax score, so we report a fixed high
            // value here — the geometry check itself is the "confidence" gate.
            mapOf(
                "gesture" to "Praying",
                "confidence" to 0.95,
                "timestampMs" to System.currentTimeMillis()
            )
        } else {
            // Fall back to the classifier's own top label for single-hand
            // gestures (Thumb_Up, Thumb_Down, etc.) using whichever hand it
            // is most confident about.
            val best = gestures
                .filter { it.isNotEmpty() }
                .map { it[0] }
                .maxByOrNull { it.score() }

            if (best == null) return

            mapOf(
                "gesture" to best.categoryName(),
                "confidence" to best.score(),
                "timestampMs" to System.currentTimeMillis()
            )
        }

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