package com.michaeldadi.sprout.services

import io.appwrite.Client
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.net.InetAddress
import java.net.ServerSocket
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AppwriteNativeAuthTest {
    @Test
    fun `native Google token exchange sends provider token to Appwrite and retains session cookie`() = runTest {
        val server = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
        var method: String? = null
        var projectHeader: String? = null
        var body: String? = null
        val serverThread = Thread {
            server.accept().use { socket ->
                val reader = socket.getInputStream().bufferedReader()
                method = reader.readLine().substringBefore(' ')
                var contentLength = 0
                while (true) {
                    val line = reader.readLine()
                    if (line.isEmpty()) break
                    val key = line.substringBefore(':')
                    val value = line.substringAfter(':').trim()
                    if (key.equals("Content-Length", ignoreCase = true)) contentLength = value.toInt()
                    if (key.equals("X-Appwrite-Project", ignoreCase = true)) projectHeader = value
                }
                val chars = CharArray(contentLength)
                var read = 0
                while (read < chars.size) {
                    val next = reader.read(chars, read, chars.size - read)
                    if (next < 0) error("Incomplete request body")
                    read += next
                }
                body = String(chars)
                val response = "{\"${'$'}id\":\"session-1\"}"
                val headers = "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\n" +
                    "Set-Cookie: a_session_test-project=session-secret; Path=/; HttpOnly\r\n" +
                    "Content-Length: ${response.toByteArray().size}\r\nConnection: close\r\n\r\n"
                socket.getOutputStream().write((headers + response).toByteArray())
            }
        }
        serverThread.start()
        try {
            val endpoint = "http://127.0.0.1:${server.localPort}/v1"
            val client = Client(RuntimeEnvironment.getApplication())
                .setEndpoint(endpoint)
                .setProject("test-project")
            AppwriteNativeAuth.exchangeGoogleIdToken(client, "test-project", "native-id-token", "Test User")
            serverThread.join(5_000)

            assertEquals("POST", method)
            assertEquals("test-project", projectHeader)
            val payload = JSONObject(body!!)
            assertEquals("google", payload.getString("provider"))
            assertEquals("native-id-token", payload.getString("idToken"))
            assertEquals("Test User", payload.getString("name"))
            assertTrue(client.getCookies(endpoint).any { it.name == "a_session_test-project" })
        } finally {
            server.close()
            serverThread.join(5_000)
        }
    }
}
