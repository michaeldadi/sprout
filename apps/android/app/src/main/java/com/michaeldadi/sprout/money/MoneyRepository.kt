package com.michaeldadi.sprout.money

import android.content.Context
import androidx.room.*
import com.google.gson.GsonBuilder
import com.google.gson.JsonObject
import com.michaeldadi.sprout.config.AppConfig
import com.michaeldadi.sprout.services.AppwriteAccountIdentity
import com.michaeldadi.sprout.services.AppwriteConnection
import com.michaeldadi.sprout.services.AppwriteNativeSession
import io.appwrite.enums.ExecutionMethod
import io.appwrite.services.Functions
import java.security.MessageDigest
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

@Entity(tableName = "workspace")
data class MoneyCache(@PrimaryKey val id: String = "current", val payload: String)

@Entity(tableName = "outbox")
data class MoneyMutation(
    @PrimaryKey val id: String,
    val entity: String,
    val payload: String,
    val createdAt: Long = System.currentTimeMillis(),
    val conflict: Boolean = false,
)

@Dao
interface MoneyDao {
    @Query("SELECT * FROM workspace WHERE id = 'current'") suspend fun cache(): MoneyCache?

    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun cache(value: MoneyCache)

    @Query("SELECT * FROM outbox ORDER BY createdAt, id")
    suspend fun mutations(): List<MoneyMutation>

    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insert(value: MoneyMutation)

    @Update suspend fun update(value: MoneyMutation)

    @Delete suspend fun delete(value: MoneyMutation)
}

@Database(entities = [MoneyCache::class, MoneyMutation::class], version = 1, exportSchema = true)
abstract class MoneyDatabase : RoomDatabase() {
    abstract fun records(): MoneyDao
}

data class MoneyState(
    val workspace: MoneyWorkspace? = null,
    val mutations: List<MoneyMutation> = emptyList(),
    val refreshing: Boolean = false,
    val message: String? = null,
)

class MoneyApiException(val code: String, override val message: String) : Exception(message)

/**
 * A separate, versioned Room store per Appwrite environment and user. Legacy Double data is
 * preserved.
 */
