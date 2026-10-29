package com.abhilash.manikutti

import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class ManikuttiQuickLogWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_DIGIT = "com.abhilash.manikutti.ACTION_KEYPAD_DIGIT"
        const val EXTRA_DIGIT = "extra_digit"

        const val ACTION_PRESET = "com.abhilash.manikutti.ACTION_KEYPAD_PRESET"
        const val EXTRA_AMOUNT = "extra_amount"

        const val ACTION_BACKSPACE = "com.abhilash.manikutti.ACTION_KEYPAD_BACKSPACE"
        const val ACTION_CLEAR = "com.abhilash.manikutti.ACTION_KEYPAD_CLEAR"

        const val ACTION_CATEGORY = "com.abhilash.manikutti.ACTION_SET_CATEGORY"
        const val EXTRA_CATEGORY = "extra_category"

        const val ACTION_CYCLE_CATEGORY = "com.abhilash.manikutti.ACTION_CYCLE_CATEGORY"
        const val ACTION_SAVE = "com.abhilash.manikutti.ACTION_SAVE_EXPENSE"

        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_AMOUNT = "quick_log_amount"
        private const val KEY_CATEGORY = "quick_log_category"
        private const val KEY_CYCLE_INDEX = "quick_log_cycle_index"
        private const val KEY_STATUS = "quick_log_status"
        private const val KEY_STATUS_TIME = "quick_log_status_time"

        private val DEFAULT_CATEGORIES = listOf("Food", "Fuel", "Shopping", "Housing", "Transport", "Health", "Other")

        fun getWidgetPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return

        when (action) {
            ACTION_DIGIT -> {
                val digit = intent.getStringExtra(EXTRA_DIGIT) ?: return
                handleDigit(context, digit)
            }
            ACTION_PRESET -> {
                val presetAmount = intent.getIntExtra(EXTRA_AMOUNT, 0)
                handlePreset(context, presetAmount)
            }
            ACTION_BACKSPACE -> handleBackspace(context)
            ACTION_CLEAR -> handleClear(context)
            ACTION_CATEGORY -> {
                val category = intent.getStringExtra(EXTRA_CATEGORY) ?: "Food"
                handleCategory(context, category)
            }
            ACTION_CYCLE_CATEGORY -> handleCycleCategory(context)
            ACTION_SAVE -> handleSave(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val views = buildRemoteViews(context, widgetData)
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun handleDigit(context: Context, digit: String) {
        val prefs = getWidgetPrefs(context)
        var current = prefs.getString(KEY_AMOUNT, "0") ?: "0"

        if (current == "0") {
            current = if (digit == "00") "0" else digit
        } else if (current.length < 8) {
            current += digit
        }

        prefs.edit()
            .putString(KEY_AMOUNT, current)
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handlePreset(context: Context, preset: Int) {
        val prefs = getWidgetPrefs(context)
        val current = prefs.getString(KEY_AMOUNT, "0")?.toIntOrNull() ?: 0
        val next = current + preset

        prefs.edit()
            .putString(KEY_AMOUNT, next.toString())
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handleBackspace(context: Context) {
        val prefs = getWidgetPrefs(context)
        val current = prefs.getString(KEY_AMOUNT, "0") ?: "0"
        val next = if (current.length > 1) {
            current.substring(0, current.length - 1)
        } else {
            "0"
        }

        prefs.edit()
            .putString(KEY_AMOUNT, next)
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handleClear(context: Context) {
        val prefs = getWidgetPrefs(context)
        prefs.edit()
            .putString(KEY_AMOUNT, "0")
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handleCategory(context: Context, category: String) {
        val prefs = getWidgetPrefs(context)
        prefs.edit()
            .putString(KEY_CATEGORY, category)
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handleCycleCategory(context: Context) {
        val prefs = getWidgetPrefs(context)
        val categories = getAvailableCategories(context)
        val currentIndex = prefs.getInt(KEY_CYCLE_INDEX, 0)
        val nextIndex = (currentIndex + 1) % categories.size
        val nextCategory = categories[nextIndex]

        prefs.edit()
            .putInt(KEY_CYCLE_INDEX, nextIndex)
            .putString(KEY_CATEGORY, nextCategory)
            .remove(KEY_STATUS)
            .apply()

        updateAllQuickLogWidgets(context)
    }

    private fun handleSave(context: Context) {
        val prefs = getWidgetPrefs(context)
        val amountStr = prefs.getString(KEY_AMOUNT, "0") ?: "0"
        val amount = amountStr.toDoubleOrNull() ?: 0.0

        if (amount <= 0.0) {
            prefs.edit()
                .putString(KEY_STATUS, "⚠️ Enter an amount first")
                .putLong(KEY_STATUS_TIME, System.currentTimeMillis())
                .apply()
            updateAllQuickLogWidgets(context)
            return
        }

        val category = prefs.getString(KEY_CATEGORY, "Food") ?: "Food"

        // 1. Get user details from FlutterSharedPreferences
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val userEmail = flutterPrefs.getString("flutter.user_email", null) ?: "Self"
        val familyCode = flutterPrefs.getString("flutter.family_code", null)
        val bankAccount = flutterPrefs.getString("flutter.selected_bank_account", "SBI") ?: "SBI"

        // 2. Generate ISO UTC Timestamp adhering strictly to architectural contract
        val utcIsoTimestamp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Instant.now().toString()
        } else {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            sdf.format(Date())
        }

        // 3. Save directly to SQLite database 'manikutti.db'
        var dbInserted = false
        try {
            val dbPath = context.getDatabasePath("manikutti.db")
            if (dbPath.exists()) {
                val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
                val values = ContentValues().apply {
                    put("date", utcIsoTimestamp)
                    put("amount", amount)
                    put("category", category)
                    put("note", "Home widget quick log")
                    put("isPaid", 1)
                    put("type", "Expense")
                    put("addedBy", userEmail)
                    put("familyCode", familyCode)
                    put("synced", 0)
                    put("bankAccount", bankAccount)
                }
                val rowId = db.insert("transactions", null, values)
                db.close()
                dbInserted = rowId > 0
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val formatter = NumberFormat.getNumberInstance(Locale("en", "IN"))
        val formattedAmount = formatter.format(amount.toInt())

        // 4. Trigger Instant System Notification as explicitly requested
        sendConfirmationNotification(context, formattedAmount, category)

        // 5. Update SQLite Month Total and sync to SharedPreferences for all widgets
        updateMonthTotal(context)

        // 6. Reset widget amount and set success status
        prefs.edit()
            .putString(KEY_AMOUNT, "0")
            .putString(KEY_STATUS, "Saved ₹$formattedAmount for $category ✓")
            .putLong(KEY_STATUS_TIME, System.currentTimeMillis())
            .apply()

        // 7. Update both widgets on home screen
        updateAllQuickLogWidgets(context)
        updateSummaryWidget(context)
    }

    private fun sendConfirmationNotification(context: Context, amountFormatted: String, category: String) {
        try {
            NotificationChannelHelper.createChannels(context)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("manikutti://dashboard")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(context, 301, openIntent, pendingFlags)

            val notification = NotificationCompat.Builder(context, NotificationChannelHelper.VOICE_EXPENSE_CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle("Manikutti: Expense Saved")
                .setContentText("Saved ₹$amountFormatted for $category (Home Widget)")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setColor(0xFF0F766E.toInt())
                .setVibrate(longArrayOf(0, 200, 100, 200))
                .build()

            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateMonthTotal(context: Context) {
        try {
            val dbPath = context.getDatabasePath("manikutti.db")
            if (!dbPath.exists()) return

            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val cal = Calendar.getInstance()
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH) + 1
            val monthPrefix = String.format(Locale.US, "%04d-%02d", year, month)

            val cursor = db.rawQuery(
                "SELECT SUM(amount) FROM transactions WHERE (LOWER(type) = 'expense' OR LOWER(type) = 'family') AND date LIKE ?",
                arrayOf("$monthPrefix%")
            )

            var monthTotal = 0.0
            if (cursor.moveToFirst()) {
                monthTotal = cursor.getDouble(0)
            }
            cursor.close()
            db.close()

            val formatter = NumberFormat.getNumberInstance(Locale("en", "IN"))
            val formattedTotal = "₹" + formatter.format(monthTotal.toInt())

            val prefs = getWidgetPrefs(context)
            prefs.edit().putString("total_expense", formattedTotal).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getAvailableCategories(context: Context): List<String> {
        val prefs = getWidgetPrefs(context)
        val raw = prefs.getString("widget_categories", null)
        if (!raw.isNullOrEmpty()) {
            val list = raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            if (list.isNotEmpty()) return list
        }
        return DEFAULT_CATEGORIES
    }

    private fun buildRemoteViews(context: Context, widgetData: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.quick_log_widget_layout)

        val amount = widgetData.getString(KEY_AMOUNT, "0") ?: "0"
        val selectedCategory = widgetData.getString(KEY_CATEGORY, "Food") ?: "Food"
        val monthTotal = widgetData.getString("total_expense", "₹0") ?: "₹0"
        val status = widgetData.getString(KEY_STATUS, null)
        val statusTime = widgetData.getLong(KEY_STATUS_TIME, 0L)

        // 1. Text displays
        views.setTextViewText(R.id.quick_log_display, "₹ $amount")
        views.setTextViewText(R.id.quick_log_active_category, selectedCategory)
        views.setTextViewText(R.id.quick_log_month_total, "Month: $monthTotal")

        // Show status message if it was set within the last 15 seconds
        if (!status.isNullOrEmpty() && (System.currentTimeMillis() - statusTime < 15000)) {
            views.setTextViewText(R.id.quick_log_status, status)
            views.setViewVisibility(R.id.quick_log_status, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.quick_log_status, View.GONE)
        }

        val categories = getAvailableCategories(context)
        val cat1 = categories.getOrNull(0) ?: "Food"
        val cat2 = categories.getOrNull(1) ?: "Fuel"
        val cat3 = categories.getOrNull(2) ?: "Shop"

        views.setTextViewText(R.id.btn_cat_1, cat1)
        views.setTextViewText(R.id.btn_cat_2, cat2)
        views.setTextViewText(R.id.btn_cat_3, cat3)

        // Category backgrounds based on selection
        views.setInt(
            R.id.btn_cat_1,
            "setBackgroundResource",
            if (selectedCategory == cat1) R.drawable.widget_cat_chip_active_bg else R.drawable.widget_cat_chip_bg
        )
        views.setInt(
            R.id.btn_cat_2,
            "setBackgroundResource",
            if (selectedCategory == cat2) R.drawable.widget_cat_chip_active_bg else R.drawable.widget_cat_chip_bg
        )
        views.setInt(
            R.id.btn_cat_3,
            "setBackgroundResource",
            if (selectedCategory == cat3) R.drawable.widget_cat_chip_active_bg else R.drawable.widget_cat_chip_bg
        )

        // Category click intents
        views.setOnClickPendingIntent(R.id.btn_cat_1, createCategoryIntent(context, cat1, 201))
        views.setOnClickPendingIntent(R.id.btn_cat_2, createCategoryIntent(context, cat2, 202))
        views.setOnClickPendingIntent(R.id.btn_cat_3, createCategoryIntent(context, cat3, 203))
        views.setOnClickPendingIntent(R.id.btn_cat_more, createBroadcastIntent(context, ACTION_CYCLE_CATEGORY, 204))

        // Digit click intents (1-9, 0)
        views.setOnClickPendingIntent(R.id.btn_key_1, createDigitIntent(context, "1", 101))
        views.setOnClickPendingIntent(R.id.btn_key_2, createDigitIntent(context, "2", 102))
        views.setOnClickPendingIntent(R.id.btn_key_3, createDigitIntent(context, "3", 103))
        views.setOnClickPendingIntent(R.id.btn_key_4, createDigitIntent(context, "4", 104))
        views.setOnClickPendingIntent(R.id.btn_key_5, createDigitIntent(context, "5", 105))
        views.setOnClickPendingIntent(R.id.btn_key_6, createDigitIntent(context, "6", 106))
        views.setOnClickPendingIntent(R.id.btn_key_7, createDigitIntent(context, "7", 107))
        views.setOnClickPendingIntent(R.id.btn_key_8, createDigitIntent(context, "8", 108))
        views.setOnClickPendingIntent(R.id.btn_key_9, createDigitIntent(context, "9", 109))
        views.setOnClickPendingIntent(R.id.btn_key_0, createDigitIntent(context, "0", 110))

        // Action presets
        views.setOnClickPendingIntent(R.id.btn_key_p50, createPresetIntent(context, 50, 120))
        views.setOnClickPendingIntent(R.id.btn_key_p100, createPresetIntent(context, 100, 121))
        views.setOnClickPendingIntent(R.id.btn_key_p500, createPresetIntent(context, 500, 122))

        // Backspace, Clear, Save
        views.setOnClickPendingIntent(R.id.btn_key_backspace, createBroadcastIntent(context, ACTION_BACKSPACE, 130))
        views.setOnClickPendingIntent(R.id.btn_key_clear, createBroadcastIntent(context, ACTION_CLEAR, 131))
        views.setOnClickPendingIntent(R.id.btn_key_save, createBroadcastIntent(context, ACTION_SAVE, 132))

        // Open App on title click
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("manikutti://dashboard")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            context,
            140,
            openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.quick_log_title, openPending)

        return views
    }

    private fun createDigitIntent(context: Context, digit: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, ManikuttiQuickLogWidgetProvider::class.java).apply {
            action = ACTION_DIGIT
            putExtra(EXTRA_DIGIT, digit)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun createPresetIntent(context: Context, amount: Int, requestCode: Int): PendingIntent {
        val intent = Intent(context, ManikuttiQuickLogWidgetProvider::class.java).apply {
            action = ACTION_PRESET
            putExtra(EXTRA_AMOUNT, amount)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun createCategoryIntent(context: Context, category: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, ManikuttiQuickLogWidgetProvider::class.java).apply {
            action = ACTION_CATEGORY
            putExtra(EXTRA_CATEGORY, category)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun createBroadcastIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, ManikuttiQuickLogWidgetProvider::class.java).apply {
            this.action = action
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun updateAllQuickLogWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, ManikuttiQuickLogWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(componentName)
        if (ids.isNotEmpty()) {
            val views = buildRemoteViews(context, getWidgetPrefs(context))
            appWidgetManager.updateAppWidget(ids, views)
        }
    }

    private fun updateSummaryWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, ManikuttiHomeWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(componentName)
        if (ids.isNotEmpty()) {
            val intent = Intent(context, ManikuttiHomeWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
