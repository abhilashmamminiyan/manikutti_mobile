package com.abhilash.manikutti

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ManikuttiHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val totalExpense = widgetData.getString("total_expense", "₹0") ?: "₹0"
                val pendingBill = widgetData.getString("pending_bill", "No pending bills") ?: "No pending bills"
                val monthName = widgetData.getString("month_name", "Manikutti • This Month") ?: "Manikutti • This Month"
                val hasAlert = widgetData.getBoolean("has_alert", false)

                setTextViewText(R.id.widget_total_expense, totalExpense)
                setTextViewText(R.id.widget_pending_bill, pendingBill)
                setTextViewText(R.id.widget_month_name, monthName)

                // Launch Intent on Mic Click -> Option B: Floating popup on home screen without opening main app
                val voiceIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val voiceIntent = PendingIntent.getActivity(
                    context,
                    100, // Explicit request code to avoid collision with main app intents
                    Intent(context, VoiceDialogActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("manikutti://voice-dialog")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    voiceIntentFlags
                )
                setOnClickPendingIntent(R.id.widget_btn_mic, voiceIntent)

                // Launch Intent on Plus Click -> deep link manikutti://add-transaction
                val addIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("manikutti://add-transaction")
                )
                setOnClickPendingIntent(R.id.widget_btn_add, addIntent)

                // Launch app on clicking card body
                val openIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("manikutti://dashboard")
                )
                setOnClickPendingIntent(R.id.widget_container, openIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
