package com.michaeldadi.sprout.money

import java.math.BigDecimal
import java.text.NumberFormat
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import java.util.UUID

@androidx.annotation.Keep
data class MoneyAmount(val minor: Long, val currency: String = "USD") {
    fun formatted(): String =
        NumberFormat.getCurrencyInstance(Locale.US).format(BigDecimal.valueOf(minor, 2))

    companion object {
        fun parse(value: String): Long? {
            val raw = value.trim().removePrefix("$")
            if (!Regex("^\\d+(\\.\\d{1,2})?$").matches(raw)) return null
            return runCatching { BigDecimal(raw).movePointRight(2).longValueExact() }
                .getOrNull()
                ?.takeIf { it > 0 && it <= 9_007_199_254_740_900L }
        }
    }
}

@androidx.annotation.Keep
data class MoneyTransaction(
    val id: String,
    val amount: MoneyAmount,
    val date: String,
    val merchant: String,
    val category: String,
    val type: String,
    val source: String,
    val accountId: String = "cash",
    val description: String = "",
    val pending: Boolean = false,
    val excluded: Boolean = false,
    val version: Int = 0,
    val updatedAt: String = "",
    val providerId: String? = null,
) {
    fun commandValue() =
        mapOf(
            "id" to id,
            "amount" to amount,
            "date" to date,
            "merchant" to merchant,
            "category" to category,
            "type" to type,
            "source" to source,
            "accountId" to accountId,
            "description" to description,
            "pending" to pending,
            "excluded" to excluded,
        )
}

@androidx.annotation.Keep
data class MoneyProfile(
    val name: String = "",
    val onboarding: String = "welcome",
    val monthlyTargetMinor: Long? = null,
    val timezone: String = ZoneId.systemDefault().id,
    val appearance: String = "system",
    val renewalAlerts: Boolean = false,
    val priceAlerts: Boolean = false,
    val weeklyDigest: Boolean = false,
    val budgetAlerts: Boolean? = null,
    val forecastAlerts: Boolean? = null,
    val quietHours: MoneyQuietHours? = null,
)

@androidx.annotation.Keep
data class MoneyQuietHours(val enabled: Boolean = true, val startMinute: Int = 1260, val endMinute: Int = 480)

@androidx.annotation.Keep
data class MoneyRecord<T>(
    val id: String,
    val version: Int,
    val updatedAt: String,
    val deleted: Boolean,
    val data: T,
)

@androidx.annotation.Keep
data class MoneyBudget(
    val id: String,
    val category: String,
    val month: String,
    val limit: MoneyAmount,
) {
    companion object {
        fun categoryKey(value: String): String = java.text.Normalizer.normalize(value, java.text.Normalizer.Form.NFKC).trim().lowercase(Locale.ROOT)
    }
}

@androidx.annotation.Keep
data class MoneyCategoryPace(
    val id: String,
    val category: String,
    val spentMinor: Long,
    val plannedMinor: Long,
    val remainingMinor: Long,
    val dailyMinor: Long,
    val aheadOfPace: Boolean,
)

@androidx.annotation.Keep
data class MoneyBudgetSummary(
    val month: String,
    val daysLeft: Int,
    val spentMinor: Long,
    val plannedMinor: Long,
    val categories: List<MoneyCategoryPace>,
    val state: String? = null,
    val remainingMinor: Long? = null,
)

@androidx.annotation.Keep
data class MoneySnapshot(
    val revision: Long,
    val asOf: String,
    val balanceMinor: Long?,
    val heroLabel: String,
    val heroMinor: Long?,
    val monthlySubscriptionsMinor: Long,
    val budget: MoneyBudgetSummary,
    val coverage: String,
)

@androidx.annotation.Keep
data class MoneyCharge(val date: String, val minor: Long)

@androidx.annotation.Keep
data class MoneySubscription(
    val id: String,
    val merchant: String,
    val accountId: String,
    val amountMinor: Long,
    val cadence: String,
    val monthlyMinor: Long,
    val nextDate: String,
    val confidence: String,
    val evidenceIds: List<String>,
    val charges: List<MoneyCharge>,
    val evidenceHash: String,
    val decision: String,
    val decisionVersion: Int,
)