class MoneyRepository(
    context: Context,
    val identity: AppwriteAccountIdentity,
    private val review: MoneyWorkspace? = null,
) {
    private val appContext = context.applicationContext
    val reviewMode: Boolean get() = review != null
    private val scope =
        MessageDigest.getInstance("SHA-256")
            .digest(
                "${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}/${identity.id}"
                    .toByteArray()
            )
            .joinToString("") { "%02x".format(it) }
    private val db =
        Room.databaseBuilder(
                context.applicationContext,
                MoneyDatabase::class.java,
                "sprout-money-v1-$scope",
            )
            .build()
    private val dao = db.records()
    private val gson = GsonBuilder().serializeNulls().create()
    private val mutex = Mutex()
    private val syncMutex = Mutex()
    private val _state = MutableStateFlow(MoneyState())
    val state = _state.asStateFlow()
    @Volatile private var active = true

    suspend fun initialize() {
        if (review != null && com.michaeldadi.sprout.BuildConfig.DEBUG) {
            _state.value = MoneyState(workspace = review)
            return
        }
        try {
            _state.value =
                MoneyState(
                    dao.cache()?.let { gson.fromJson(it.payload, MoneyWorkspace::class.java) },
                    dao.mutations(),
                )
        } catch (_: Exception) {
            _state.value =
                MoneyState(
                    message = "The local store could not open. Existing data has been preserved."
                )
            return
        }
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { runCatching { MoneyReceiptArchive.prune(appContext, identity.id, dao.mutations().mapNotNull { MoneyReceiptArchive.reference(it.payload) }.toSet()) } }
        refresh()
    }

    suspend fun eraseLocal() {
        active = false
        mutex.withLock {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                db.clearAllTables()
                MoneyReceiptArchive.erase(appContext, identity.id)
            }
        }
        _state.value = MoneyState()
    }

    fun deactivate() {
        active = false
        _state.value = MoneyState()
        db.close()
    }

    fun transactions(): List<MoneyTransaction> {
        val items =
            _state.value.workspace?.transactions.orEmpty().associateBy { it.id }.toMutableMap()
        for (m in _state.value.mutations.filter { !it.conflict }) {
            val command =
                gson.fromJson(m.payload, JsonObject::class.java).getAsJsonObject("command")
            when (command["type"].asString) {
                "transaction.upsert" -> {
                    val item = pendingTransaction(command)
                    items[item.id] = item
                }
                "transaction.delete" -> items.remove(command["id"].asString)
            }
        }
        return items.values.sortedWith(
            compareByDescending<MoneyTransaction> { it.date }.thenByDescending { it.id }
        )
    }

    fun goals(): List<MoneyRecord<MoneyGoal>> {
        val items = _state.value.workspace?.goals.orEmpty().associateBy { it.id }.toMutableMap()
        for (mutation in _state.value.mutations.filter { !it.conflict }) {
            val command =
                gson.fromJson(mutation.payload, JsonObject::class.java).getAsJsonObject("command")
            if (command["type"].asString == "goal.upsert") {
                val goal = gson.fromJson(command["goal"], MoneyGoal::class.java)
                items[goal.id] =
                    MoneyRecord(goal.id, command["expectedVersion"].asInt + 1, "", false, goal)
            }
        }
        return items.values.sortedBy { it.data.name.lowercase() }
    }

    fun pendingGoal(id: String) = _state.value.mutations.any { it.entity == "goal:$id" }

    private fun pendingTransaction(command: JsonObject): MoneyTransaction =
        decodePendingTransaction(command, gson)

    suspend fun enqueue(
        command: Map<String, Any?>,
        entity: String,
        mutationId: String = UUID.randomUUID().toString(),
    ) =
        mutex.withLock {
            checkIdentity()
            if (dao.mutations().any { it.entity == entity })
                throw MoneyApiException(
                    "PENDING",
                    "This record already has a pending change. Sync or resolve it first.",
                )
            dao.insert(
                MoneyMutation(
                    mutationId,
                    entity,
                    gson.toJson(mapOf("mutationId" to mutationId, "command" to command)),
                )
            )
            _state.value = _state.value.copy(mutations = dao.mutations())
        }

    suspend fun save(draft: ExpenseDraft) {
        val transaction =
            draft.transaction()
                ?: throw MoneyApiException(
                    "INVALID_EXPENSE",
                    "Review the amount, merchant and date.",
                )
        val financial = mapOf("type" to "transaction.upsert", "transaction" to transaction.commandValue(), "expectedVersion" to draft.expectedVersion)
        val financialId = if (draft.expectedVersion == 0) draft.id else UUID.randomUUID().toString()
        if (draft.keepReceipt) {
            val jpeg = draft.receiptJPEG?.takeIf { it.size <= 650_000 }
                ?: throw MoneyApiException("INVALID_RECEIPT", "Choose a receipt again before retaining its compressed copy.")
            val hash = java.security.MessageDigest.getInstance("SHA-256").digest(jpeg).joinToString("") { "%02x".format(it.toInt() and 255) }
            val receipt = mapOf("type" to "receipt.attach", "id" to draft.receiptId, "transactionId" to transaction.id, "sha256" to hash)
            mutex.withLock {
                checkIdentity()
                val financialEntity = "transaction:${transaction.id}"; val receiptEntity = "receipt-upload:${draft.receiptId}"
                if (dao.mutations().any { it.entity == financialEntity || it.entity == receiptEntity }) throw MoneyApiException("PENDING", "This transaction already has a pending change. Sync or resolve it first.")
                val receiptMutationId = UUID.randomUUID().toString()
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { MoneyReceiptArchive.save(appContext, identity.id, draft.receiptId, jpeg) }
                try {
                    checkIdentity()
                    db.withTransaction {
                        dao.insert(MoneyMutation(financialId, financialEntity, gson.toJson(mapOf("mutationId" to financialId, "command" to financial))))
                        dao.insert(MoneyMutation(receiptMutationId, receiptEntity, gson.toJson(mapOf("mutationId" to receiptMutationId, "command" to receipt, "attachmentFile" to "${draft.receiptId}.jpg"))))
                    }
                } catch (e: Exception) { kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable + kotlinx.coroutines.Dispatchers.IO) { runCatching { MoneyReceiptArchive.remove(appContext, identity.id, draft.receiptId) } }; throw e }
                _state.value = _state.value.copy(mutations = dao.mutations())
            }
        } else enqueue(financial, "transaction:${transaction.id}", financialId)
        MoneyAnalytics.track("expense_reviewed", mapOf("source" to draft.source))
    }

    suspend fun saveProfile(profile: MoneyProfile, expectedVersion: Int = _state.value.workspace?.profileVersion ?: 0) =
        enqueue(
            mapOf(
                "type" to "profile.update",
                "profile" to profile,
                "expectedVersion" to expectedVersion,
            ),
            "profile",
        )

    suspend fun useServer(mutation: MoneyMutation) =
        mutex.withLock {
            checkIdentity()
            val original = dao.mutations().firstOrNull { it.id == mutation.id && it.payload == mutation.payload } ?: return@withLock
            val receipt = MoneyReceiptArchive.reference(original.payload)
            db.withTransaction {
                dao.delete(original)
                if (receipt != null) {
                    val next = UUID.randomUUID().toString()
                    dao.insert(MoneyMutation(next, "receipt-cancel:$receipt", gson.toJson(mapOf("mutationId" to next, "command" to mapOf("type" to "receipt.cancel", "id" to receipt)))))
                }
            }
            if (receipt != null) kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { runCatching { MoneyReceiptArchive.remove(appContext, identity.id, receipt) } }
            _state.value = _state.value.copy(mutations = dao.mutations())
        }

    fun pendingExpenseDescription(mutation: MoneyMutation): String =
        runCatching {
                val command =
                    gson
                        .fromJson(mutation.payload, JsonObject::class.java)
                        .getAsJsonObject("command")
                val transaction =
                    gson.fromJson(command["transaction"], MoneyTransaction::class.java)
                "Your edit: ${transaction.merchant} · ${transaction.amount.formatted()} · ${transaction.date}"
            }
            .getOrDefault("A saved change needs review before it can sync.")

    fun goalConflictDescription(mutation: MoneyMutation): String =
        runCatching {
                val command =
                    gson
                        .fromJson(mutation.payload, JsonObject::class.java)
                        .getAsJsonObject("command")
                val goal = gson.fromJson(command["goal"], MoneyGoal::class.java)
                "Your edit: ${goal.name}, ${goal.allocated.formatted()} allocated of ${goal.target.formatted()}, date ${goal.targetDate ?: "none"}, ${if(goal.archived) "archived" else "active"}."
            }
            .getOrDefault("Your saved goal needs review.")

    suspend fun keepBudgetEdit(review: MoneyBudgetConflictReview) = mutex.withLock {
        checkIdentity()
        val pending = dao.mutations()
        val original = pending.firstOrNull { it.id == review.mutation.id && it.payload == review.mutation.payload && it.conflict }
            ?: throw MoneyApiException("REVIEW_REQUIRED", "This saved edit changed. Reopen the review.")
        val target = review.server ?: throw MoneyApiException("REVIEW_REQUIRED", "Refresh and review the server budget first.")
        if (_state.value.workspace?.budgets?.firstOrNull { it.id == target.id }?.version != target.version)
            throw MoneyApiException("REVIEW_REQUIRED", "This budget changed again. Reopen the review before choosing.")
        val entity = "budget:${target.id}"
        if (pending.any { it.id != original.id && it.entity == entity })
            throw MoneyApiException("PENDING", "The server budget already has a pending edit. Sync or resolve it first.")
        val next = UUID.randomUUID().toString()
        db.withTransaction {
            dao.delete(original)
            dao.insert(MoneyMutation(next, entity, gson.toJson(mapOf("mutationId" to next, "command" to review.command()))))
        }
        _state.value = _state.value.copy(mutations = dao.mutations())
    }

    suspend fun discardReviewedEdit(review: MoneyEditConflictReview) = mutex.withLock {
        checkIdentity()
        val original = dao.mutations().firstOrNull { it.id == review.mutation.id && it.payload == review.mutation.payload && it.conflict }
            ?: throw MoneyApiException("REVIEW_REQUIRED", "This saved edit changed. Reopen the review.")
        dao.delete(original); _state.value = _state.value.copy(mutations = dao.mutations())
    }

    suspend fun keepReviewedEdit(review: MoneyEditConflictReview) = mutex.withLock {
        checkIdentity()
        val original = dao.mutations().firstOrNull { it.id == review.mutation.id && it.payload == review.mutation.payload && it.conflict }
            ?: throw MoneyApiException("REVIEW_REQUIRED", "This saved edit changed. Reopen the review.")
        if (_state.value.refreshing || review.serverVersion == null || review.currentVersion(_state.value.workspace) != review.serverVersion)
            throw MoneyApiException("REVIEW_REQUIRED", "This record changed again. Reopen the review before choosing.")
        val next = UUID.randomUUID().toString()
        db.withTransaction {
            dao.delete(original)
            dao.insert(MoneyMutation(next, original.entity, gson.toJson(mapOf("mutationId" to next, "command" to review.command()))))
        }
        _state.value = _state.value.copy(mutations = dao.mutations())
    }

    suspend fun refresh() =
        syncMutex.withLock {
            if (review != null) return@withLock
            if (!active) return@withLock
            _state.value = _state.value.copy(refreshing = true)
            try {
                val acknowledged = mutableListOf<MoneyMutation>()
                for (m in dao.mutations().filter { !it.conflict }.sortedBy { it.entity.startsWith("receipt-upload:") }) {
                    try {
                        val payload = if (m.entity.startsWith("receipt-upload:")) kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { MoneyReceiptArchive.wire(appContext, identity.id, m.payload) } else m.payload
                        request("/v1/commands", payload)
                        checkIdentity()
                        acknowledged.add(m)
                    } catch (e: MoneyApiException) {
                        if (
                            e.code in
                                listOf(
                                    "VERSION_CONFLICT",
                                    "STALE_EVIDENCE",
                                    "STALE_APPROVAL",
                                    "INVALID_REQUEST",
                                    "IMPORT_CHANGED",
                                    "PAYLOAD_TOO_LARGE",
                                    "RECEIPT_CHANGED", "RECEIPT_REMOVED", "INVALID_RECEIPT", "RECEIPT_SCOPE", "RECEIPT_LIMIT", "RECEIPT_LOCAL_MISSING", "RECEIPT_LOCAL_CHANGED", "ATTACHMENT_TARGET_GONE",
                                    "PROVIDER_OWNED",
                                    "NOT_FOUND",
                                    "PLUS_REQUIRED",
                                    "UNSUPPORTED_MERCHANT",
                                    "ACCOUNT_DELETING",
                                )
                        )
                            mutex.withLock {
                                dao.update(m.copy(conflict = true))
                                _state.value = _state.value.copy(mutations = dao.mutations())
                            }
                        else throw e
                    }
                }
                val payload = download()
                checkIdentity()
                val workspace = gson.fromJson(payload, MoneyWorkspace::class.java)
                if (workspace.accountId != identity.id)
                    throw MoneyApiException(
                        "ACCOUNT_CHANGED",
                        "The account changed during sync. No downloaded records were saved.",
                    )
                if (workspace.contractVersion != 1)
                    throw MoneyApiException(
                        "UPDATE_REQUIRED",
                        "Update Sprout to sync this account.",
                    )
                mutex.withLock {
                    checkIdentity()
                    db.withTransaction {
                        dao.cache(MoneyCache(payload = payload))
                        acknowledged.forEach { dao.delete(it) }
                    }
                    kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { acknowledged.mapNotNull { MoneyReceiptArchive.reference(it.payload) }.forEach { runCatching { MoneyReceiptArchive.remove(appContext, identity.id, it) } } }
                    _state.value =
                        MoneyState(
                            workspace,
                            dao.mutations(),
                            message =
                                if (dao.mutations().any { it.conflict })
                                    "A record changed on another device. Review the pending edit."
                                else null,
                        )
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) {
                if (active) _state.value = _state.value.copy(refreshing = false)
                throw cancelled
            } catch (e: Exception) {
                if (active)
                    _state.value =
                        _state.value.copy(
                            mutations = dao.mutations(),
                            refreshing = false,
                            message =
                                (e as? MoneyApiException)?.message
                                    ?: "Can't reach Sprout. Saved records are available and pending changes will retry.",
                        )
            }
        }

    private suspend fun download(): String {
        val base = _state.value.workspace ?: return request("/v1/bootstrap")
        if (base.projectionVersion != 3) return request("/v1/bootstrap")
        var cursor = base.cursor ?: return request("/v1/bootstrap")
        try {
            val cycle = MoneySyncCycle(gson.toJson(base), identity.id)
            repeat(400) {
                val step = cycle.append(request("/v1/sync?cursor=$cursor"))
                checkIdentity()
                cursor = step.cursor
                step.result?.let {
                    return it
                }
            }
            return request("/v1/bootstrap")
        } catch (error: MoneyApiException) {
            if (error.code !in listOf("CURSOR_INVALID", "CURSOR_EXPIRED")) throw error
            return request("/v1/bootstrap")
        }
    }

    suspend fun request(
        path: String,
        payload: String? = null,
        function: String = "sprout-api",
    ): String {
        checkIdentity()
        val scopedPayload =
            payload?.let {
                val value = gson.fromJson(it, JsonObject::class.java)
                value.addProperty("_account", identity.id)
                gson.toJson(value)
            }
        val execution =
            Functions(AppwriteConnection.client())
                .createExecution(
                    functionId = function,
                    body = scopedPayload,
                    headers = mapOf("x-sprout-account" to identity.id),
                    async = false,
                    path = path,
                    method = if (payload == null) ExecutionMethod.GET else ExecutionMethod.POST,
                )
        if (execution.responseStatusCode !in 200..299) {
            val error =
                runCatching {
                        gson
                            .fromJson(execution.responseBody, JsonObject::class.java)
                            .getAsJsonObject("error")
                    }
                    .getOrNull()
            throw MoneyApiException(
                error?.get("code")?.asString ?: "SERVICE_UNAVAILABLE",
                error?.get("message")?.asString ?: "This service is unavailable. Try again shortly.",
            )
        }
        return execution.responseBody
    }

    fun encode(value: Any): String = gson.toJson(value)

    private fun checkIdentity() {
        if (!active || AppwriteNativeSession.identity.value?.id != identity.id)
            throw MoneyApiException("UNAUTHENTICATED", "Sign in again to continue.")
    }
}
