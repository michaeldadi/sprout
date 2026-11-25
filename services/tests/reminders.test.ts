import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { profile, transaction } from "../contracts";
import { MemoryStore } from "../domain/store";
import { detectRecurring } from "../domain/finance";
import { claim, type Job } from "../domain/jobs";
import {
  planReminder,
  reconcileReminders,
  requestReminderPlan,
  renewalOccurrence,
  type ReminderRule,
} from "../domain/reminders";

const now = new Date("2026-11-10T17:00:00Z");
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(now);
});
afterEach(() => vi.useRealTimers());
async function setup() {
  const store = new MemoryStore();
  await store.mutate("seed", "seed", async (tx) => {
    await tx.put(
      "profiles",
      "current",
      profile.parse({ renewalAlerts: true, timezone: "America/New_York" }),
      0,
    );
    for (const [i, date] of [
      "2026-09-08",
      "2026-10-08",
      "2026-11-08",
    ].entries())
      await tx.put(
        "transactions",
        `charge-${i}`,
        transaction.parse({
          id: `charge-${i}`,
          amount: { minor: -1299, currency: "USD" },
          date,
          merchant: "Stream",
          category: "Other",
          type: "expense",
          source: "manual",
        }),
        0,
      );
    return true;
  });
  const stream = detectRecurring(
    (await store.list<any>("transactions")).map((r) => r.data),
  )[0];
  const plan = async (
    id: string,
    options?: { enabled: boolean; daysBefore: number },
  ) =>
    store.mutate(id, id, (tx) =>
      planReminder(tx, stream.id, options, new Date()),
    );
  return { store, stream, plan };
}
it("reschedules changed charge evidence, supersedes the old occurrence and never fabricates a later cycle", async () => {
  const { store, stream, plan } = await setup();
  const first = (await plan("first", { enabled: true, daysBefore: 1 }))!;
  expect((await store.get<Job>("jobs", first.data.jobId!))?.data.dueAt).toBe(
    "2026-12-07T14:00:00.000Z",
  );
  vi.setSystemTime(new Date("2026-12-09T17:00:00Z"));
  await store.mutate("new-charge", "new-charge", (tx) =>
    tx.put(
      "transactions",
      "charge-3",
      transaction.parse({
        id: "charge-3",
        amount: { minor: -1299, currency: "USD" },
        date: "2026-12-08",
        merchant: "Stream",
        category: "Other",
        type: "expense",
        source: "manual",
      }),
      0,
    ),
  );
  const second = (await plan("next-cycle"))!;
  expect(second.data.renewalDate).toBe("2027-01-08");
  expect(second.data.jobId).not.toBe(first.data.jobId);
  expect((await store.get<Job>("jobs", first.data.jobId!))?.data).toMatchObject(
    { status: "failed", error: "superseded" },
  );
  vi.setSystemTime(new Date("2027-01-09T17:00:00Z"));
  // An expired estimate is not advanced by inventing an unobserved charge.
  const stale = (await plan("stale"))!;
  expect(stale.data.renewalDate).toBe("2027-01-08");
  expect(stale.data.status).toBe("needs_review");
  expect(stale.data.jobId).toBeNull();
});
it("updates quiet hours and timezone, and keeps a globally muted topic off", async () => {
  const { store, plan } = await setup();
  await plan("first", { enabled: true, daysBefore: 1 });
  await store.mutate("preferences", "preferences", (tx) =>
    tx.put(
      "profiles",
      "current",
      profile.parse({
        renewalAlerts: true,
        timezone: "America/Los_Angeles",
        quietHours: { enabled: true, startMinute: 480, endMinute: 600 },
      }),
      1,
    ),
  );
  const shifted = (await plan("shifted"))!;
  expect((await store.get<Job>("jobs", shifted.data.jobId!))?.data.dueAt).toBe(
    "2026-12-07T18:00:00.000Z",
  );
  await store.mutate("mute", "mute", (tx) =>
    tx.put("profiles", "current", profile.parse({ renewalAlerts: false }), 2),
  );
  const muted = (await plan("muted"))!;
  expect(muted.data).toMatchObject({
    enabled: true,
    status: "muted",
    jobId: null,
  });
  expect((await store.get<Job>("jobs", shifted.data.jobId!))?.data.status).toBe(
    "failed",
  );
});
it("cancels dismissed streams and waits for complete ingestion before scheduling", async () => {
  const { store, stream, plan } = await setup();
  const first = (await plan("first", { enabled: true, daysBefore: 1 }))!;
  await store.mutate("importing", "importing", (tx) =>
    tx.put("connections", "bank", { status: "importing" }, 0),
  );
  const partial = (await plan("partial"))!;
  expect(partial.data).toMatchObject({
    enabled: true,
    status: "awaiting_data",
    jobId: null,
  });
  expect((await store.get<Job>("jobs", first.data.jobId!))?.data.status).toBe(
    "failed",
  );
  await store.mutate("dismiss", "dismiss", async (tx) => {
    await tx.put("connections", "bank", { status: "ready" }, 1);
    await tx.put(
      "recurring_decisions",
      stream.id,
      { decision: "dismissed" },
      0,
    );
    return true;
  });
  expect((await plan("dismissed"))?.data).toMatchObject({
    status: "needs_review",
    jobId: null,
  });
});
it("does not create another delivery for an accepted renewal when the rule changes", async () => {
  const { store, stream, plan } = await setup();
  await plan("first", { enabled: true, daysBefore: 1 });
  await store.mutate("accepted", "accepted", (tx) =>
    tx.put(
      "notifications",
      renewalOccurrence(stream.id, stream.nextDate),
      { status: "accepted", providerReference: "synthetic" },
      0,
    ),
  );
  const changed = (await plan("changed", { enabled: true, daysBefore: 3 }))!;
  expect(changed.data).toMatchObject({
    enabled: true,
    status: "accepted",
    jobId: null,
  });
});
it("coalesces changes and fences a bounded planner with its live claim", async () => {
  const { store, stream, plan } = await setup();
  await plan("first", { enabled: true, daysBefore: 1 });
  const queued = await store.mutate("queue", "queue", (tx) =>
    requestReminderPlan(tx, new Date()),
  );
  const repeated = await store.mutate("again", "again", (tx) =>
    requestReminderPlan(tx, new Date()),
  );
  expect(repeated?.id).toBe(queued?.id);
  vi.setSystemTime(new Date("2026-11-10T17:05:00Z"));
  await claim(store, queued!.id, "planner");
  await expect(
    reconcileReminders(store, queued!.id, "stale"),
  ).rejects.toMatchObject({ code: "LEASE_LOST" });
  expect(await reconcileReminders(store, queued!.id, "planner")).toEqual({
    rules: 1,
  });
  const daily = (await store.list<Job>("jobs")).filter(
    (r) => r.data.type === "notification.plan" && r.id !== queued!.id,
  );
  expect(daily).toHaveLength(1);
  expect(daily[0].data.dueAt).toBe("2026-11-11T14:00:00.000Z");
  expect(
    (await store.get<ReminderRule>("reminders", stream.id))?.data.enabled,
  ).toBe(true);
});