@androidx.annotation.Keep
data class MoneyInsight(
    val id: String,
    val kind: String,
    val title: String,
    val detail: String,
    val evidenceIds: List<String>,
)

@androidx.annotation.Keep
data class MoneyEntitlements(
    val plus: Boolean,
    val connectionLimit: Int,
    val aiAllowance: Int,
    val cancellationAllowance: Int,
)

@androidx.annotation.Keep
data class MoneyCapabilities(
    val linking: Boolean,
    val cancellation: Boolean,
    val ai: Boolean,
    val forecasts: Boolean,
    val notifications: Boolean,
    val scanAssistance: Boolean,
)

@androidx.annotation.Keep
data class MoneyReminder(
    val subscriptionId: String,
    val enabled: Boolean,
    val daysBefore: Int,
    val renewalDate: String,
    val status: String,
)

@androidx.annotation.Keep
data class MoneyAction(
    val subscriptionId: String,
    val merchant: String,
    val state: String,
    val evidenceHash: String,
    val approvalExpiresAt: String?,
)

@androidx.annotation.Keep
data class MoneyEvidenceReference(val id: String, val text: String, val evidenceIds: List<String>)

@androidx.annotation.Keep
data class MoneyAnswer(
    val message: String,
    val references: List<MoneyEvidenceReference>,
    val assumptions: List<String>,
    val proposalIds: List<String>,
)

@androidx.annotation.Keep
data class MoneyConversation(
    val question: String,
    val context: String?,
    val answer: MoneyAnswer,
    val createdAt: String,
)

@androidx.annotation.Keep
data class MoneyJobResult(
    val fileId: String?,
    val bucketId: String?,
    val generatedAt: String? = null,
    val status: String? = null,
)

@androidx.annotation.Keep
data class MoneyImportProgress(val total: Int, val processed: Int, val imported: Int, val preserved: Int)

@androidx.annotation.Keep
data class MoneyJob(
    val id: String,
    val type: String,
    val status: String,
    val error: String?,
    val result: MoneyJobResult? = null,
    val batchId: String? = null,
    val progress: MoneyImportProgress? = null,
    val updatedAt: String? = null,
)

@androidx.annotation.Keep
data class MoneyConnection(val status: String, val sourceAsOf: String?)

@androidx.annotation.Keep
data class MoneyReceipt(val id: String, val version: Int, val transactionId: String, val status: String, val sha256: String, val bytes: Int, val fileId: String?, val bucketId: String?, val updatedAt: String)

@androidx.annotation.Keep
data class MoneyGoal(
    val id: String,
    val name: String,
    val target: MoneyAmount,
    val allocated: MoneyAmount,
    val targetDate: String?,
    val archived: Boolean,
)

@androidx.annotation.Keep
data class MoneyWorkspace(
    val contractVersion: Int,
    val revision: Long,
    val today: String,
    val profile: MoneyProfile,
    val profileVersion: Int,
    val transactions: List<MoneyTransaction>,
    val budgets: List<MoneyRecord<MoneyBudget>>,
    val subscriptions: List<MoneySubscription>,
    val reminders: List<MoneyRecord<MoneyReminder>>,
    val actions: List<MoneyRecord<MoneyAction>>,
    val insights: List<MoneyInsight>,
    val entitlements: MoneyEntitlements,
    val capabilities: MoneyCapabilities,
    val snapshot: MoneySnapshot,
    val conversations: List<MoneyRecord<MoneyConversation>>? = null,
    val budgetPeriods: List<MoneyBudgetSummary>? = null,
    val goals: List<MoneyRecord<MoneyGoal>>? = null,
    val jobs: List<MoneyJob>? = null,
    val connections: List<MoneyRecord<MoneyConnection>>? = null,
    val changeChannel: String? = null,
    val projectionVersion: Int? = null,
    val accountId: String? = null,
    val cursor: String? = null,
    val receipts: List<MoneyReceipt>? = null,
)

