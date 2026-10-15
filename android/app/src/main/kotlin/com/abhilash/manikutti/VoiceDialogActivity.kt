package com.abhilash.manikutti

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

class VoiceDialogActivity : FlutterActivity() {
    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }

    override fun getInitialRoute(): String {
        val data = intent?.data
        val query = data?.getQueryParameter("query") ?: ""
        return if (query.isNotEmpty()) {
            "/voice-dialog?query=" + Uri.encode(query)
        } else {
            "/voice-dialog"
        }
    }
}
