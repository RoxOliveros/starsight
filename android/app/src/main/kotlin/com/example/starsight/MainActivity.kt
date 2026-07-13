package com.example.starsight

import com.example.starsight.gesture.GestureViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val eventChannelName = "com.example.starsight/gesture_events"
    private val viewTypeId = "com.example.starsight/gesture_camera_view"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Stream of gesture results going to Dart
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // Register the native camera+gesture view so Flutter can embed it
        flutterEngine.platformViewsController.registry.registerViewFactory(
            viewTypeId,
            GestureViewFactory(
                lifecycleOwner = this,
                eventSink = { eventSink }
            )
        )
    }
}