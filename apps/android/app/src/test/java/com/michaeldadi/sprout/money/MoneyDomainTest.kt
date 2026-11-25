package com.michaeldadi.sprout.money

import com.google.gson.Gson
import java.io.File
import org.junit.Assert.*
import org.junit.Test

class MoneyDomainTest {
    @Test fun identityCacheBeforeCredentialMetadataRemainsReadable() {
        val gson=Gson();val type=com.michaeldadi.sprout.services.AppwriteAccountIdentity::class.java
        val old=gson.fromJson("{\"id\":\"owner\",\"email\":\"qa@example.invalid\",\"name\":\"QA\"}",type);assertEquals("owner",old.id);assertNull(old.hasPassword)
        val updated=gson.fromJson("{\"id\":\"owner\",\"email\":\"qa@example.invalid\",\"name\":\"QA\",\"hasPassword\":true}",type);assertEquals(true,updated.hasPassword)
    }
    @Test fun notificationPreferencesPreserveLegacyCacheAndNullableWireFields() {
        val gson = com.google.gson.GsonBuilder().serializeNulls().create()
        val legacy = gson.fromJson("{\"name\":\"Legacy\",\"timezone\":\"America/New_York\"}",MoneyProfile::class.java)
        assertNull(legacy.quietHours)
        val wire = com.google.gson.JsonParser.parseString(gson.toJson(MoneyProfile())).asJsonObject
        assertTrue(wire["quietHours"].isJsonNull);assertTrue(wire["budgetAlerts"].isJsonNull)
        val reviewed = MoneyProfile(timezone="America/Los_Angeles",quietHours=MoneyQuietHours(false,1230,450),budgetAlerts=false)
        val restored = gson.fromJson(gson.toJson(reviewed),MoneyProfile::class.java)
        assertEquals(reviewed.quietHours,restored.quietHours);assertEquals(reviewed.timezone,restored.timezone);assertEquals(false,restored.budgetAlerts)
    }
    @Test fun sharedExpenseTextAmountsRequireUnambiguousReviewedUsd() {
        val stream = javaClass.classLoader!!.getResourceAsStream("expense-text.json")!!
        com.google.gson.JsonParser.parseString(stream.bufferedReader().use { it.readText() }).asJsonArray.forEach { element ->
            val row = element.asJsonObject
            val values = ExpenseDraft.explicitAmounts(row["text"].asString)
            val expected = row["amountMinor"].takeUnless { it.isJsonNull }?.asLong
            assertEquals(row["text"].asString, expected, values.singleOrNull()?.let { MoneyAmount.parse(it) })
        }
    }

    @Test fun analyticsRejectsFinancialAndFreeFormValues() {
        assertNull(SproutAnalyticsPolicy.sanitize("merchant_secret"))
        assertEquals(mapOf("screen_name" to "home"), SproutAnalyticsPolicy.sanitize("screen_view", mapOf("screen_name" to "home", "amount" to 123.45, "merchant" to "Sensitive", "accountId" to "user123", "transcript" to "my salary", "url" to "https://private.example")))
        assertEquals(emptyMap<String, String>(), SproutAnalyticsPolicy.sanitize("screen_view", mapOf("screen_name" to "My private merchant")))
        assertEquals(mapOf("source" to "scan", "type" to "expense"), SproutAnalyticsPolicy.sanitize("transaction_added", mapOf("source" to "scan", "type" to "expense", "amount" to -123)))
    }

    @Test
    fun sharedShortcutReviewCases() {
        val stream = javaClass.classLoader!!.getResourceAsStream("shortcut-inputs.json")!!
        val cases =
            com.google.gson.JsonParser.parseString(stream.bufferedReader().use { it.readText() })
                .asJsonArray
        cases.forEach { element ->
            val value = element.asJsonObject
            val fields =
                value.getAsJsonObject("fields").entrySet().associate { it.key to it.value.asString }
            val draft = ExpenseDraft.shortcut(fields)
            if (value["valid"].asBoolean) {
                assertNotNull(value["name"].asString, draft)
                assertEquals("shortcut", draft!!.source)
                assertEquals(
                    if (value["minor"].isJsonNull) null else -value["minor"].asLong,
                    draft.transaction()?.amount?.minor,
                )
                if (draft.transaction() != null)
                    assertEquals(fields["date"], draft.transaction()?.date)
            } else assertNull(value["name"].asString, draft)
        }
    }

    @Test
    fun pendingCommandHasValidDisplayMetadataBeforeAcknowledgment() {
        val item = ExpenseDraft(amount = "4.56", merchant = "Offline lunch").transaction()!!
        val gson = Gson()
        val command =
            gson
                .toJsonTree(
                    mapOf(
                        "type" to "transaction.upsert",
                        "expectedVersion" to 0,
                        "transaction" to item.commandValue(),
                    )
                )
                .asJsonObject
        val pending = decodePendingTransaction(command, gson)
        assertEquals(1, pending.version)
        assertEquals("", pending.updatedAt)
        assertEquals("Offline lunch", pending.copy(category = "Food").merchant)
    }

