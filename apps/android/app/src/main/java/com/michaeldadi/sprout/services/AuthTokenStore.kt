package com.michaeldadi.sprout.services

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.edit
import com.michaeldadi.sprout.models.StoredTokens
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Device-bound storage shared by foreground authentication and background sync. */
class AuthTokenStore(context: Context) {
    private val prefs = context.getSharedPreferences("sprout_auth_prefs", Context.MODE_PRIVATE)

    fun save(tokens: StoredTokens) {
        val json = JSONObject()
            .put("accessToken", tokens.accessToken)
            .put("idToken", tokens.idToken)
            .put("refreshToken", tokens.refreshToken)
            .toString()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.iv + cipher.doFinal(json.toByteArray(Charsets.UTF_8))
        val encoded = Base64.encodeToString(encrypted, Base64.NO_WRAP)
        check(prefs.edit().putString(ENCRYPTED_TOKENS, encoded).remove(LEGACY_TOKENS).commit()) {
            "Could not save the authenticated session"
        }
    }

    fun read(): StoredTokens? {
        prefs.getString(ENCRYPTED_TOKENS, null)?.let { encoded ->
            return try {
                val encrypted = Base64.decode(encoded, Base64.DEFAULT)
                require(encrypted.size > 12) { "Invalid encrypted session" }
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, encrypted, 0, 12))
                parse(String(cipher.doFinal(encrypted, 12, encrypted.size - 12), Charsets.UTF_8))
            } catch (_: Exception) {
                null // A restored backup without its device key requires a fresh sign-in.
            }
        }

        val legacy = prefs.getString(LEGACY_TOKENS, null)?.let(::parse) ?: return null
        try {
            save(legacy)
        } catch (_: Exception) {
            // Preserve the previous session if migration could not be persisted yet.
        }
        return legacy
    }

    fun clear() {
        prefs.edit { remove(LEGACY_TOKENS); remove(ENCRYPTED_TOKENS) }
    }

    private fun parse(json: String): StoredTokens? = try {
        val value = JSONObject(json)
        StoredTokens(value.getString("accessToken"), value.getString("idToken"), value.getString("refreshToken"))
    } catch (_: Exception) {
        null
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build())
            generateKey()
        }
    }

    private companion object {
        const val LEGACY_TOKENS = "cognito_tokens"
        const val ENCRYPTED_TOKENS = "cognito_tokens_encrypted"
        const val KEY_ALIAS = "sprout_cognito_tokens"
    }
}
