package com.michaeldadi.sprout.money

import com.google.gson.JsonParser
import com.michaeldadi.sprout.config.AppConfig
import com.michaeldadi.sprout.services.AppwriteConnection
import com.michaeldadi.sprout.services.AppwriteNativeSession
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.buffer
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrl
import java.util.UUID

/** Realtime is a private revision hint. Cursor sync supplies all financial data.
 * This small protocol adapter handles error frames without the SDK's uncaught
 * coroutine exception on session revocation. */
internal object MoneyChangeSignal {
    enum class Frame { CONNECTED, SIGNAL, STOP, IGNORE }
    fun frame(text: String, channel: String, subscription: String): Frame {
        if (text.length > 16_384) return Frame.STOP
        return runCatching {
            val value=JsonParser.parseString(text).asJsonObject
            when(value["type"]?.asString) {
                "connected" -> Frame.CONNECTED
                "error" -> Frame.STOP
                "event" -> {
                    val data=value.getAsJsonObject("data")
                    val channels=data?.getAsJsonArray("channels")?.map { it.asString }.orEmpty()
                    val subscriptions=data?.getAsJsonArray("subscriptions")?.map { it.asString }.orEmpty()
                    if(channel in channels || subscription in subscriptions) Frame.SIGNAL else Frame.IGNORE
                }
                else -> Frame.IGNORE
            }
        }.getOrDefault(Frame.STOP)
    }
    fun listen(owner: String, channel: String) = callbackFlow {
        check(AppwriteNativeSession.identity.value?.id == owner)
        val jwt=AppwriteConnection.account().createJWT().jwt
        check(AppwriteNativeSession.identity.value?.id == owner)
        val subscription=UUID.randomUUID().toString()
        val client=OkHttpClient.Builder().cookieJar(CookieJar.NO_COOKIES).followRedirects(false).followSslRedirects(false).build()
        val url=(AppConfig.appwriteEndpoint.trimEnd('/')+"/realtime").toHttpUrl().newBuilder().addQueryParameter("project",AppConfig.appwriteProjectId).build()
        val request=Request.Builder().url(url).header("x-appwrite-jwt",jwt).build()
        val socket=client.newWebSocket(request,object:WebSocketListener() {
            override fun onMessage(webSocket:WebSocket,text:String) {
                when(frame(text,channel,subscription)) {
                    Frame.CONNECTED -> webSocket.send(org.json.JSONObject().put("type","subscribe").put("data",org.json.JSONArray().put(org.json.JSONObject().put("subscriptionId",subscription).put("channels",org.json.JSONArray().put(channel)).put("queries",org.json.JSONArray()))).toString())
                    Frame.SIGNAL -> trySend(Unit)
                    Frame.STOP -> { close();webSocket.cancel() }
                    Frame.IGNORE -> Unit
                }
            }
            override fun onFailure(webSocket:WebSocket,t:Throwable,response:Response?) { close() }
            override fun onClosed(webSocket:WebSocket,code:Int,reason:String) { close() }
            override fun onClosing(webSocket:WebSocket,code:Int,reason:String) { webSocket.close(code,null);close() }
        })
        val heartbeat=launch { while(true) {delay(20_000);socket.send("{\"type\":\"ping\"}")} }
        awaitClose { heartbeat.cancel();socket.cancel();client.connectionPool.evictAll();client.dispatcher.executorService.shutdown() }
    }.buffer(kotlinx.coroutines.channels.Channel.CONFLATED)
}