@androidx.annotation.Keep
data class ExpenseDraft(
    val id: String = UUID.randomUUID().toString(),
    val source: String = "manual",
    val amount: String = "",
    val merchant: String = "",
    val category: String = "Other",
    val date: String = LocalDate.now().toString(),
    val accountId: String = "cash",
    val notes: String = "",
    val transcript: String = "",
    val attachmentReferences: List<String> = emptyList(),
    val expectedVersion: Int = 0,
    val excluded: Boolean = false,
    val receiptJPEG: ByteArray? = null,
    val keepReceipt: Boolean = false,
    val receiptId: String = UUID.randomUUID().toString(),
) {
    fun transaction(): MoneyTransaction? {
        val minor = MoneyAmount.parse(amount) ?: return null
        if (
            merchant.isBlank() ||
                merchant.trim().length > 160 ||
                notes.length > 1000 ||
                category.isBlank() ||
                category.length > 80 ||
                runCatching { LocalDate.parse(date) }.isFailure
        )
            return null
        return MoneyTransaction(
            id,
            MoneyAmount(-minor),
            date,
            merchant.trim(),
            category,
            "expense",
            source,
            accountId,
            notes,
            excluded = excluded,
        )
    }

    companion object {
        fun shortcut(fields: Map<String, String>): ExpenseDraft? {
            if ((fields["currency"] ?: "USD") != "USD") return null
            val amount = fields["amount"].orEmpty().trim()
            if (amount.isNotEmpty() && MoneyAmount.parse(amount) == null) return null
            val merchant = fields["merchant"].orEmpty().trim()
            val notes = fields["notes"].orEmpty()
            val category = fields["category"] ?: "Other"
            val date = fields["date"] ?: LocalDate.now().toString()
            if (
                merchant.length > 160 ||
                    notes.length > 1000 ||
                    category !in
                        listOf(
                            "Food",
                            "Groceries",
                            "Transport",
                            "Shopping",
                            "Health",
                            "Entertainment",
                            "Bills",
                            "Other",
                        ) ||
                    !Regex("\\d{4}-\\d{2}-\\d{2}").matches(date) ||
                    runCatching { LocalDate.parse(date) }.isFailure
            )
                return null
            return ExpenseDraft(
                source = "shortcut",
                amount = amount.removePrefix("$"),
                merchant = merchant,
                category = category,
                date = date,
                notes = notes,
            )
        }

        fun editing(item: MoneyTransaction): ExpenseDraft? {
            if (
                item.source == "plaid" ||
                    item.providerId != null ||
                    item.type != "expense" ||
                    item.amount.minor >= 0
            )
                return null
            return ExpenseDraft(
                id = item.id,
                source = item.source,
                amount = BigDecimal.valueOf(-item.amount.minor, 2).toPlainString(),
                merchant = item.merchant,
                category = item.category,
                date = item.date,
                accountId = item.accountId,
                notes = item.description,
                expectedVersion = item.version,
                excluded = item.excluded,
            )
        }

        fun explicitAmounts(text: String): List<String> {
            if (text.length > 4000 || Regex(SproutCaptureRules.corrections, RegexOption.IGNORE_CASE).containsMatchIn(text) || Regex(SproutCaptureRules.unsupportedCurrency, RegexOption.IGNORE_CASE).containsMatchIn(text)) return emptyList()
            val pattern = Regex(SproutCaptureRules.amounts, RegexOption.IGNORE_CASE)
            val matches = pattern.findAll(text).toList()
            if (Regex(SproutCaptureRules.unparsedMinorUnits, RegexOption.IGNORE_CASE).containsMatchIn(pattern.replace(text, " "))) return emptyList()
            val values = mutableListOf<String>()
            for (match in matches) {
                val minor: Long
                val cents = match.groups[4]?.value
                if (cents != null) {
                    minor = cents.toLongOrNull()?.takeIf { it > 0 && it <= 9_007_199_254_740_900L } ?: return emptyList()
                } else {
                    var value = (match.groups[1]?.value ?: match.groups[3]?.value ?: return emptyList()).replace(",", "")
                    match.groups[2]?.value?.let {
                        if (value.contains('.')) return emptyList()
                        value += "." + it.padStart(2, '0')
                    }
                    minor = MoneyAmount.parse(value) ?: return emptyList()
                }
                values.add("${minor / 100}.${(minor % 100).toString().padStart(2, '0')}")
            }
            return values
        }

    }
}

enum class MoneyTab(val route: String, val title: String) {
    HOME("home", "Home"),
    BUDGET("budget", "Budget"),
    ACTIVITY("activity", "Activity"),
    INSIGHTS("insights", "Insights"),
    PROFILE("profile", "Profile"),
}
