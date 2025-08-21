package com.michaeldadi.sprout.workers

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.work.*
import com.michaeldadi.sprout.data.database.SproutDatabase
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.repository.TransactionRepository
import com.michaeldadi.sprout.network.ApiService
import com.michaeldadi.sprout.network.models.TransactionSyncData
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*

class SyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val database = SproutDatabase.getDatabase(context)
    private val repository = TransactionRepository(database.transactionDao(), context)
    
    override suspend fun doWork(): Result {
        return try {
            if (!isNetworkAvailable()) {
                return Result.retry()
            }
            
            // Check if user is authenticated by looking at stored tokens
            if (!isUserAuthenticated()) {
                return Result.success() // Skip sync if not authenticated
            }
            
            val accessToken = getStoredAccessToken()
            if (accessToken == null) {
                return Result.success() // Skip sync if no access token
            }
            
            // Perform sync operations
            uploadPendingChanges(accessToken)
            downloadRemoteChanges(accessToken)
            repository.cleanupDeletedSyncedTransactions()
            
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }
    
    private suspend fun uploadPendingChanges(accessToken: String) {
        val unsyncedTransactions = repository.getUnsyncedTransactions()
        
        for (transaction in unsyncedTransactions.filter { it.syncStatus == SyncStatus.PENDING }) {
            try {
                repository.updateSyncStatus(transaction.id, SyncStatus.SYNCING)
                
                val apiService = createApiService()
                
                if (transaction.isDeleted) {
                    // Delete from remote
                    val response = apiService.deleteTransaction(
                        transactionId = transaction.id,
                        authorization = "Bearer $accessToken"
                    )
                    
                    if (response.isSuccessful) {
                        database.transactionDao().hardDeleteTransaction(transaction.id)
                    } else {
                        repository.updateSyncStatus(transaction.id, SyncStatus.FAILED)
                    }
                } else {
                    // Create or update on remote
                    val syncData = TransactionSyncData.fromEntity(transaction)
                    val response = if (transaction.createdAt == transaction.updatedAt) {
                        apiService.createTransaction(syncData, "Bearer $accessToken")
                    } else {
                        apiService.updateTransaction(transaction.id, syncData, "Bearer $accessToken")
                    }
                    
                    if (response.isSuccessful) {
                        val syncResponse = response.body()
                        repository.updateSyncStatus(
                            transaction.id,
                            SyncStatus.SYNCED,
                            Date()
                        )
                        // Update remote version if provided
                        syncResponse?.let {
                            val updatedTransaction = transaction.copy(
                                remoteVersion = it.version,
                                lastSyncedAt = Date()
                            )
                            database.transactionDao().updateTransaction(updatedTransaction)
                        }
                    } else {
                        repository.updateSyncStatus(transaction.id, SyncStatus.FAILED)
                    }
                }
            } catch (e: Exception) {
                repository.updateSyncStatus(transaction.id, SyncStatus.FAILED)
            }
        }
    }
    
    private suspend fun downloadRemoteChanges(accessToken: String) {
        try {
            val lastSync = getLastSyncDate()
            val apiService = createApiService()
            
            val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            
            val response = apiService.getSyncData(
                since = dateFormatter.format(lastSync),
                authorization = "Bearer $accessToken"
            )
            
            if (response.isSuccessful) {
                val syncData = response.body() ?: return
                
                // Convert remote transactions to entities
                val remoteEntities = syncData.transactions.map { it.toEntity() }
                
                // Handle each remote transaction
                for (remoteEntity in remoteEntities) {
                    val localTransaction = repository.getTransactionById(remoteEntity.id)
                    
                    if (localTransaction == null) {
                        // New transaction from remote
                        repository.insertTransactionsFromRemote(listOf(remoteEntity))
                    } else {
                        // Check for conflicts
                        if (localTransaction.syncStatus != SyncStatus.SYNCED && 
                            localTransaction.locallyModifiedAt.after(remoteEntity.updatedAt)) {
                            // Conflict: local changes are newer
                            val conflictedTransaction = localTransaction.copy(
                                syncStatus = SyncStatus.CONFLICT
                            )
                            database.transactionDao().updateTransaction(conflictedTransaction)
                        } else if (remoteEntity.updatedAt.after(localTransaction.updatedAt)) {
                            // Remote is newer, update local
                            val updatedTransaction = remoteEntity.copy(
                                syncStatus = SyncStatus.SYNCED,
                                lastSyncedAt = Date()
                            )
                            database.transactionDao().updateTransaction(updatedTransaction)
                        }
                    }
                }
                
                // Update last sync timestamp
                saveLastSyncDate(Date())
            }
        } catch (e: Exception) {
            // Handle download errors
        }
    }
    
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }
    
    private fun createApiService(): ApiService {
        // This would typically be injected via DI
        // For now, we'll create it here
        return ApiServiceFactory.create()
    }
    
    private fun getLastSyncDate(): Date {
        val prefs = applicationContext.getSharedPreferences("sync_prefs", Context.MODE_PRIVATE)
        val timestamp = prefs.getLong("last_sync", 0)
        return if (timestamp > 0) Date(timestamp) else Date(0)
    }
    
    private fun saveLastSyncDate(date: Date) {
        val prefs = applicationContext.getSharedPreferences("sync_prefs", Context.MODE_PRIVATE)
        prefs.edit().putLong("last_sync", date.time).apply()
    }
    
    private fun isUserAuthenticated(): Boolean {
        val authPrefs = applicationContext.getSharedPreferences("sprout_auth_prefs", Context.MODE_PRIVATE)
        val tokensJson = authPrefs.getString("cognito_tokens", null)
        return !tokensJson.isNullOrBlank()
    }
    
    private fun getStoredAccessToken(): String? {
        val authPrefs = applicationContext.getSharedPreferences("sprout_auth_prefs", Context.MODE_PRIVATE)
        val tokensJson = authPrefs.getString("cognito_tokens", null) ?: return null
        
        return try {
            // Simple JSON parsing to extract access token
            tokensJson.substringAfter("\"accessToken\": \"").substringBefore("\",")
        } catch (e: Exception) {
            null
        }
    }
}

// Factory for creating API service
object ApiServiceFactory {
    fun create(): ApiService {
        val okHttpClient = okhttp3.OkHttpClient.Builder()
            .addInterceptor(okhttp3.logging.HttpLoggingInterceptor().apply {
                level = okhttp3.logging.HttpLoggingInterceptor.Level.BODY
            })
            .build()
            
        val retrofit = retrofit2.Retrofit.Builder()
            .baseUrl("https://api.sprout.com/") // Replace with your actual API base URL
            .client(okHttpClient)
            .addConverterFactory(retrofit2.converter.gson.GsonConverterFactory.create())
            .build()
            
        return retrofit.create(ApiService::class.java)
    }
}