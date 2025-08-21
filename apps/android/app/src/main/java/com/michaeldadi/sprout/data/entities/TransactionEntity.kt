package com.michaeldadi.sprout.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters
import com.michaeldadi.sprout.data.converters.DateConverter
import com.michaeldadi.sprout.data.converters.StringListConverter
import java.util.Date
import java.util.UUID

@Entity(tableName = "transactions")
@TypeConverters(DateConverter::class, StringListConverter::class)
data class TransactionEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),
    val userId: String,
    val amount: Double,
    val currency: String = "USD",
    val category: String,
    val subcategory: String? = null,
    val merchant: String? = null,
    val description: String? = null,
    val date: Date = Date(),
    val type: TransactionType,
    val paymentMethod: String? = null,
    val receiptUrl: String? = null,
    val tags: List<String> = emptyList(),
    val notes: String? = null,
    
    // Location data
    val locationLatitude: Double? = null,
    val locationLongitude: Double? = null,
    val locationAddress: String? = null,
    val locationCity: String? = null,
    val locationState: String? = null,
    val locationCountry: String? = null,
    val locationPostalCode: String? = null,
    
    // Recurring transaction info
    val isRecurring: Boolean = false,
    val recurringFrequency: String? = null,
    val attachments: List<String> = emptyList(),
    
    // Sync metadata
    val syncStatus: SyncStatus = SyncStatus.PENDING,
    val lastSyncedAt: Date? = null,
    val locallyModifiedAt: Date = Date(),
    val remoteVersion: Int = 0,
    val conflictResolution: ConflictResolution? = null,
    
    // Offline support
    val isDeleted: Boolean = false,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date()
)

enum class TransactionType {
    INCOME,
    EXPENSE,
    TRANSFER
}

enum class SyncStatus {
    SYNCED,
    PENDING,
    SYNCING,
    FAILED,
    CONFLICT
}

enum class ConflictResolution {
    KEEP_LOCAL,
    KEEP_REMOTE,
    MERGE
}