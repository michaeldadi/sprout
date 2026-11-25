import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { capabilities } from "../contracts";
import { MemoryStore } from "../domain/store";
import { readSyncCursor, syncCursor, syncPage } from "../domain/sync";

describe("bounded account sync", () => {
  it("persists no-op receipts without invalidating a stable snapshot", async () => {
    const store = new MemoryStore();
    await store.mutate("seed", "seed", (tx) =>
      tx.put("insight_feedback", "one", { feedback: "dismissed" }),
    );
    const revision = await store.revision();
    expect(await store.mutate("no-op", "no-op", async () => null)).toBeNull();
    expect(
      await store.mutate("no-op", "no-op", async () => {
        throw new Error("Replayed no-op executed");
      }),
    ).toBeNull();
    expect(await store.revision()).toBe(revision);
    expect(await store.changes(revision)).toEqual([]);
  });
  beforeEach(() => {
    process.env.SPROUT_SYNC_CURSOR_KEY = Buffer.alloc(32, 9).toString("base64");
  });
  afterEach(() => {
    delete process.env.SPROUT_SYNC_CURSOR_KEY;
  });
  it("rejects tampering, another account, expiry and future revisions", async () => {
    const now = new Date("2026-11-09T12:00:00Z");
    const cursor = syncCursor("alice", 0, null, now);
    expect(() => readSyncCursor("bob", cursor, now)).toThrow();
    expect(() => readSyncCursor("alice", cursor + "x", now)).toThrow();
    expect(() =>
      readSyncCursor("alice", cursor, new Date("2026-12-10")),
    ).toThrow();
    await expect(
      syncPage(
        new MemoryStore(),
        "alice",
        capabilities(),
        syncCursor("alice", 1),
      ),
    ).rejects.toMatchObject({ code: "CURSOR_INVALID" });
  });
  it("keeps the initial projection and all pages at the same revision while newer changes wait", async () => {
    const store = new MemoryStore();
    for (let i = 0; i < 55; i++)
      await store.mutate(`seed-${i}`, String(i), (tx) =>
        tx.put("insight_feedback", String(i), { feedback: "dismissed" }),
      );
    const first = await syncPage(
      store,
      "alice",
      capabilities(),
      syncCursor("alice", 0),
    );
    expect(first.projection?.revision).toBe(55);
    expect(first.events).toHaveLength(50);
    expect(first.events.every((e) => e.changes.length === 0)).toBe(true);
    expect(first.hasMore).toBe(true);
    await store.mutate("new", "new", (tx) =>
      tx.put("profiles", "current", { monthlyTargetMinor: 12000 }),
    );
    const second = await syncPage(
      store,
      "alice",
      capabilities(),
      first.nextCursor,
    );
    expect(second.projection).toBeNull();
    expect(second.throughRevision).toBe(55);
    expect(second.events.map((e) => e.sequence)).toEqual([51, 52, 53, 54, 55]);
    expect(second.hasMore).toBe(false);
    const next = await syncPage(
      store,
      "alice",
      capabilities(),
      second.nextCursor,
    );
    expect(next.throughRevision).toBe(56);
    expect((next.projection?.profile as any).monthlyTargetMinor).toBe(12000);
    const idle = await syncPage(
      store,
      "alice",
      capabilities(),
      next.nextCursor,
    );
    expect(idle.unchanged).toBe(true);
  });
  it("carries transaction tombstones and never exposes private operational payloads", async () => {
    const store = new MemoryStore();
    await store.mutate("create", "1", (tx) =>
      tx.put("transactions", "expense", {
        amount: { minor: -29, currency: "USD" },
        date: "2026-11-09",
        merchant: "Coffee",
        category: "Food",
        type: "expense",
        source: "manual",
        excluded: false,
      }),
    );
    const cursor = syncCursor("alice", 1);
    await store.mutate("delete", "2", async (tx) => {
      await tx.remove("transactions", "expense", 1);
      await tx.put("jobs", "private", { secret: "not-for-sync" });
    });
    const page = await syncPage(store, "alice", capabilities(), cursor);
    expect(page.events[0].changes).toHaveLength(1);
    expect(page.events[0].changes[0].record).toMatchObject({
      id: "expense",
      version: 2,
      deleted: true,
    });
    expect(JSON.stringify(page)).not.toContain("not-for-sync");
  });
});

it("refreshes time-dependent projections without a financial mutation", async () => {
  process.env.SPROUT_SYNC_CURSOR_KEY = Buffer.alloc(32, 7).toString("base64");
  try {
    const store = new MemoryStore();
    const start = new Date("2026-11-09T23:59:00Z");
    const flags = {
      linking: false,
      cancellation: false,
      ai: false,
      forecasts: false,
      notifications: false,
      scanAssistance: false,
    };
    const cursor = syncCursor("alice", 0, null, start);
    const page = await syncPage(
      store,
      "alice",
      flags,
      cursor,
      new Date(start.getTime() + 301000),
    );
    expect(page.unchanged).toBe(false);
    expect(page.events).toEqual([]);
    expect(page.projection?.revision).toBe(0);
    expect(page.projection?.projectionVersion).toBe(3);
  } finally {
    delete process.env.SPROUT_SYNC_CURSOR_KEY;
  }
});
