package com.abhilash.manikutti

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object NotificationChannelHelper {
    const val VOICE_EXPENSE_CHANNEL_ID = "voice_expense_channel_v2"
    const val PAYMENT_CHANNEL_ID = "payment_channel"
    const val SALARY_CHANNEL_ID = "salary_channel"
    const val DUES_CHANNEL_ID = "dues_channel"
    const val RECHARGE_CHANNEL_ID = "recharge_channel"

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return

            val voiceChannel = NotificationChannel(
                VOICE_EXPENSE_CHANNEL_ID,
                "Voice & Widget Expenses",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Instant confirmation alerts for expenses and income logged via voice or widget"
                enableVibration(true)
                setShowBadge(true)
            }

            val paymentChannel = NotificationChannel(
                PAYMENT_CHANNEL_ID,
                "Payment Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when someone pays a family commitment"
                enableVibration(true)
            }

            val salaryChannel = NotificationChannel(
                SALARY_CHANNEL_ID,
                "Salary Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Prompts on 4th & 5th of each month for recording salary"
                enableVibration(true)
            }

            val duesChannel = NotificationChannel(
                DUES_CHANNEL_ID,
                "Due Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders for regular family dues"
                enableVibration(true)
            }

            val rechargeChannel = NotificationChannel(
                RECHARGE_CHANNEL_ID,
                "Recharge Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders before mobile recharge expiry"
                enableVibration(true)
            }

            // Clean up legacy v1 channel if present
            try {
                manager.deleteNotificationChannel("voice_expense_channel")
            } catch (_: Exception) {}

            manager.createNotificationChannels(
                listOf(voiceChannel, paymentChannel, salaryChannel, duesChannel, rechargeChannel)
            )
        }
    }
}
