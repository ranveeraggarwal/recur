package com.ranveeraggarwal.recur

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recur/calendar_intent")
            .setMethodCallHandler { call, result ->
                if (call.method != "insertEvent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI).apply {
                    putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, call.argument<Number>("beginMillis")!!.toLong())
                    putExtra(CalendarContract.EXTRA_EVENT_END_TIME, call.argument<Number>("endMillis")!!.toLong())
                    putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                    call.argument<String>("location")?.let {
                        putExtra(CalendarContract.Events.EVENT_LOCATION, it)
                    }
                    call.argument<String>("description")?.let {
                        putExtra(CalendarContract.Events.DESCRIPTION, it)
                    }
                }
                try {
                    startActivity(intent)
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("no_calendar_app", "No app can add a calendar event.", null)
                }
            }
    }
}
