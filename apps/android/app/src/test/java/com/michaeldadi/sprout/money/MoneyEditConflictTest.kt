package com.michaeldadi.sprout.money

import com.google.gson.Gson
import java.io.File
import org.junit.Assert.*
import org.junit.Test

class MoneyEditConflictTest {
    private fun workspace() = Gson().fromJson(File("src/debug/assets/money-workspace.json").readText(), MoneyWorkspace::class.java)
    private fun mutation(kind: String, value: Any) = MoneyMutation("local", "saved", Gson().toJson(mapOf("command" to mapOf("type" to "$kind.upsert", (if(kind=="transaction") "transaction" else "goal") to value, "expectedVersion" to 1))), conflict=true)
    @Test fun expenseApprovalUsesTheDisplayedVersionAndBothNotes() {
        val fixture=workspace(); val server=fixture.transactions.first().copy(version=4,description="Server note")
        val local=server.copy(amount=MoneyAmount(-2222),description="My note"); val pending=mutation("transaction",local.commandValue())
        val review=MoneyEditConflictReview.capture(pending,fixture.copy(transactions=listOf(server)))!!
        val later=fixture.copy(transactions=listOf(server.copy(version=5)))
        assertTrue(review.localSummary.contains("My note")); assertTrue(review.serverSummary!!.contains("Server note"))
        assertEquals(4,review.command()["expectedVersion"]); assertEquals(5,review.currentVersion(later))
        assertEquals(5,MoneyEditConflictReview.capture(pending,later)!!.serverVersion)
    }
    @Test fun missingOrDeletedGoalCannotBeRecreatedFromConflictApproval() {
        val local=MoneyGoal("goal-conflict","Reserve",MoneyAmount(50000),MoneyAmount(10000),null,false)
        val fixture=workspace().copy(goals=listOf(MoneyRecord(local.id,4,"",false,local)))
        val pending=mutation("goal",local);val review=MoneyEditConflictReview.capture(pending,fixture)!!
        val later=fixture.copy(goals=listOf(fixture.goals!!.first().copy(deleted=true)))
        assertEquals(4,review.command()["expectedVersion"]);assertNull(review.currentVersion(later))
        assertThrows(MoneyApiException::class.java) { MoneyEditConflictReview.capture(pending,later)!!.command() }
    }
    @Test fun bankFactCannotBeApprovedAsAManualReplacement() {
        val fixture=workspace();val local=fixture.transactions.first()
        val review=MoneyEditConflictReview.capture(mutation("transaction",local.commandValue()),fixture.copy(transactions=listOf(local.copy(source="plaid",providerId="bank-fact"))))!!
        assertNull(review.serverVersion);assertThrows(MoneyApiException::class.java) { review.command() }
    }
}
