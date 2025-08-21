package com.michaeldadi.sprout.network

import com.michaeldadi.sprout.network.models.SyncDataResponse
import com.michaeldadi.sprout.network.models.SyncResponse
import com.michaeldadi.sprout.network.models.TransactionSyncData
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    @POST("transactions")
    suspend fun createTransaction(
        @Body transaction: TransactionSyncData,
        @Header("Authorization") authorization: String
    ): Response<SyncResponse>
    
    @PUT("transactions/{id}")
    suspend fun updateTransaction(
        @Path("id") transactionId: String,
        @Body transaction: TransactionSyncData,
        @Header("Authorization") authorization: String
    ): Response<SyncResponse>
    
    @DELETE("transactions/{id}")
    suspend fun deleteTransaction(
        @Path("id") transactionId: String,
        @Header("Authorization") authorization: String
    ): Response<Unit>
    
    @GET("sync")
    suspend fun getSyncData(
        @Query("since") since: String,
        @Header("Authorization") authorization: String
    ): Response<SyncDataResponse>
    
    @POST("transactions/{id}/receipt")
    suspend fun uploadReceipt(
        @Path("id") transactionId: String,
        @Body receipt: okhttp3.RequestBody,
        @Header("Authorization") authorization: String
    ): Response<ReceiptUploadResponse>
}

data class ReceiptUploadResponse(
    val receiptUrl: String,
    val uploadedAt: String
)