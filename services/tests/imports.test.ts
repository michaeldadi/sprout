import { describe, expect, it } from "vitest";
import {
  envelope,
  transactionImport,
  type Capabilities,
  type Transaction,
  type TransactionImport,
} from "../contracts";
import { MemoryStore } from "../domain/store";
import { execute, workspace } from "../domain/application";
import {
  applyImportChunk,
  importedTransactionId,
  importProgress,
} from "../domain/imports";
import { claim, finish, type Job } from "../domain/jobs";

const flags: Capabilities = {
  linking: false,
  cancellation: false,
  ai: false,
  forecasts: false,
  notifications: false,
  scanAssistance: false,
};
const make = (count = 45): TransactionImport =>
  transactionImport.parse({
    type: "transaction.import",
    batchId: "a".repeat(64),
    rows: Array.from({ length: count }, (_, sourceIndex) => ({
      sourceIndex,
      transaction: {
        id: importedTransactionId("a".repeat(64), sourceIndex),
        amount: { minor: -1234, currency: "USD" },
        date: "2026-11-09",
        merchant: `CSV ${sourceIndex}`,
        category: "Other",
        type: "expense",
        source: "import",
        accountId: "cash",
      },
    })),
  });
async function setup(count = 45) {
  const store = new MemoryStore(),
    batch = make(count);
  await execute(
    store,
    envelope.parse({ mutationId: "reviewed", command: batch }),
    flags,
  );
  const job = (await store.list<Job>("jobs"))[0];
  const now = new Date();
  await claim(store, job.id, "worker-one", now);
  return { store, batch, job, now };
}
describe("reviewed resumable imports", () => {
  it("resumes after a worker interruption with atomic facts and checkpoint progress", async () => {
    const { store, job, now } = await setup();
    expect(
      await applyImportChunk(store, job.id, "worker-one", now),
    ).toMatchObject({ processed: 20, imported: 20, complete: false });
    expect(await store.list("transactions")).toHaveLength(20);
    const later = new Date(now.getTime() + 241000);
    expect(await claim(store, job.id, "worker-two", later)).not.toBeNull();
    await expect(
      applyImportChunk(store, job.id, "worker-one", later),
    ).rejects.toMatchObject({ code: "LEASE_LOST" });
    expect(
      await applyImportChunk(store, job.id, "worker-two", later),
    ).toMatchObject({ processed: 40, imported: 40, complete: false });
    const result = await applyImportChunk(store, job.id, "worker-two", later);
    expect(result).toMatchObject({
      total: 45,
      processed: 45,
      imported: 45,
      preserved: 0,
      complete: true,
    });
    await finish(store, job.id, "worker-two", result);
    expect(await store.list("transactions")).toHaveLength(45);
    const saved = (await store.get<Job>("jobs", job.id))!;
    expect(saved.data.payload.rows).toBeUndefined();
    expect(importProgress(saved.data)).toEqual({
      total: 45,
      processed: 45,
      imported: 45,
      preserved: 0,
    });
  });
  it("preserves existing edits and tombstones rather than overwriting or resurrecting them", async () => {
    const store = new MemoryStore(),
      batch = make(3);
    await store.mutate("existing", "existing", async (tx) => {
      await tx.put(
        "transactions",
        batch.rows[0].transaction.id,
        {
          ...batch.rows[0].transaction,
          merchant: "User correction",
          amount: { minor: -999, currency: "USD" },
        },
        0,
      );
      await tx.put(
        "transactions",
        batch.rows[1].transaction.id,
        batch.rows[1].transaction,
        0,
      );
      await tx.remove("transactions", batch.rows[1].transaction.id, 1);
      return true;
    });
    await execute(
      store,
      envelope.parse({ mutationId: "import", command: batch }),
      flags,
    );
    const job = (await store.list<Job>("jobs"))[0];
    await claim(store, job.id, "worker");
    expect(await applyImportChunk(store, job.id, "worker")).toMatchObject({
      imported: 1,
      preserved: 2,
      complete: true,
    });
    expect(
      (
        await store.get<Transaction>(
          "transactions",
          batch.rows[0].transaction.id,
        )
      )?.data.merchant,
    ).toBe("User correction");
    expect(
      (await store.get("transactions", batch.rows[1].transaction.id))?.deleted,
    ).toBe(true);
  });
  it("deduplicates repeated reviewed batches and rejects changed consent for the same file", async () => {
    const store = new MemoryStore(),
      batch = make(3);
    const first = await execute(
      store,
      envelope.parse({ mutationId: "first", command: batch }),
      flags,
    );
    expect(
      await execute(
        store,
        envelope.parse({
          mutationId: "retry",
          command: { ...batch, rows: [...batch.rows].reverse() },
        }),
        flags,
      ),
    ).toEqual(first);
    expect(await store.list("jobs")).toHaveLength(1);
    const changed = structuredClone(batch);
    changed.rows[0].transaction.amount.minor = -2000;
    await expect(
      execute(
        store,
        envelope.parse({ mutationId: "changed", command: changed }),
        flags,
      ),
    ).rejects.toMatchObject({ code: "IMPORT_CHANGED" });
  });
  it("blocks later chunks immediately when deletion is accepted", async () => {
    const { store, job } = await setup();
    await applyImportChunk(store, job.id, "worker-one");
    await store.mutate("delete", "delete", (tx) =>
      tx.put("privacy_jobs", "current", { type: "delete" }, 0),
    );
    await expect(
      applyImportChunk(store, job.id, "worker-one"),
    ).rejects.toMatchObject({ code: "ACCOUNT_DELETING" });
    expect(await store.list("transactions")).toHaveLength(20);
    expect(
      importProgress((await store.get<Job>("jobs", job.id))!.data)?.processed,
    ).toBe(20);
  });
  it("keeps partial imports visible and suppresses transient insight claims until completion", async () => {
    const { store, job } = await setup(2);
    expect((await workspace(store, flags)).snapshot.importing).toBe(true);
    expect((await workspace(store, flags)).insights).toEqual([]);
    const result = await applyImportChunk(store, job.id, "worker-one");
    await finish(store, job.id, "worker-one", result);
    const view = await workspace(store, flags);
    expect(view.snapshot.importing).toBe(false);
    expect(view.transactions).toHaveLength(2);
  });
  it("rejects provider facts, currency and direction mismatches, duplicate rows and forged row IDs", async () => {
    for (const patch of [
      { source: "plaid" },
      { providerId: "bank-fact" },
      { amount: { minor: -1, currency: "EUR" } },
      { amount: { minor: 1, currency: "USD" } },
      { pending: true },
      { accountId: "bank-account" },
    ]) {
      const batch = make(1);
      Object.assign(batch.rows[0].transaction, patch);
      expect(transactionImport.safeParse(batch).success).toBe(false);
    }
    const duplicate = make(1);
    duplicate.rows.push(duplicate.rows[0]);
    expect(transactionImport.safeParse(duplicate).success).toBe(false);
    const forged = make(1);
    forged.rows[0].transaction.id = "another-record";
    await expect(
      execute(
        new MemoryStore(),
        envelope.parse({ mutationId: "forged", command: forged }),
        flags,
      ),
    ).rejects.toMatchObject({ code: "INVALID_REQUEST" });
  });
  it("keeps Unicode input private and bounded while committing every source row exactly once", async () => {
    const store = new MemoryStore(),
      batch = make(120);
    for (const row of batch.rows)
      row.transaction.description = "試".repeat(850 + (row.sourceIndex % 150));
    await execute(
      store,
      envelope.parse({ mutationId: "unicode", command: batch }),
      flags,
    );
    const inputs = await store.list("import_inputs");
    expect(inputs.length).toBeGreaterThan(1);
    for (const input of inputs)
      expect(Buffer.byteLength(JSON.stringify(input.data))).toBeLessThan(
        61_000,
      );
    const queued = (await store.changes(0))[0];
    expect(JSON.stringify(queued)).not.toContain("試");
    expect(Buffer.byteLength(JSON.stringify(queued))).toBeLessThan(90_000);
    const job = (await store.list<Job>("jobs"))[0];
    await claim(store, job.id, "unicode-worker");
    let previous = 0;
    while (previous < 120) {
      const result = await applyImportChunk(store, job.id, "unicode-worker");
      expect(result.processed).toBeGreaterThan(previous);
      expect(
        (await store.list("transactions")).map((r) => r.id).sort(),
      ).toEqual(
        batch.rows
          .slice(0, result.processed)
          .map((r) => r.transaction.id)
          .sort(),
      );
      previous = result.processed;
    }
    expect(await store.list("import_inputs")).toEqual([]);
    for (const event of await store.changes(0))
      expect(Buffer.byteLength(JSON.stringify(event))).toBeLessThan(90_000);
    await finish(store, job.id, "unicode-worker", { complete: true });
  });
  it("rolls back a damaged input chunk and refuses to mark an incomplete job successful", async () => {
    const { store, job } = await setup();
    await expect(finish(store, job.id, "worker-one", {})).rejects.toMatchObject(
      { code: "IMPORT_INCOMPLETE" },
    );
    const input = (await store.list<any>("import_inputs"))[0];
    await store.mutate("damage", "damage", (tx) =>
      tx.put(
        "import_inputs",
        input.id,
        { ...input.data, rows: input.data.rows.slice(1) },
        input.version,
      ),
    );
    const revision = await store.revision();
    await expect(
      applyImportChunk(store, job.id, "worker-one"),
    ).rejects.toMatchObject({ code: "IMPORT_INPUT_MISSING" });
    expect(await store.list("transactions")).toEqual([]);
    expect(await store.revision()).toBe(revision);
    expect(
      importProgress((await store.get<Job>("jobs", job.id))!.data)?.processed,
    ).toBe(0);
  });
  it("retains incomplete coverage during an exhausted retry and resumes its reviewed input", async () => {
    const { store, job } = await setup();
    await applyImportChunk(store, job.id, "worker-one");
    const current = (await store.get<Job>("jobs", job.id))!;
    await store.mutate("exhausted", "exhausted", (tx) =>
      tx.put(
        "jobs",
        job.id,
        {
          ...current.data,
          status: "needs_attention",
          attempts: 6,
          leaseToken: null,
          leaseUntil: null,
        },
        current.version,
      ),
    );
    expect((await workspace(store, flags)).snapshot.importing).toBe(true);
    await execute(
      store,
      envelope.parse({
        mutationId: "resume",
        command: { type: "transaction.import.resume", id: job.id },
      }),
      flags,
    );
    expect(await claim(store, job.id, "resumed")).not.toBeNull();
    await applyImportChunk(store, job.id, "resumed");
    const result = await applyImportChunk(store, job.id, "resumed");
    await finish(store, job.id, "resumed", result);
    expect(result).toMatchObject({ processed: 45, imported: 45, preserved: 0 });
    expect((await workspace(store, flags)).snapshot.importing).toBe(false);
  });
});