    @Test
    fun syncPublishesOnlyCompleteProjectionAndAppliesTombstones() {
        val gson = Gson()
        val base =
            gson
                .fromJson(
                    File("src/debug/assets/money-workspace.json").readText(),
                    MoneyWorkspace::class.java,
                )
                .copy(accountId = "alice", cursor = "old")
        val item = base.transactions.first()
        val projection =
            gson.toJsonTree(base).asJsonObject.apply {
                remove("transactions")
                addProperty("revision", base.revision + 2)
                getAsJsonObject("snapshot").addProperty("revision", base.revision + 2)
            }
        val deletion =
            mapOf(
                "kind" to "transactions",
                "record" to
                    mapOf(
                        "id" to item.id,
                        "version" to item.version + 1,
                        "deleted" to true,
                        "data" to null,
                    ),
            )
        fun page(sequence: Long, more: Boolean, changes: List<Any>, first: Boolean): String =
            com.google.gson
                .GsonBuilder()
                .serializeNulls()
                .create()
                .toJson(
                    mapOf(
                        "contractVersion" to 1,
                        "accountId" to "alice",
                        "throughRevision" to base.revision + 2,
                        "events" to listOf(mapOf("sequence" to sequence, "changes" to changes)),
                        "hasMore" to more,
                        "unchanged" to false,
                        "projection" to if (first) projection else null,
                        "nextCursor" to if (more) "next" else "stable",
                        "capabilities" to base.capabilities,
                    )
                )
        val cycle = MoneySyncCycle(gson.toJson(base), "alice")
        assertNull(cycle.append(page(base.revision + 1, true, listOf(deletion), true)).result)
        val result =
            gson.fromJson(
                cycle.append(page(base.revision + 2, false, emptyList(), false)).result,
                MoneyWorkspace::class.java,
            )
        assertEquals(base.revision + 2, result.revision)
        assertEquals("stable", result.cursor)
        assertFalse(result.transactions.any { it.id == item.id })
        assertEquals(base.transactions.size - 1, result.transactions.size)
        assertThrows(MoneyApiException::class.java) { MoneySyncCycle(gson.toJson(base), "bob") }
        assertThrows(MoneyApiException::class.java) {
            MoneySyncCycle(gson.toJson(base), "alice")
                .append(page(base.revision + 2, false, emptyList(), true))
        }
    }

    @Test
    fun exactCentsAndInvalidPrecision() {
        assertEquals(29L, MoneyAmount.parse("0.29"))
        assertEquals(123456L, MoneyAmount.parse("$1234.56"))
        listOf("1.005", "1$2", "-10", "NaN", "900719925474100", "0").forEach {
            assertNull(it, MoneyAmount.parse(it))
        }
    }

    @Test
    fun datesAndAmbiguousTotalsNeedReview() {
        assertEquals(
            listOf("12.50"),
            ExpenseDraft.explicitAmounts("On November 9 I spent $12.50 at lunch"),
        )
        assertEquals(2, ExpenseDraft.explicitAmounts("Subtotal $12 and tax $1.20").size)
        assertTrue(ExpenseDraft.explicitAmounts("Dinner on the 18th").isEmpty())
        assertTrue(ExpenseDraft.explicitAmounts("Total $12.345").isEmpty())
    }

    @Test
    fun draftPreservesIdentityAndSignedAmount() {
        val draft = ExpenseDraft(amount = "0.29", merchant = "Coffee")
        assertEquals(-29L, draft.transaction()?.amount?.minor)
        assertEquals(draft.id, draft.transaction()?.id)
        assertNull(draft.copy(merchant = " ").transaction())
    }

    @Test
    fun editingPinsReviewedVersionAndPreservesMetadata() {
        val item =
            ExpenseDraft(amount = "12.50", merchant = "Coffee")
                .transaction()!!
                .copy(version = 7, excluded = true)
        val draft = ExpenseDraft.editing(item)!!
        assertEquals(7, draft.expectedVersion)
        assertEquals(item.id, draft.transaction()?.id)
        assertEquals(item.amount, draft.transaction()?.amount)
        assertEquals(item.date, draft.transaction()?.date)
        assertTrue(draft.transaction()!!.excluded)
        assertEquals(7, draft.copy(merchant = "Reviewed correction").expectedVersion)
        assertNull(ExpenseDraft.editing(item.copy(source = "plaid")))
    }

    @Test
    fun sharedFixtureNeverFabricatesCash() {
        val fixture =
            Gson()
                .fromJson(
                    File("src/debug/assets/money-workspace.json").readText(),
                    MoneyWorkspace::class.java,
                )
        assertNull(fixture.snapshot.balanceMinor)
        assertEquals("Stream Club", fixture.subscriptions.first().merchant)
        assertEquals(1599L, fixture.snapshot.monthlySubscriptionsMinor)
        assertEquals(201283L, fixture.snapshot.heroMinor)
    }
}
