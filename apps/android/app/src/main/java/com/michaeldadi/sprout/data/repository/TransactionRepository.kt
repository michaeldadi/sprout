package com.michaeldadi.sprout.data.repository

import android.content.Context
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.ExistingPeriodicWorkPolicy
import com.michaeldadi.sprout.data.dao.TransactionDao
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionEntity
import com.michaeldadi.sprout.workers.SyncWorker
import kotlinx.coroutines.flow.Flow
import java.util.Date
import java.util.concurrent.TimeUnit

class TransactionRepository(
    private val transactionDao: TransactionDao,
    private val context: Context
) {
    
    fun getAllTransactions(): Flow<List<TransactionEntity>> = transactionDao.getAllTransactions()
    
    fun getTransactionsByUserId(userId: String): Flow<List<TransactionEntity>> = 
        transactionDao.getTransactionsByUserId(userId)
    
    suspend fun getTransactionById(id: String): TransactionEntity? = 
        transactionDao.getTransactionById(id)
    
    suspend fun insertTransaction(transaction: TransactionEntity) {
        val updatedTransaction = transaction.copy(
            locallyModifiedAt = Date(),
            syncStatus = SyncStatus.PENDING
        )
        transactionDao.insertTransaction(updatedTransaction)
        scheduleSyncWork()
    }
    
    suspend fun updateTransaction(transaction: TransactionEntity) {
        val updatedTransaction = transaction.copy(
            locallyModifiedAt = Date(),
            updatedAt = Date(),
            syncStatus = SyncStatus.PENDING
        )
        transactionDao.updateTransaction(updatedTransaction)
        scheduleSyncWork()
    }
    
    suspend fun deleteTransaction(id: String) {
        transactionDao.markAsDeleted(id)
        scheduleSyncWork()
    }
    
    suspend fun getUnsyncedTransactions(): List<TransactionEntity> = 
        transactionDao.getUnsyncedTransactions()
    
    suspend fun updateSyncStatus(id: String, status: SyncStatus, syncedAt: Date? = null) {
        transactionDao.updateSyncStatus(id, status, syncedAt)
    }
    
    suspend fun getTransactionsBySyncStatus(status: SyncStatus): List<TransactionEntity> = 
        transactionDao.getTransactionsBySyncStatus(status)
    
    fun getTransactionsByDateRange(startDate: Date, endDate: Date): Flow<List<TransactionEntity>> = 
        transactionDao.getTransactionsByDateRange(startDate, endDate)
    
    fun getTransactionsByCategory(category: String): Flow<List<TransactionEntity>> = 
        transactionDao.getTransactionsByCategory(category)
    
    suspend fun getUnsyncedCount(): Int = transactionDao.getUnsyncedCount()
    
    suspend fun cleanupDeletedSyncedTransactions() {
        transactionDao.cleanupDeletedSyncedTransactions()
    }
    
    suspend fun insertTransactionsFromRemote(transactions: List<TransactionEntity>) {
        // Insert remote transactions with synced status
        val syncedTransactions = transactions.map { transaction ->
            transaction.copy(
                syncStatus = SyncStatus.SYNCED,
                lastSyncedAt = Date()
            )
        }
        transactionDao.insertTransactions(syncedTransactions)
    }
    
    private fun scheduleSyncWork() {
        val syncWorkRequest = PeriodicWorkRequestBuilder<SyncWorker>(
            15, TimeUnit.MINUTES
        ).build()
        
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "transaction_sync",
            ExistingPeriodicWorkPolicy.KEEP,
            syncWorkRequest
        )
    }
    
    suspend fun forceSyncNow() {
        // Trigger immediate sync
        val workManager = WorkManager.getInstance(context)
        val syncWorkRequest = androidx.work.OneTimeWorkRequestBuilder<SyncWorker>().build()
        workManager.enqueue(syncWorkRequest)
    }
}