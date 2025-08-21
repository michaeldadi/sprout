package com.michaeldadi.sprout.network.models

import com.michaeldadi.sprout.data.entities.TransactionEntity
import com.michaeldadi.sprout.data.entities.TransactionType
import java.util.Date

data class TransactionSyncData(
    val id: String,
    val userId: String,
    val amount: Double,
    val currency: String,
    val category: String,
    val subcategory: String?,
    val merchant: String?,
    val description: String?,
    val date: Date,
    val type: String,
    val paymentMethod: String?,
    val receiptUrl: String?,
    val tags: List<String>,
    val notes: String?,
    val location: LocationData?,
    val isRecurring: Boolean,
    val recurringFrequency: String?,
    val attachments: List<String>,
    val locallyModifiedAt: Date,
    val remoteVersion: Int
) {
    companion object {
        fun fromEntity(entity: TransactionEntity): TransactionSyncData {
            return TransactionSyncData(
                id = entity.id,
                userId = entity.userId,
                amount = entity.amount,
                currency = entity.currency,
                category = entity.category,
                subcategory = entity.subcategory,
                merchant = entity.merchant,
                description = entity.description,
                date = entity.date,
                type = entity.type.name.lowercase(),
                paymentMethod = entity.paymentMethod,
                receiptUrl = entity.receiptUrl,
                tags = entity.tags,
                notes = entity.notes,
                location = if (entity.locationLatitude != null && entity.locationLongitude != null) {
                    LocationData(
                        latitude = entity.locationLatitude,
                        longitude = entity.locationLongitude,
                        address = entity.locationAddress,
                        city = entity.locationCity,
                        state = entity.locationState,
                        country = entity.locationCountry,
                        postalCode = entity.locationPostalCode
                    )
                } else null,
                isRecurring = entity.isRecurring,
                recurringFrequency = entity.recurringFrequency,
                attachments = entity.attachments,
                locallyModifiedAt = entity.locallyModifiedAt,
                remoteVersion = entity.remoteVersion
            )
        }
    }
}

data class LocationData(
    val latitude: Double?,
    val longitude: Double?,
    val address: String?,
    val city: String?,
    val state: String?,
    val country: String?,
    val postalCode: String?
)

data class SyncResponse(
    val id: String,
    val version: Int,
    val updatedAt: Date
)

data class SyncDataResponse(
    val transactions: List<RemoteTransaction>,
    val lastSync: Date,
    val hasMore: Boolean,
    val nextCursor: String?
)

data class RemoteTransaction(
    val id: String,
    val userId: String,
    val amount: Double,
    val category: String,
    val description: String?,
    val date: Date,
    val updatedAt: Date,
    val version: Int,
    val type: String? = "expense",
    val currency: String? = "USD",
    val subcategory: String? = null,
    val merchant: String? = null,
    val paymentMethod: String? = null,
    val receiptUrl: String? = null,
    val tags: List<String>? = emptyList(),
    val notes: String? = null,
    val location: LocationData? = null,
    val isRecurring: Boolean? = false,
    val recurringFrequency: String? = null,
    val attachments: List<String>? = emptyList()
) {
    fun toEntity(): TransactionEntity {
        return TransactionEntity(
            id = id,
            userId = userId,
            amount = amount,
            currency = currency ?: "USD",
            category = category,
            subcategory = subcategory,
            merchant = merchant,
            description = description,
            date = date,
            type = when (type?.lowercase()) {
                "income" -> TransactionType.INCOME
                "transfer" -> TransactionType.TRANSFER
                else -> TransactionType.EXPENSE
            },
            paymentMethod = paymentMethod,
            receiptUrl = receiptUrl,
            tags = tags ?: emptyList(),
            notes = notes,
            locationLatitude = location?.latitude,
            locationLongitude = location?.longitude,
            locationAddress = location?.address,
            locationCity = location?.city,
            locationState = location?.state,
            locationCountry = location?.country,
            locationPostalCode = location?.postalCode,
            isRecurring = isRecurring ?: false,
            recurringFrequency = recurringFrequency,
            attachments = attachments ?: emptyList(),
            updatedAt = updatedAt,
            remoteVersion = version
        )
    }
}