package com.abhilash.manikutti

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
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

                // Launch Intent on Mic Click -> Option B: Floating popup on home screen
                val voiceIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    VoiceDialogActivity::class.java,
                    Uri.parse("manikutti://voice-dialog")
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
