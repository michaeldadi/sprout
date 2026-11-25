import { afterEach, describe, expect, it } from "vitest";
import {
  sealToken,
  openToken,
  PlaidClient,
  bankFact,
} from "../integrations/plaid";
import { MemoryStore } from "../domain/store";
import { schedule, claim, finish } from "../domain/jobs";
import { parseExpenseText, budgetSummary, forecast } from "../domain/finance";
import { transaction } from "../contracts";
import { readFileSync } from "node:fs";
import path from "node:path";
const cases: { text: string; amountMinor: number | null }[] = JSON.parse(
  readFileSync(
    path.resolve(__dirname, "../../design/fixtures/expense-text.json"),
    "utf8",
  ),
);

describe("provider boundaries and durable jobs", () => {
  it("does not reschedule work stopped by accepted deletion", async () => {
    const store = new MemoryStore();
    const job = await store.mutate("queued", "queued", (tx) =>
      schedule(tx, "bank.sync", "bank", {}),
    );
    await claim(store, job.id, "lease");
    await finish(store, job.id, "lease", null, "ACCOUNT_DELETING");
    expect((await store.get<any>("jobs", job.id))?.data.status).toBe("failed");
    expect(
      await claim(
        store,
        job.id,
        "another-lease",
        new Date(Date.now() + 3_600_000),
      ),
    ).toBeNull();
  });
  it("clears a previous retry error after successful recovery", async () => {
    const store = new MemoryStore();
    const started = new Date("2026-11-09T12:00:00Z");
    const job = await store.mutate("queued", "queued", (tx) =>
      schedule(tx, "privacy.export", "export", {}, started),
    );
    await claim(store, job.id, "first", started);
    await finish(store, job.id, "first", null, "EXPORT_CHANGED", started);
    const later = new Date(started.getTime() + 120_000);
    await claim(store, job.id, "second", later);
    await finish(
      store,
      job.id,
      "second",
      { status: "ready" },
      undefined,
      later,
    );
    const finished = (await store.get<any>("jobs", job.id))!.data;
    expect(finished.status).toBe("succeeded");
    expect(finished.error).toBeUndefined();
    expect(finished.result).toEqual({ status: "ready" });
  });
  afterEach(() => {
    delete process.env.SPROUT_TOKEN_KEY_1;
    delete process.env.PLAID_CLIENT_ID;
    delete process.env.PLAID_SECRET;
    delete process.env.PLAID_ENVIRONMENT;
  });
  it("binds encrypted credentials to their user and connection and detects tampering", () => {
    process.env.SPROUT_TOKEN_KEY_1 = Buffer.alloc(32, 7).toString("base64");
    const sealed = sealToken("private-token", "alice", "one");
    expect(sealed).not.toContain("private-token");
    expect(openToken(sealed, "alice", "one")).toBe("private-token");
    expect(() => openToken(sealed, "bob", "one")).toThrow();
    expect(() => openToken(sealed, "alice", "two")).toThrow();
    const parts = sealed.split(".");
    parts[2] = Buffer.from("changed").toString("base64");
    expect(() => openToken(parts.join("."), "alice", "one")).toThrow();
  });
  it("restarts the entire Plaid pagination cycle from its original cursor", async () => {
    process.env.PLAID_CLIENT_ID = "fictional";
    process.env.PLAID_SECRET = "fictional";
    process.env.PLAID_ENVIRONMENT = "sandbox";
    const cursors: unknown[] = [];
    let index = 0;
    const transport = async (_url: unknown, request: any) => {
      cursors.push(JSON.parse(request.body).cursor);
      const values = [
        {
          added: [],
          modified: [],
          removed: [],
          has_more: true,
          next_cursor: "mid",
        },
        { error_code: "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION" },
        {
          added: [],
          modified: [],
          removed: [],
          has_more: false,
          next_cursor: "complete",
        },
      ];
      return new Response(JSON.stringify(values[index]), {
        status: index++ === 1 ? 400 : 200,
      });
    };
    expect(
      (
        await new PlaidClient(transport as typeof fetch).syncCycle(
          "fictional",
          "original",
        )
      ).cursor,
    ).toBe("complete");
    expect(cursors).toEqual(["original", "mid", "original"]);
  });
  it("classifies credit card payment cash movement separately from purchases and refunds", () => {
    const base = {
      transaction_id: "t",
      account_id: "a",
      date: "2026-11-09",
      amount: 25,
      iso_currency_code: "USD",
      name: "Merchant",
      pending: false,
    };
    expect(
      bankFact(
        {
          ...base,
          personal_finance_category: {
            primary: "LOAN_PAYMENTS",
            detailed: "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT",
          },
        },
        "c",
      ).type,
    ).toBe("transfer");
    expect(
      bankFact(
        {
          ...base,
          amount: -25,
          personal_finance_category: {
            primary: "GENERAL_MERCHANDISE",
            detailed: "GENERAL_MERCHANDISE_OTHER",
          },
        },
        "c",
      ).type,
    ).toBe("refund");
  });
  it("deduplicates scheduling, admits one lease holder, and rejects a stale completion", async () => {
    const store = new MemoryStore();
    const due = new Date("2026-11-01");
    const a = await store.mutate("schedule", "same", (tx) =>
      schedule(tx, "bank.sync", "connection", { connectionId: "one" }, due),
    );
    const b = await store.mutate("repeat", "again", (tx) =>
      schedule(tx, "bank.sync", "connection", { connectionId: "one" }, due),
    );
    expect(a.id).toBe(b.id);
    const results = await Promise.all([
      claim(store, a.id, "first"),
      claim(store, a.id, "second"),
    ]);
    expect(results.filter(Boolean)).toHaveLength(1);
    await expect(finish(store, a.id, "wrong", {})).rejects.toMatchObject({
      code: "LEASE_LOST",
    });
    await finish(store, a.id, "first", { cursor: "next" });
    expect((await store.get<any>("jobs", a.id))?.data.status).toBe("succeeded");
  });
  it.each(cases)("keeps capture ambiguity for $text", (row) => {
    expect(parseExpenseText(row.text).amountMinor).toBe(row.amountMinor);
  });
  it("nets refunds without counting card payments as spending", () => {
    const base = {
      merchant: "Store",
      category: "Shopping",
      date: "2026-11-09",
      source: "manual",
    };
    const rows = [
      transaction.parse({
        ...base,
        id: "buy",
        type: "expense",
        amount: { minor: -10000, currency: "USD" },
      }),
      transaction.parse({
        ...base,
        id: "refund",
        type: "refund",
        amount: { minor: 2500, currency: "USD" },
      }),
      transaction.parse({
        ...base,
        id: "payment",
        type: "transfer",
        amount: { minor: -10000, currency: "USD" },
      }),
    ];
    expect(budgetSummary(rows, [], "2026-11-09").spentMinor).toBe(7500);
  });
  it("does not double-count scheduled charges in its historical spending baseline", () => {
    const start = Date.parse("2026-11-09T00:00:00Z");
    const transactions = Array.from({ length: 60 }, (_, i) =>
      transaction.parse({
        id: `daily-${i}`,
        date: new Date(start - (i + 1) * 86400000).toISOString().slice(0, 10),
        amount: { minor: -1000, currency: "USD" },
        merchant: "Variable",
        category: "Other",
        type: "expense",
        source: "manual",
      }),
    );
    transactions.push(
      transaction.parse({
        id: "bill",
        date: "2026-11-01",
        amount: { minor: -100000, currency: "USD" },
        merchant: "Rent",
        category: "Bills",
        type: "expense",
        source: "manual",
      }),
    );
    const result = forecast({
      balanceMinor: 200000,
      balanceAsOf: "2026-11-09",
      asOf: "2026-11-09T12:00:00Z",
      today: "2026-11-09",
      coverageComplete: true,
      historyCoverage: {fromDate: "2026-09-14", throughDate: "2026-11-08", accountIds: ["cash"]},
      transactions,
      commitments: [
        { date: "2026-11-10", minor: -100000, historicalEvidenceIds: ["bill"] },
      ],
      horizon: 7,
    });
    expect(result.eligible && result.expectedMinor).toBe(93000);
  });
});
