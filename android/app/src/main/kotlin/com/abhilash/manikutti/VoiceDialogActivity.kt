package com.abhilash.manikutti

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class VoiceDialogActivity : FlutterActivity() {
    private val SETTINGS_CHANNEL = "com.abhilash.manikutti/settings"
    private val VOICE_DIALOG_CHANNEL = "com.abhilash.manikutti/voice_dialog"

    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }

    override fun getDartEntrypointFunctionName(): String {
        return "voiceDialogMain"
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = intent.data
        val query = data?.getQueryParameter("query") ?: ""
        flutterEngine?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, VOICE_DIALOG_CHANNEL)
                .invokeMethod("onNewQuery", query)
        }
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure all system notification channels exist natively in Android OS
        NotificationChannelHelper.createChannels(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
