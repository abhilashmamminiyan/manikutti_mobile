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
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

data class ParsedSmsTransaction(
    val id: String,
    val amount: Double,
    val type: String,
    val category: String,
    val merchant: String,
    val bankAccount: String,
    val availableBalance: Double?,
    val isEmi: Boolean,
    val rawBody: String,
    val timestampMs: Long
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("amount", amount)
            put("type", type)
            put("category", category)
            put("merchant", merchant)
            put("bankAccount", bankAccount)
            if (availableBalance != null) {
                put("availableBalance", availableBalance)
            } else {
                put("availableBalance", JSONObject.NULL)
            }
            put("isEmi", isEmi)
            put("rawBody", rawBody)
            put("timestampMs", timestampMs)
        }
    }

    companion object {
        fun fromJson(obj: JSONObject): ParsedSmsTransaction {
            val balVal = if (obj.isNull("availableBalance")) null else obj.optDouble("availableBalance", Double.NaN)
            return ParsedSmsTransaction(
                id = obj.optString("id", ""),
                amount = obj.optDouble("amount", 0.0),
                type = obj.optString("type", "Expense"),
                category = obj.optString("category", "Other"),
                merchant = obj.optString("merchant", "Bank Transaction"),
                bankAccount = obj.optString("bankAccount", "SBI"),
                availableBalance = if (balVal != null && !balVal.isNaN()) balVal else null,
                isEmi = obj.optBoolean("isEmi", false),
                rawBody = obj.optString("rawBody", ""),
                timestampMs = obj.optLong("timestampMs", System.currentTimeMillis())
            )
        }
    }
}

object SmsParserHelper {
    private const val WIDGET_PREFS = "HomeWidgetPreferences"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_PENDING_QUEUE = "pending_sms_queue"
    private const val KEY_SEEN_HASHES = "seen_sms_hashes"

    private val IGNORE_KEYWORDS = listOf(
        "otp", "one time password", "verification code", "do not share",
        "pre-approved", "preapproved", "apply now", "win rs", "cashback offer",
        "credit limit", "statement is generated", "due date reminder", "kyc"
    )

    private val DEBIT_KEYWORDS = listOf(
        "debited", "paid", "spent", "withdrawn", "sent", "deducted",
        "purchase", "debited by", "debited for", "dr ", "emi", "nach", "ecs"
    )

    private val CREDIT_KEYWORDS = listOf(
        "credited", "received", "deposited", "refund", "reversed", "cr "
    )

    private val EMI_KEYWORDS = listOf(
        "emi", "bajaj", "home loan", "loan repayment", "nach", "ecs debit",
        "ach debit", "instalment", "installment", "auto-debit", "auto debit"
    )

    fun isDetectionEnabled(context: Context): Boolean {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return flutterPrefs.getBoolean("flutter.sms_detection_enabled", true)
    }

    fun parseSms(context: Context, sender: String, body: String, timestampMs: Long = System.currentTimeMillis()): ParsedSmsTransaction? {
        val trimmed = body.trim()
        if (trimmed.isEmpty()) return null
        val lower = trimmed.lowercase(Locale.US)
        val senderLower = sender.lowercase(Locale.US)

        if (IGNORE_KEYWORDS.any { lower.contains(it) }) return null

        val hasCurrency = lower.contains("rs") || lower.contains("inr") || trimmed.contains("₹")
        val hasDebit = DEBIT_KEYWORDS.any { lower.contains(it) }
        val hasCredit = CREDIT_KEYWORDS.any { lower.contains(it) }
        if (!hasCurrency || (!hasDebit && !hasCredit)) return null

        // Strip trailing balance section before extracting transaction amount
        val balanceKeywordsRegex = Regex(
            "(?i)(avl\\.?\\s*bal|avail\\.?\\s*bal|available\\s*bal(?:ance)?|clr\\.?\\s*bal|bal\\s*[:\\-])"
        )
        val balSplit = balanceKeywordsRegex.find(trimmed)
        val primaryPortion = if (balSplit != null) trimmed.substring(0, balSplit.range.first) else trimmed
        val balancePortion = if (balSplit != null) trimmed.substring(balSplit.range.first) else ""

        val amountRegex = Regex("(?:rs\\.?|inr|₹)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)|([0-9,]+(?:\\.[0-9]{1,2})?)\\s*(?:rs\\.?|inr|₹)", RegexOption.IGNORE_CASE)
        val amtMatch = amountRegex.find(primaryPortion) ?: amountRegex.find(trimmed) ?: return null
        val rawAmtStr = (amtMatch.groupValues[1].ifEmpty { amtMatch.groupValues[2] }).replace(",", "")
        val amount = rawAmtStr.toDoubleOrNull() ?: return null
        if (amount <= 0.0) return null

        var availableBalance: Double? = null
        if (balancePortion.isNotEmpty()) {
            val balNumRegex = Regex("(?:rs\\.?|inr|₹|:)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)", RegexOption.IGNORE_CASE)
            val balMatch = balNumRegex.find(balancePortion)
            if (balMatch != null) {
                val parsedBal = balMatch.groupValues[1].replace(",", "").toDoubleOrNull()
                if (parsedBal != null && parsedBal >= 0.0) {
                    availableBalance = parsedBal
                }
            }
        }

        val type = if (hasCredit && !hasDebit) "Income" else "Expense"
        val merchant = extractMerchant(trimmed, sender)
        val bankAccount = detectBank(context, senderLower, lower)
        val isEmi = detectIsEmi(context, lower, amount)
        val category = if (isEmi && type == "Expense") "EMI" else guessCategory(lower, merchant, type)

        val hashInput = "${senderLower}|${amount}|${trimmed.take(80)}|${timestampMs / 60000L}"
        val id = sha256Short(hashInput)

        return ParsedSmsTransaction(
            id = id,
            amount = amount,
            type = type,
            category = category,
            merchant = merchant,
            bankAccount = bankAccount,
            availableBalance = availableBalance,
            isEmi = isEmi,
            rawBody = trimmed.take(300),
            timestampMs = timestampMs
        )
    }

