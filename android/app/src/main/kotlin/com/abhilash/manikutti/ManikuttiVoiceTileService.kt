package com.abhilash.manikutti

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.TileService

class ManikuttiVoiceTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent = Intent(this, VoiceDialogActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("manikutti://voice-dialog")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14+
            val pendingIntent = PendingIntent.getActivity(
                this,
                101,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            unlockAndRun {
                startActivityAndCollapse(intent)
            }
        }
    }
}
