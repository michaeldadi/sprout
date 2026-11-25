package com.michaeldadi.sprout.money

import com.google.gson.JsonObject
import com.google.gson.JsonParser

/** No page is persisted separately from the final projection and stable cursor. */
class MoneySyncCycle(base: String, private val owner: String) {
    private var snapshot = JsonParser.parseString(base).asJsonObject
    private val items = linkedMapOf<String, JsonObject>()
    private var sequence = snapshot["revision"].asLong
    private var through: Long? = null
    private var first = true

    init {
        requireSync(snapshot["accountId"]?.asString == owner)
        snapshot.getAsJsonArray("transactions").forEach {
            val item = it.asJsonObject
            requireSync(items.put(item["id"].asString, item) == null)
        }
    }

    data class Step(val cursor: String, val result: String?)

    fun append(payload: String): Step {
        val page = JsonParser.parseString(payload).asJsonObject
        requireSync(page["accountId"]?.asString == owner && page["contractVersion"].asInt == 1)
        val ceiling = page["throughRevision"].asLong
        val cursor = page["nextCursor"].asString
        val more = page["hasMore"].asBoolean
        val events = page.getAsJsonArray("events")
        requireSync(
            ceiling >= sequence && (through == null || through == ceiling) && cursor.isNotEmpty()
        )
        through = ceiling
        if (page["unchanged"].asBoolean) {
            requireSync(first && ceiling == sequence && events.isEmpty && !more)
        } else if (first) {
            val projection = page.getAsJsonObject("projection")
            requireSync(
                projection["accountId"]?.asString == owner &&
                    projection["revision"].asLong == ceiling &&
                    projection.getAsJsonObject("snapshot")["revision"].asLong == ceiling
            )
            snapshot = projection.deepCopy()
        } else requireSync(page["projection"].isJsonNull)
        events.forEach { element ->
            val event = element.asJsonObject
            requireSync(event["sequence"].asLong == sequence + 1 && sequence < ceiling)
            sequence++
            event.getAsJsonArray("changes").forEach { changeElement ->
                val change = changeElement.asJsonObject
                val record = change.getAsJsonObject("record")
                val id = record["id"].asString
                val version = record["version"].asInt
                requireSync(
                    change["kind"].asString == "transactions" &&
                        version > (items[id]?.get("version")?.asInt ?: 0)
                )
                if (record["deleted"].asBoolean) items.remove(id)
                else {
                    val item = record.getAsJsonObject("data").deepCopy()
                    requireSync(item["id"].asString == id)
                    item.addProperty("version", version)
                    item.add("updatedAt", record["updatedAt"])
                    items[id] = item
                }
            }
        }
        first = false
        if (more) {
            requireSync(sequence < ceiling && !events.isEmpty)
            return Step(cursor, null)
        }
        requireSync(sequence == ceiling)
        snapshot.add(
            "transactions",
            com.google.gson.JsonArray().apply { items.toSortedMap().values.forEach { add(it) } },
        )
        snapshot.addProperty("cursor", cursor)
        snapshot.add("capabilities", page["capabilities"])
        return Step(cursor, snapshot.toString())
    }

    private fun requireSync(value: Boolean) {
        if (!value)
            throw MoneyApiException(
                "CURSOR_INVALID",
                "A fresh account snapshot is required. Pending changes are preserved.",
            )
    }
}
