package com.michaeldadi.sprout.money

import com.google.gson.Gson
import com.google.gson.JsonObject

/**
 * Command payloads deliberately omit server fields. Gson bypasses Kotlin's default arguments, so
 * supply those fields before decoding a display model.
 */
internal fun decodePendingTransaction(command: JsonObject, gson: Gson): MoneyTransaction {
    val item = command.getAsJsonObject("transaction").deepCopy()
    item.addProperty("version", command["expectedVersion"].asInt + 1)
    item.addProperty("updatedAt", "")
    return gson.fromJson(item, MoneyTransaction::class.java)
}
