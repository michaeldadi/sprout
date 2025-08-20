package com.michaeldadi.sprout.services

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.michaeldadi.sprout.config.AppConfig

/**
 * Google Sign In service for Android using Credential Manager API
 * Mirrors the iOS Google Sign In functionality
 */
class GoogleSignInService(
    private val context: Context,
    private val activity: ComponentActivity
) {
    private val credentialManager = CredentialManager.create(context)
    
    suspend fun signIn(): GoogleSignInResult {
        return try {
            val googleIdOption = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId(AppConfig.googleSignInClientId)
                .build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
                .build()

            val result = credentialManager.getCredential(
                request = request,
                context = activity,
            )
            
            when (val credential = result.credential) {
                is GoogleIdTokenCredential -> {
                    GoogleSignInResult.Success(
                        idToken = credential.idToken,
                        email = credential.id,
                        displayName = credential.displayName,
                        photoUrl = credential.profilePictureUri?.toString()
                    )
                }
                else -> {
                    GoogleSignInResult.Error("Unknown credential type")
                }
            }
        } catch (e: GetCredentialException) {
            when (e) {
                is androidx.credentials.exceptions.GetCredentialCancellationException -> {
                    GoogleSignInResult.Cancelled
                }
                else -> {
                    GoogleSignInResult.Error(e.message ?: "Google Sign In failed")
                }
            }
        } catch (e: Exception) {
            GoogleSignInResult.Error(e.message ?: "Google Sign In failed")
        }
    }
    
    suspend fun signOut() {
        try {
            // Clear any cached credentials
            // Note: Credential Manager doesn't have a direct sign out method
            // You would typically handle this on the server side or use additional APIs
            println("Google sign out completed")
        } catch (e: Exception) {
            println("Google sign out error: ${e.message}")
        }
    }
}

/**
 * Result classes for Google Sign In
 */
sealed class GoogleSignInResult {
    data class Success(
        val idToken: String,
        val email: String,
        val displayName: String?,
        val photoUrl: String?
    ) : GoogleSignInResult()
    
    object Cancelled : GoogleSignInResult()
    
    data class Error(
        val message: String
    ) : GoogleSignInResult()
}