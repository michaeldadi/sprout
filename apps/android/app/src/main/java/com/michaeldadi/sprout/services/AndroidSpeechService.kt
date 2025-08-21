package com.michaeldadi.sprout.services

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import java.util.Locale
import java.util.regex.Pattern

class AndroidSpeechService(private val context: Context) {

    companion object {
        private const val TAG = "AndroidSpeechService"
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening by mutableStateOf(false)

    var transcript by mutableStateOf("")
        private set

    var isAvailable by mutableStateOf(false)
        private set

    var onTranscriptChanged: ((String) -> Unit)? = null
    var onListeningStateChanged: ((Boolean) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    init {
        checkAvailability()
    }

    private fun checkAvailability() {
        isAvailable = SpeechRecognizer.isRecognitionAvailable(context) &&
          ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    fun startListening() {
        if (!isAvailable) {
            onError?.invoke("Speech recognition not available or permission not granted")
            return
        }

        if (isListening) {
            return
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Say your expense details...")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "Ready for speech")
                isListening = true
                onListeningStateChanged?.invoke(true)
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Beginning of speech")
            }

            override fun onRmsChanged(rmsdB: Float) {
                // Voice volume level changed
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // Audio buffer received
            }

            override fun onEndOfSpeech() {
                Log.d(TAG, "End of speech")
                isListening = false
                onListeningStateChanged?.invoke(false)
            }

            override fun onError(error: Int) {
                Log.e(TAG, "Speech recognition error: $error")
                isListening = false
                onListeningStateChanged?.invoke(false)

                val errorMessage = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                    SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                    SpeechRecognizer.ERROR_NO_MATCH -> "No speech match found"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
                    SpeechRecognizer.ERROR_SERVER -> "Server error"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                    else -> "Unknown error"
                }
                onError?.invoke(errorMessage)
            }

            override fun onResults(results: Bundle?) {
                Log.d(TAG, "Speech recognition results received")
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    transcript = matches[0]
                    onTranscriptChanged?.invoke(transcript)
                    Log.d(TAG, "Transcript: $transcript")
                }
                isListening = false
                onListeningStateChanged?.invoke(false)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    transcript = matches[0]
                    onTranscriptChanged?.invoke(transcript)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {
                // Speech recognition event
            }
        })

        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting speech recognition", e)
            onError?.invoke("Failed to start speech recognition: ${e.message}")
            isListening = false
            onListeningStateChanged?.invoke(false)
        }
    }

    fun stopListening() {
        speechRecognizer?.stopListening()
        isListening = false
        onListeningStateChanged?.invoke(false)
    }

    fun destroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        isListening = false
    }

    fun parseExpenseFromText(text: String): ExpenseData {
        val lowercased = text.lowercase()

        // Extract amount using regex
        val amountPattern = Pattern.compile("\\$?([0-9]+\\.?[0-9]*)")
        val amountMatcher = amountPattern.matcher(text)
        val amount = if (amountMatcher.find()) {
            amountMatcher.group(1) ?: ""
        } else ""

        // Extract merchant (common patterns)
        var merchant = ""
        val merchantKeywords = listOf("at ", "from ", "to ")
        for (keyword in merchantKeywords) {
            val index = lowercased.indexOf(keyword)
            if (index != -1) {
                val afterKeyword = lowercased.substring(index + keyword.length)
                val words = afterKeyword.split(" ")
                if (words.isNotEmpty()) {
                    merchant = words[0].replaceFirstChar { it.uppercase() }
                    break
                }
            }
        }

        // Extract category (simple keyword matching)
        val categoryKeywords = mapOf(
            "coffee" to "Food & Dining",
            "lunch" to "Food & Dining",
            "dinner" to "Food & Dining",
            "breakfast" to "Food & Dining",
            "gas" to "Transportation",
            "fuel" to "Transportation",
            "uber" to "Transportation",
            "lyft" to "Transportation",
            "grocery" to "Groceries",
            "groceries" to "Groceries",
            "shopping" to "Shopping",
            "clothes" to "Shopping",
            "movie" to "Entertainment",
            "restaurant" to "Food & Dining"
        )

        var category = ""
        for ((keyword, cat) in categoryKeywords) {
            if (lowercased.contains(keyword)) {
                category = cat
                break
            }
        }

        return ExpenseData(
            amount = amount,
            merchant = merchant,
            category = category,
            originalText = text
        )
    }

    fun updateAvailability() {
        checkAvailability()
    }
}

data class ExpenseData(
    val amount: String,
    val merchant: String,
    val category: String,
    val originalText: String
)
