package com.abhilash.manikutti

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsWidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_CONFIRM_LOG = "com.abhilash.manikutti.ACTION_SMS_CONFIRM_LOG"
        const val ACTION_DISMISS = "com.abhilash.manikutti.ACTION_SMS_DISMISS"
        const val EXTRA_SMS_ID = "extra_sms_id"
        const val EXTRA_NOTIF_ID = "extra_notif_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val smsId = intent.getStringExtra(EXTRA_SMS_ID) ?: return
        val notifId = intent.getIntExtra(EXTRA_NOTIF_ID, -1)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (notifId > 0) {
            manager.cancel(notifId)
        } else {
            val fallbackId = (smsId.hashCode() and 0x7FFF) + 4000
            manager.cancel(fallbackId)
        }

        when (intent.action) {
            ACTION_CONFIRM_LOG -> {
                val logged = SmsParserHelper.confirmPendingToPersonal(context, smsId)
                if (logged != null) {
                    SmsParserHelper.showLoggedNotification(context, logged, autoEmi = false)
                }
            }
            ACTION_DISMISS -> {
                SmsParserHelper.removePendingById(context, smsId)
            }
        }
    }
}