    private fun extractMerchant(body: String, sender: String): String {
        val patterns = listOf(
            Regex("(?i)(?:paid\\s+to|sent\\s+to|transfer\\s+to|to)\\s+([A-Za-z0-9 &._\\-]{2,36})"),
            Regex("(?i)(?:at|towards|info[:\\s]+)\\s*([A-Za-z0-9 &._\\-]{2,36})"),
            Regex("(?i)vpa\\s+([A-Za-z0-9._\\-]+@[A-Za-z]+)"),
            Regex("(?i)by\\s+([A-Za-z0-9 &._\\-]{2,30})")
        )
        for (regex in patterns) {
            val match = regex.find(body)
            if (match != null) {
                var candidate = match.groupValues[1]
                    .replace(Regex("(?i)\\b(on|ref|avl|avail|bal|upi|using|via|from)\\b.*"), "")
                    .trim(' ', '.', ',', '-', ':')
                if (candidate.length >= 2) {
                    return candidate.take(40)
                }
            }
        }
        val cleanSender = sender.replace(Regex("^[A-Z]{2}-"), "").trim()
        return if (cleanSender.isNotEmpty()) cleanSender else "Bank SMS"
    }

    private fun detectBank(context: Context, senderLower: String, bodyLower: String): String {
        if (bodyLower.contains("canara") || senderLower.contains("cnrb") || senderLower.contains("canara")) {
            return "Canara Bank"
        }
        if (bodyLower.contains("sbi") || bodyLower.contains("state bank") || senderLower.contains("sbi")) {
            return "SBI"
        }
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return flutterPrefs.getString("flutter.selected_bank_account", "SBI") ?: "SBI"
    }

    fun matchesConfiguredEmiAmount(context: Context, amount: Double): Boolean {
        if (amount <= 0) return false
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val emiAmountsCsv = flutterPrefs.getString("flutter.configured_emi_amounts", "") ?: ""
        if (emiAmountsCsv.isNotEmpty()) {
            for (token in emiAmountsCsv.split(",")) {
                val target = token.trim().toDoubleOrNull()
                if (target != null && target > 0 && abs(target - amount) <= 1.0) {
                    return true
                }
            }
        }
        return false
    }

    private fun detectIsEmi(context: Context, bodyLower: String, amount: Double): Boolean {
        if (EMI_KEYWORDS.any { bodyLower.contains(it) }) return true
        return matchesConfiguredEmiAmount(context, amount)
    }

