package com.abhilash.manikutti

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import java.text.NumberFormat
import java.util.Locale

class SmsTransactionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return
        if (!SmsParserHelper.isDetectionEnabled(context)) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val grouped = linkedMapOf<String, StringBuilder>()
        var timestampMs = System.currentTimeMillis()
        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: "BANK"
            val body = sms.displayMessageBody ?: ""
            timestampMs = sms.timestampMillis.takeIf { it > 0 } ?: timestampMs
            grouped.getOrPut(sender) { StringBuilder() }.append(body)
        }

        for ((sender, bodyBuilder) in grouped) {
            val parsed = SmsParserHelper.parseSms(context, sender, bodyBuilder.toString(), timestampMs)
            if (parsed != null) {
                val autoEmi = SmsParserHelper.autoLogIfExactEmi(context, parsed)
                if (autoEmi != null) {
                    SmsParserHelper.showLoggedNotification(context, autoEmi, autoEmi = true)
                } else {
                    val enqueued = SmsParserHelper.enqueuePendingTransaction(context, parsed)
                    if (enqueued) {
                        showSmsDetectionNotification(context, parsed)
                    }
                }
            }
        }
    }

    private fun showSmsDetectionNotification(context: Context, tx: ParsedSmsTransaction) {
        try {
            NotificationChannelHelper.createChannels(context)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val fmt = NumberFormat.getNumberInstance(Locale("en", "IN"))
            val amtText = "₹${fmt.format(tx.amount.toInt())}"

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val reqBase = (tx.id.hashCode() and 0x7FFF) + 4000

            val yesIntent = Intent(context, SmsWidgetActionReceiver::class.java).apply {
                action = SmsWidgetActionReceiver.ACTION_CONFIRM_LOG
                putExtra(SmsWidgetActionReceiver.EXTRA_SMS_ID, tx.id)
                putExtra(SmsWidgetActionReceiver.EXTRA_NOTIF_ID, reqBase)
            }
            val yesPending = PendingIntent.getBroadcast(context, reqBase + 1, yesIntent, flags)

            val noIntent = Intent(context, SmsWidgetActionReceiver::class.java).apply {
                action = SmsWidgetActionReceiver.ACTION_DISMISS
                putExtra(SmsWidgetActionReceiver.EXTRA_SMS_ID, tx.id)
                putExtra(SmsWidgetActionReceiver.EXTRA_NOTIF_ID, reqBase)
            }
            val noPending = PendingIntent.getBroadcast(context, reqBase + 2, noIntent, flags)

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("manikutti://dashboard")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val openPending = PendingIntent.getActivity(context, reqBase + 3, openAppIntent, flags)

            val balSuffix = if (tx.availableBalance != null) {
                " • Avl Bal ₹${fmt.format(tx.availableBalance.toInt())}"
            } else ""

            val title = if (tx.isEmi) {
                "EMI Payment Detected: $amtText"
            } else {
                "Transaction Detected: $amtText"
            }

            val body = if (tx.isEmi) {
                "${tx.merchant}$balSuffix. Log & confirm this month's EMI?"
            } else {
                "${tx.type} at ${tx.merchant} (${tx.bankAccount})$balSuffix. Want to log to Personal?"
            }

            val notification = NotificationCompat.Builder(context, NotificationChannelHelper.SMS_EXPENSE_CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(openPending)
                .addAction(0, "Yes, Log", yesPending)
                .addAction(0, "Dismiss", noPending)
                .setColor(0xFF006972.toInt())
                .build()

            manager.notify(reqBase, notification)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
