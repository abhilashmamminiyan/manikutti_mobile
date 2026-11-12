package com.abhilash.manikutti

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val SETTINGS_CHANNEL = "com.abhilash.manikutti/settings"
    private val SHARE_CHANNEL = "com.abhilash.manikutti/share"
    private val SMS_CHANNEL = "com.abhilash.manikutti/sms"
    private val SMS_PERMISSION_REQUEST_CODE = 9201

    private var shareChannel: MethodChannel? = null
    private var pendingSmsPermissionResult: MethodChannel.Result? = null
    private var pendingSharedImagePath: String? = null
    private var pendingDeepLinkUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent, notifyLiveChannel = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent, notifyLiveChannel = true)
    }

    private fun handleShareIntent(intent: Intent?, notifyLiveChannel: Boolean) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type
        if (Intent.ACTION_VIEW == action && intent.data != null) {
            val uriStr = intent.data.toString()
            if (notifyLiveChannel && shareChannel != null) {
                shareChannel?.invokeMethod("onDeepLink", uriStr)
            } else {
                pendingDeepLinkUri = uriStr
            }
            return
        }
        if (Intent.ACTION_SEND == action && type != null && type.startsWith("image/")) {
            val imageUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            if (imageUri != null) {
                val copiedPath = copyUriToCache(imageUri)
                if (copiedPath != null) {
                    if (notifyLiveChannel && shareChannel != null) {
                        shareChannel?.invokeMethod("onSharedImage", copiedPath)
                    } else {
                        pendingSharedImagePath = copiedPath
                    }
                    // Clear action so configuration changes don't re-trigger
                    intent.action = ""
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val dir = File(cacheDir, "shared_receipts")
            if (!dir.exists()) dir.mkdirs()
            val target = File(dir, "share_${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun shareImageViaAndroid(filePath: String, caption: String?, whatsappOnly: Boolean): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false

        val contentUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )

        val baseIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, contentUri)
            if (!caption.isNullOrBlank()) {
                putExtra(Intent.EXTRA_TEXT, caption)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (whatsappOnly) {
            val candidates = listOf("com.whatsapp", "com.whatsapp.w4b")
            for (pkg in candidates) {
                if (packageManager.getLaunchIntentForPackage(pkg) != null) {
                    val waIntent = Intent(baseIntent).apply {
                        setPackage(pkg)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        startActivity(waIntent)
                        return true
                    } catch (_: Exception) {}
                }
            }
        }

        val chooser = Intent.createChooser(baseIntent, "Forward payment screenshot").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(chooser)
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure all system notification channels exist natively in Android OS
        NotificationChannelHelper.createChannels(this)

        // Publish dynamic shortcuts for Android OS and Google Assistant
        ShortcutHelper.publishShortcuts(this)

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
                "publishShortcuts" -> {
                    ShortcutHelper.publishShortcuts(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedImage" -> {
                        val path = pendingSharedImagePath
                        pendingSharedImagePath = null
                        result.success(path)
                    }
                    "getInitialDeepLink" -> {
                        val uriStr = pendingDeepLinkUri
                        pendingDeepLinkUri = null
                        result.success(uriStr)
                    }
                    "shareImage" -> {
                        val path = call.argument<String>("path")
                        val caption = call.argument<String>("caption")
                        val whatsappOnly = call.argument<Boolean>("whatsappOnly") ?: false
                        if (path.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            try {
                                result.success(shareImageViaAndroid(path, caption, whatsappOnly))
                            } catch (e: Exception) {
                                result.error("SHARE_ERROR", e.localizedMessage, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(hasReceive && hasRead)
                }
                "requestSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    if (hasReceive && hasRead) {
                        result.success(true)
                    } else {
                        pendingSmsPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                            SMS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "scanRecentSms" -> {
                    val hours = call.argument<Int>("hours") ?: 48
                    val added = scanInboxRecentSms(hours)
                    result.success(added)
                }
                "getPendingSms" -> {
                    val list = SmsParserHelper.getPendingTransactions(this)
                    val arr = JSONArray()
                    list.forEach { arr.put(it.toJson()) }
                    result.success(arr.toString())
                }
                "confirmPendingSms" -> {
                    val id = call.argument<String>("id")
                    if (id.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        val logged = SmsParserHelper.confirmPendingToPersonal(this, id)
                        result.success(logged?.toJson()?.toString())
                    }
                }
                "dismissPendingSms" -> {
                    val id = call.argument<String>("id")
                    if (!id.isNullOrBlank()) {
                        SmsParserHelper.removePendingById(this, id)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingSmsPermissionResult?.success(granted)
            pendingSmsPermissionResult = null
        }
    }

    private fun scanInboxRecentSms(hours: Int): Int {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return 0
        }
        var count = 0
        val cutoff = System.currentTimeMillis() - hours * 3600L * 1000L
        try {
            val cursor = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                "${Telephony.Sms.DATE} >= ?",
                arrayOf(cutoff.toString()),
                "${Telephony.Sms.DATE} DESC"
            )
            cursor?.use {
                val addrIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)
                var checked = 0
                while (it.moveToNext() && checked < 40) {
                    checked++
                    val sender = if (addrIdx >= 0) (it.getString(addrIdx) ?: "BANK") else "BANK"
                    val body = if (bodyIdx >= 0) (it.getString(bodyIdx) ?: "") else ""
                    val ts = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                    val parsed = SmsParserHelper.parseSms(this, sender, body, ts)
                    if (parsed != null) {
                        val autoEmi = SmsParserHelper.autoLogIfExactEmi(this, parsed)
                        if (autoEmi != null) {
                            SmsParserHelper.showLoggedNotification(this, autoEmi, autoEmi = true)
                            count++
                        } else if (SmsParserHelper.enqueuePendingTransaction(this, parsed)) {
                            count++
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return count
    }
}