    private fun guessCategory(bodyLower: String, merchant: String, type: String): String {
        val text = "$bodyLower ${merchant.lowercase(Locale.US)}"
        if (type == "Income") {
            return if (text.contains("salary") || text.contains("payroll")) "Salary" else "Other"
        }
        return when {
            listOf("petrol", "diesel", "pump", "hpcl", "iocl", "bpcl", "shell", "fuel", "indian oil", "bharat petroleum").any { text.contains(it) } -> "Fuel"
            listOf("emi", "loan", "bajaj", "nach", "ecs", "instalment").any { text.contains(it) } -> "EMI"
            listOf("swiggy", "zomato", "restaurant", "hotel", "cafe", "bakery", "food", "grocery", "supermarket", "blinkit", "zepto").any { text.contains(it) } -> "Food"
            listOf("uber", "ola", "metro", "irctc", "train", "bus", "flight", "toll", "fastag").any { text.contains(it) } -> "Transport"
            listOf("pharmacy", "medical", "hospital", "clinic", "doctor", "apollo", "medplus").any { text.contains(it) } -> "Health"
            listOf("amazon", "flipkart", "myntra", "ajio", "mall", "store").any { text.contains(it) } -> "Shopping"
            listOf("electricity", "kseb", "water", "gas", "wifi", "broadband", "airtel", "jio", "recharge").any { text.contains(it) } -> "Utilities"
            else -> "Other"
        }
    }

    fun wasAlreadySeen(context: Context, id: String): Boolean {
        val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        val seenRaw = prefs.getString(KEY_SEEN_HASHES, "") ?: ""
        return seenRaw.split(",").contains(id)
    }

    private fun markSeenIfNew(prefs: SharedPreferences, id: String): Boolean {
        val seenRaw = prefs.getString(KEY_SEEN_HASHES, "") ?: ""
        val existing = seenRaw.split(",").filter { it.isNotEmpty() }
        if (existing.contains(id)) return false
        val seenList = existing.toMutableList()
        seenList.add(0, id)
        if (seenList.size > 60) {
            seenList.subList(60, seenList.size).clear()
        }
        prefs.edit().putString(KEY_SEEN_HASHES, seenList.joinToString(",")).apply()
        return true
    }

    /**
     * Auto-logs exact configured EMI repayment debits immediately without requiring Yes/No confirmation.
     * Returns the logged transaction (with isEmi = true) if auto-logged, or null otherwise.
     */
    fun autoLogIfExactEmi(context: Context, tx: ParsedSmsTransaction): ParsedSmsTransaction? {
        if (tx.type != "Expense" || !matchesConfiguredEmiAmount(context, tx.amount)) {
            return null
        }
        val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        if (!markSeenIfNew(prefs, tx.id)) {
            return null
        }
        val emiTx = tx.copy(
            isEmi = true,
            category = if (tx.category == "Other") "EMI" else tx.category
        )
        logTransactionDirectly(context, emiTx)
        return emiTx
    }

    fun enqueuePendingTransaction(context: Context, tx: ParsedSmsTransaction): Boolean {
        val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        if (!markSeenIfNew(prefs, tx.id)) return false

        val queue = getPendingQueueInternal(prefs)
        val updated = JSONArray()
        updated.put(tx.toJson())
        for (i in 0 until queue.length()) {
            if (updated.length() >= 10) break
            val existing = queue.optJSONObject(i) ?: continue
            if (existing.optString("id") != tx.id) {
                updated.put(existing)
            }
        }

        prefs.edit()
            .putString(KEY_PENDING_QUEUE, updated.toString())
            .apply()

        refreshAllWidgets(context)
        return true
    }

