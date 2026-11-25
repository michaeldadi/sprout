import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { profile, transaction } from "../contracts";
import { MemoryStore } from "../domain/store";
import { claim, type Job } from "../domain/jobs";
import {
  planWeeklyReview,
  prepareWeeklyReview,
  queueWeeklyReview,
} from "../domain/weekly";
import { requestReminderPlan } from "../domain/reminders";
import { workspace } from "../domain/application";
const monday = new Date("2026-11-16T14:00:00Z");
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(monday);
});
afterEach(() => vi.useRealTimers());
async function setup() {
  const store = new MemoryStore();
  const job = await store.mutate("seed", "seed", async (tx) => {
    await tx.put(
      "profiles",
      "current",
      profile.parse({ weeklyDigest: true }),
      0,
    );
    for (const [id, type, minor, extra] of [
      ["expense", "expense", -2200, {}],
      ["refund", "refund", 200, {}],
      ["pay", "income", 10000, {}],
      ["transfer", "transfer", -10000, {}],
      ["pending", "expense", -5000, { pending: true }],
      ["excluded", "expense", -5000, { excluded: true }],
    ] as const) {
      const value = transaction.parse({
        id,
        type,
        amount: { minor, currency: "USD" },
        merchant: "Public fixture",
        date: "2026-11-12",
        category: "Other",
        source: "manual",
        ...extra,
      });
      await tx.put("transactions", id, value, 0);
    }
    return (await planWeeklyReview(tx, new Date("2026-11-10T17:00:00Z")))!;
  });
  await claim(store, job.id, "claim", monday);
  return { store, job };
}
it("schedules one weekly review without requiring a renewal rule", async () => {
  const store = new MemoryStore();
  await store.mutate("plan", "plan", async (tx) => {
    await tx.put(
      "profiles",
      "current",
      profile.parse({ weeklyDigest: true, timezone: "America/New_York" }),
      0,
    );
    expect(await requestReminderPlan(tx)).not.toBeNull();
    const first = (await planWeeklyReview(
        tx,
        new Date("2026-10-27T12:00:00Z"),
      ))!,
      second = (await planWeeklyReview(tx, new Date("2026-10-28T12:00:00Z")))!;
    expect(first.id).toBe(second.id);
    expect(first.data.dueAt).toBe("2026-11-02T14:00:00.000Z");
    expect(first.data.payload.week).toBe("2026-11-02");
  });
});
it("persists an evidence-bound available-history review and reuses it after facts change", async () => {
  const { store, job } = await setup();
  const result = await prepareWeeklyReview(store, job.id, "claim", monday);
  expect(result.status).toBe("ready");
  if (result.status !== "ready") throw Error("Review missing");
  expect(result.review).toMatchObject({
    week: "2026-11-16",
    fromDate: "2026-11-09",
    throughDate: "2026-11-15",
    netSpendingMinor: 2000,
    incomeMinor: 10000,
    transactionCount: 3,
    scope: "available_history",
    accountIds: ["cash"],
    evidenceIds: ["expense", "pay", "refund"],
  });
  await store.mutate("changed", "changed", (tx) =>
    tx.remove("transactions", "expense", 1),
  );
  const retryAt = new Date(monday.getTime() + 300_000);
  vi.setSystemTime(retryAt);
  await claim(store, job.id, "retry", retryAt);
  const repeated = await prepareWeeklyReview(store, job.id, "retry", retryAt);
  expect(repeated).toMatchObject({ review: result.review });
  const view = await workspace(
    store,
    {
      linking: false,
      ai: false,
      forecasts: false,
      notifications: false,
      cancellation: false,
      scanAssistance: false,
    },
    monday,
  );
  expect(
    view.insights.some(
      (i) =>
        i.id === result.occurrenceId &&
        i.kind === "weekly" &&
        i.detail.includes("Available history"),
    ),
  ).toBe(true);
});
it("does not prepare during incomplete ingestion or from an expired claim", async () => {
  const { store, job } = await setup();
  await store.mutate("partial", "partial", (tx) =>
    tx.put("connections", "bank", { status: "importing" }, 0),
  );
  expect(await prepareWeeklyReview(store, job.id, "claim", monday)).toEqual({
    status: "incomplete",
  });
  expect(await store.list("notifications")).toEqual([]);
  await expect(
    prepareWeeklyReview(store, job.id, "stale", monday),
  ).rejects.toMatchObject({ code: "LEASE_LOST" });
});
it("honors opt-out and discards obsolete preferences and missed weeks", async () => {
  const { store, job } = await setup();
  await store.mutate("disable", "disable", (tx) =>
    tx.put("profiles", "current", profile.parse({ weeklyDigest: false }), 1),
  );
  expect(await prepareWeeklyReview(store, job.id, "claim", monday)).toEqual({
    status: "muted",
  });
  await store.mutate("enable", "enable", (tx) =>
    tx.put(
      "profiles",
      "current",
      profile.parse({ weeklyDigest: true, timezone: "America/Los_Angeles" }),
      2,
    ),
  );
  const retryAt = new Date(monday.getTime() + 300_000);
  vi.setSystemTime(retryAt);
  await claim(store, job.id, "retry", retryAt);
  expect(await prepareWeeklyReview(store, job.id, "retry", retryAt)).toEqual({
    status: "superseded",
  });
  expect(await store.list("notifications")).toEqual([]);
});

it("does not cancel a due review when an unrelated profile field changes", async () => {
  const { store, job } = await setup();
  await store.mutate("name", "name", (tx) =>
    tx.put(
      "profiles",
      "current",
      profile.parse({ weeklyDigest: true, name: "Updated display name" }),
      1,
    ),
  );
  expect(
    await prepareWeeklyReview(store, job.id, "claim", monday),
  ).toMatchObject({ status: "ready" });
});

it("drops missed review weeks rather than sending a backlog", async () => {
  const { store, job } = await setup();
  await store.mutate("old-week", "old-week", async (tx) => {
    const current = (await tx.get<Job>("jobs", job.id))!;
    await tx.put(
      "jobs",
      job.id,
      {
        ...current.data,
        payload: { ...current.data.payload, week: "2026-11-02" },
      },
      current.version,
    );
  });
  expect(await prepareWeeklyReview(store, job.id, "claim", monday)).toEqual({
    status: "superseded",
  });
  expect(await store.list("notifications")).toEqual([]);
});

it("prepares a requested review without opting into notifications and coalesces repeat requests", async () => {
  const { store } = await setup();
  let id = "";
  await store.mutate("manual", "manual", async (tx) => {
    await tx.put(
      "profiles",
      "current",
      profile.parse({ weeklyDigest: false }),
      1,
    );
    const first = await queueWeeklyReview(tx, monday),
      second = await queueWeeklyReview(tx, monday);
    expect(first.id).toBe(second.id);
    id = first.id;
  });
  await claim(store, id, "manual-claim", monday);
  expect(
    await prepareWeeklyReview(store, id, "manual-claim", monday),
  ).toMatchObject({ status: "ready", review: { netSpendingMinor: 2000 } });
  expect((await store.get<any>("profiles", "current"))?.data.weeklyDigest).toBe(
    false,
  );
});
