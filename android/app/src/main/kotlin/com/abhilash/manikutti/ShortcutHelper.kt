package com.abhilash.manikutti

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

object ShortcutHelper {
    private const val SHORTCUT_VOICE_ID = "voice_expense"
    private const val SHORTCUT_ADD_ID = "add_expense"

    fun publishShortcuts(context: Context) {
        try {
            // 1. Intent for Voice Expense Dialog (translucent overlay)
            val voiceIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://manikutti.vercel.app/voice-dialog")).apply {
                setPackage(context.packageName)
                setClass(context, VoiceDialogActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            // Voice Expense dynamic shortcut
            val voiceShortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_VOICE_ID)
                .setShortLabel(context.getString(R.string.shortcut_voice_short))
                .setLongLabel(context.getString(R.string.shortcut_voice_long))
                .setIcon(IconCompat.createWithResource(context, R.drawable.ic_tile_mic))
                .setIntent(voiceIntent)
                .setRank(1)
                .addCapabilityBinding(
                    "actions.intent.OPEN_APP_FEATURE",
                    "feature",
                    listOf("voice expense", "log expense", "record expense", "voice", "വോയ്സ് ചിലവ്", "വോയ്സ്")
                )
                .addCapabilityBinding("actions.intent.CREATE_ITEM", "item.name", listOf("expense", "transaction", "ചിലവ്"))
                .build()

            // 2. Intent for Add Expense (Main App)
            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://manikutti.vercel.app/add-transaction")).apply {
                setPackage(context.packageName)
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            // Add Expense dynamic shortcut
            val addShortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_ADD_ID)
                .setShortLabel(context.getString(R.string.shortcut_add_short))
                .setLongLabel(context.getString(R.string.shortcut_add_long))
                .setIcon(IconCompat.createWithResource(context, R.drawable.ic_widget_add))
                .setIntent(addIntent)
                .setRank(2)
                .addCapabilityBinding(
                    "actions.intent.OPEN_APP_FEATURE",
                    "feature",
                    listOf("add expense", "add transaction", "പുതിയ ചിലവ്")
                )
                .build()

            ShortcutManagerCompat.pushDynamicShortcut(context, voiceShortcut)
            ShortcutManagerCompat.pushDynamicShortcut(context, addShortcut)
            android.util.Log.i("ShortcutHelper", "Successfully published dynamic shortcuts to ShortcutManagerCompat")
        } catch (e: Exception) {
            android.util.Log.e("ShortcutHelper", "Failed to publish dynamic shortcuts", e)
        }
    }
}
