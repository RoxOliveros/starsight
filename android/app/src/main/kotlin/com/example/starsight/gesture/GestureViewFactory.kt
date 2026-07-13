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
        return GestureRecognizerView(context, lifecycleOwner, eventSink())
    }
}