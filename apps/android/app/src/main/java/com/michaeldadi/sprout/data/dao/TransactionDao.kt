package com.michaeldadi.sprout.data.dao

import androidx.room.*
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionEntity
import kotlinx.coroutines.flow.Flow
import java.util.Date

@Dao
interface TransactionDao {
    
    @Query("SELECT * FROM transactions WHERE isDeleted = 0 ORDER BY date DESC")
    fun getAllTransactions(): Flow<List<TransactionEntity>>
    
    @Query("SELECT * FROM transactions WHERE id = :id AND isDeleted = 0")
    suspend fun getTransactionById(id: String): TransactionEntity?
    
    @Query("SELECT * FROM transactions WHERE userId = :userId AND isDeleted = 0 ORDER BY date DESC")
    fun getTransactionsByUserId(userId: String): Flow<List<TransactionEntity>>
    
    @Query("SELECT * FROM transactions WHERE syncStatus != :syncStatus")
    suspend fun getUnsyncedTransactions(syncStatus: SyncStatus = SyncStatus.SYNCED): List<TransactionEntity>
    
    @Query("SELECT * FROM transactions WHERE syncStatus = :status")
    suspend fun getTransactionsBySyncStatus(status: SyncStatus): List<TransactionEntity>
    
    @Query("SELECT * FROM transactions WHERE date BETWEEN :startDate AND :endDate AND isDeleted = 0 ORDER BY date DESC")
    fun getTransactionsByDateRange(startDate: Date, endDate: Date): Flow<List<TransactionEntity>>
    
    @Query("SELECT * FROM transactions WHERE category = :category AND isDeleted = 0 ORDER BY date DESC")
    fun getTransactionsByCategory(category: String): Flow<List<TransactionEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransaction(transaction: TransactionEntity)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransactions(transactions: List<TransactionEntity>)
    
    @Update
    suspend fun updateTransaction(transaction: TransactionEntity)
    
    @Query("UPDATE transactions SET syncStatus = :status, lastSyncedAt = :syncedAt WHERE id = :id")
    suspend fun updateSyncStatus(id: String, status: SyncStatus, syncedAt: Date?)
    
    @Query("UPDATE transactions SET isDeleted = 1, syncStatus = :syncStatus, locallyModifiedAt = :modifiedAt WHERE id = :id")
    suspend fun markAsDeleted(id: String, syncStatus: SyncStatus = SyncStatus.PENDING, modifiedAt: Date = Date())
    
    @Query("DELETE FROM transactions WHERE id = :id")
    suspend fun hardDeleteTransaction(id: String)
    
    @Query("DELETE FROM transactions WHERE isDeleted = 1 AND syncStatus = :syncStatus")
    suspend fun cleanupDeletedSyncedTransactions(syncStatus: SyncStatus = SyncStatus.SYNCED)
    
    @Query("SELECT COUNT(*) FROM transactions WHERE isDeleted = 0")
    suspend fun getTransactionCount(): Int
    
    @Query("SELECT COUNT(*) FROM transactions WHERE syncStatus != :syncStatus")
    suspend fun getUnsyncedCount(syncStatus: SyncStatus = SyncStatus.SYNCED): Int
    
    @Query("SELECT * FROM transactions WHERE locallyModifiedAt > :since AND isDeleted = 0")
    suspend fun getTransactionsModifiedSince(since: Date): List<TransactionEntity>
}