    fun getPendingTransactions(context: Context): List<ParsedSmsTransaction> {
        val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        val arr = getPendingQueueInternal(prefs)
        val list = mutableListOf<ParsedSmsTransaction>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            list.add(ParsedSmsTransaction.fromJson(obj))
        }
        return list
    }

    fun getLatestPendingTransaction(context: Context): ParsedSmsTransaction? {
        return getPendingTransactions(context).firstOrNull()
    }

    fun removePendingById(context: Context, id: String): ParsedSmsTransaction? {
        val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        val arr = getPendingQueueInternal(prefs)
        var removed: ParsedSmsTransaction? = null
        val next = JSONArray()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            if (obj.optString("id") == id && removed == null) {
                removed = ParsedSmsTransaction.fromJson(obj)
            } else {
                next.put(obj)
            }
        }
        prefs.edit().putString(KEY_PENDING_QUEUE, next.toString()).apply()
        refreshAllWidgets(context)
        return removed
    }

    fun confirmPendingToPersonal(context: Context, id: String): ParsedSmsTransaction? {
        val item = removePendingById(context, id) ?: return null
        logTransactionDirectly(context, item)
        return item
    }

    fun logTransactionDirectly(context: Context, item: ParsedSmsTransaction) {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val userEmail = flutterPrefs.getString("flutter.user_email", null) ?: "Self"
        val familyCode = flutterPrefs.getString("flutter.family_code", null)

        val utcIsoTimestamp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Instant.ofEpochMilli(item.timestampMs).toString()
        } else {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            sdf.format(Date(item.timestampMs))
        }

        // 1. Insert into manikutti.db Personal ledger (synced = 0)
        try {
            val dbPath = context.getDatabasePath("manikutti.db")
            if (dbPath.exists()) {
                val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
                val noteText = if (item.availableBalance != null) {
                    val fmtBal = NumberFormat.getNumberInstance(Locale("en", "IN")).format(item.availableBalance.toInt())
                    "${item.merchant} (SMS • Bal ₹$fmtBal)"
                } else {
                    "${item.merchant} (SMS)"
                }
                val values = ContentValues().apply {
                    put("date", utcIsoTimestamp)
                    put("amount", item.amount)
                    put("category", item.category)
                    put("note", noteText)
                    put("isPaid", 1)
                    put("type", item.type)
                    put("addedBy", userEmail)
                    put("familyCode", familyCode)
                    put("synced", 0)
                    put("bankAccount", item.bankAccount)
                }
                db.insert("transactions", null, values)
                db.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Update verified bank balance if SMS included Available Balance
        val editor = flutterPrefs.edit()
        if (item.availableBalance != null) {
            editor.putString("flutter.sms_latest_balance_${item.bankAccount}", item.availableBalance.toString())
            editor.putString("flutter.sms_latest_balance_date_${item.bankAccount}", utcIsoTimestamp)
        }

        // 3. If EMI SMS, suppress mandatory monthly prompt & queue server sync
        if (item.isEmi) {
            val cal = Calendar.getInstance().apply { timeInMillis = item.timestampMs }
            val monthKey = String.format(Locale.US, "%04d-%02d", cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1)
            editor.putBoolean("flutter.emi_sms_confirmed_$monthKey", true)
            editor.putString("flutter.pending_emi_sms_sync_month", monthKey)
            editor.putString("flutter.pending_emi_sms_sync_amount", item.amount.toString())
            editor.putString("flutter.pending_emi_sms_sync_note", "Auto-confirmed via SMS: ${item.merchant}")
        }
        editor.apply()

        // 4. Recompute widget month total and refresh home widgets
        recalculateWidgetMonthTotal(context)
        refreshAllWidgets(context)
    }

    fun showLoggedNotification(context: Context, item: ParsedSmsTransaction, autoEmi: Boolean = false) {
        try {
            NotificationChannelHelper.createChannels(context)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val fmt = NumberFormat.getNumberInstance(Locale("en", "IN"))
            val amtText = "₹${fmt.format(item.amount.toInt())}"

            val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("manikutti://dashboard")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val openPending = PendingIntent.getActivity(context, 701, openAppIntent, piFlags)

            val title = if (autoEmi) "Manikutti: EMI Auto-Logged" else "Manikutti: SMS Logged"
            val subtitle = if (item.isEmi) {
                "Auto-logged $amtText EMI (${item.merchant}) & marked this month's EMI paid ✓"
            } else {
                "Logged $amtText for ${item.category} (${item.merchant}) to Personal ✓"
            }

            val notif = NotificationCompat.Builder(context, NotificationChannelHelper.VOICE_EXPENSE_CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setStyle(NotificationCompat.BigTextStyle().bigText(subtitle))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(openPending)
                .setColor(0xFF006972.toInt())
                .build()

            manager.notify((item.id.hashCode() and 0x7FFF) + 6000, notif)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun recalculateWidgetMonthTotal(context: Context) {
        try {
            val dbPath = context.getDatabasePath("manikutti.db")
            if (!dbPath.exists()) return
            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val cal = Calendar.getInstance()
            val monthPrefix = String.format(Locale.US, "%04d-%02d", cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1)
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
            val formattedTotal = "₹${formatter.format(monthTotal.toInt())}"
            context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString("total_expense", formattedTotal)
                .apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun refreshAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val summaryIds = manager.getAppWidgetIds(ComponentName(context, ManikuttiHomeWidgetProvider::class.java))
        if (summaryIds.isNotEmpty()) {
            val intent = Intent(context, ManikuttiHomeWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, summaryIds)
            }
            context.sendBroadcast(intent)
        }
        val quickIds = manager.getAppWidgetIds(ComponentName(context, ManikuttiQuickLogWidgetProvider::class.java))
        if (quickIds.isNotEmpty()) {
            val intent = Intent(context, ManikuttiQuickLogWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, quickIds)
            }
            context.sendBroadcast(intent)
        }
    }

    private fun getPendingQueueInternal(prefs: android.content.SharedPreferences): JSONArray {
        val raw = prefs.getString(KEY_PENDING_QUEUE, "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun sha256Short(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return digest.take(8).joinToString("") { "%02x".format(it) }
    }
}
