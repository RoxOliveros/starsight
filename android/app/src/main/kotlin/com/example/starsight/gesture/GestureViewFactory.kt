package com.example.starsight.gesture

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class GestureViewFactory(
    private val lifecycleOwner: LifecycleOwner,
    private val eventSink: () -> EventChannel.EventSink?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // args comes from Dart's creationParams via StandardMessageCodec, so
        // ints decode as Int (or Long on some platforms) — guard both, and
        // fall back to 1 hand (today's default behavior for every existing
        // screen like thumbs up/down) if it's missing or malformed.
        val requiredHands = when (val raw = (args as? Map<*, *>)?.get("requiredHands")) {
            is Int -> raw
            is Long -> raw.toInt()
            else -> 1
        }.coerceIn(1, 2) // MediaPipe GestureRecognizer only supports 1 or 2 hands

        return GestureRecognizerView(context, lifecycleOwner, eventSink(), requiredHands)
    }
}