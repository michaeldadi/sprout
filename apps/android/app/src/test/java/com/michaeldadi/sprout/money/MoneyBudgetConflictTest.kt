package com.michaeldadi.sprout.money

import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Test

class MoneyBudgetConflictTest {
    private fun pending(budget: MoneyBudget) = MoneyMutation(
        "saved-local-edit", "budget:${budget.id}",
        Gson().toJson(mapOf("command" to mapOf("type" to "budget.upsert", "budget" to budget, "expectedVersion" to 0))),
        conflict = true,
    )

    @Test fun separateOfflineIdsResolveAgainstTheReviewedLogicalBudget() {
        val local = MoneyBudget("offline", "Ｆｏｏｄ", "2026-11", MoneyAmount(2222))
        val server = MoneyRecord("winner", 4, "", false, local.copy(id = "winner", category = "Food", limit = MoneyAmount(3333)))
        val review = MoneyBudgetConflictReview.capture(pending(local), listOf(server))!!
        val command = review.command()
        assertEquals("winner", (command["budget"] as MoneyBudget).id)
        assertEquals(2222L, (command["budget"] as MoneyBudget).limit.minor)
        assertEquals(4, command["expectedVersion"])
        // A later download cannot rebase an already displayed approval pair.
        val later = server.copy(version = 5, data = server.data.copy(limit = MoneyAmount(4444)))
        assertEquals(5, MoneyBudgetConflictReview.capture(pending(local), listOf(later))!!.command()["expectedVersion"])
        assertEquals(4, review.command()["expectedVersion"])
        assertEquals(3333L, review.server!!.data.limit.minor)
    }

    @Test fun missingServerBudgetRequiresReviewInsteadOfRecreatingIt() {
        val local = MoneyBudget("removed", "Food", "2026-11", MoneyAmount(2222))
        val review = MoneyBudgetConflictReview.capture(pending(local), emptyList())!!
        assertNull(review.server)
        assertThrows(MoneyApiException::class.java) { review.command() }
    }

}
