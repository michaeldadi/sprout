import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryStore } from "../domain/store";
import { transaction } from "../contracts";
import { detectRecurring, fingerprint } from "../domain/finance";
import { schedule, type Job } from "../domain/jobs";
import { planReminder } from "../domain/reminders";
import { planWeeklyReview, queueWeeklyReview } from "../domain/weekly";
const mocks = vi.hoisted(() => ({
  store: null as unknown as MemoryStore,
  deliver: vi.fn(),
  weekly: vi.fn(),
}));
vi.mock("../integrations/appwrite-store", () => ({
  AppwriteStore: class {
    constructor() {
      return Object.assign(mocks.store, {
        assertWritable: async () => undefined,
      });
    }
  },
}));
vi.mock("../integrations/notifications", () => ({
  deliverReminder: mocks.deliver,
  deliverWeeklyReview: mocks.weekly,
}));
import worker from "../functions/worker";

describe("notification execution boundary", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-11-10T17:00:00Z"));
    mocks.store = new MemoryStore();
    mocks.deliver.mockReset();
    mocks.weekly.mockReset();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "false");
  });
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });
  async function queued() {
    return mocks.store.mutate("setup", "setup", async (tx) => {
      await tx.put(
        "profiles",
        "current",
        { renewalAlerts: true, timezone: "America/New_York" },
        0,
      );
      const facts = ["2026-09-08", "2026-10-08", "2026-11-08"].map(
        (date, index) =>
          transaction.parse({
            id: `charge-${index}`,
            amount: { minor: -1299, currency: "USD" },
            date,
            merchant: "Stream",
            category: "Subscriptions",
            type: "expense",
            source: "manual",
          }),
      );
      for (const fact of facts) await tx.put("transactions", fact.id, fact, 0);
      const stream = detectRecurring(facts)[0];
      const rule = (await planReminder(tx, stream.id, {
        enabled: true,
        daysBefore: 1,
      }))!;
      const job = (await tx.get<Job>("jobs", rule.data.jobId!))!;
      // Exercise the delivery boundary now; calendar correctness is tested
      // independently with real due dates in reminders.test.ts.
      await tx.put(
        "jobs",
        job.id,
        { ...job.data, dueAt: new Date(0).toISOString() },
        job.version,
      );
      return job.id;
    });
  }
  function run(id: string) {
    return worker({
      req: {
        path: "/",
        method: "POST",
        headers: { "x-appwrite-key": "fictional" },
        bodyText: JSON.stringify({ owner: "alice", jobId: id }),
      },
      res: { json: (body, status = 200) => ({ body, status }) },
    });
  }
  async function weeklyQueued(manual = false) {
    return mocks.store.mutate("weekly-setup", "weekly-setup", async (tx) => {
      await tx.put(
        "profiles",
        "current",
        { weeklyDigest: !manual, timezone: "America/New_York" },
        0,
      );
      await tx.put(
        "transactions",
        "weekly-expense",
        transaction.parse({
          id: "weekly-expense",
          date: "2026-11-08",
          amount: { minor: -1200, currency: "USD" },
          merchant: "Public weekly fixture",
          category: "Other",
          type: "expense",
          source: "manual",
        }),
        0,
      );
      return manual
        ? (await queueWeeklyReview(tx, new Date())).id
        : (await planWeeklyReview(tx, new Date("2026-11-03T17:00:00Z")))!.id;
    });
  }
  it("preserves a prepared weekly review while delivery is paused without spending retry attempts", async () => {
    const id = await weeklyQueued();
    await run(id);
    expect(mocks.weekly).not.toHaveBeenCalled();
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data).toMatchObject({
      status: "retry",
      attempts: 0,
      error: "DELIVERY_PAUSED",
    });
    expect(
      (await mocks.store.list<any>("notifications"))[0].data,
    ).toMatchObject({
      status: "prepared",
      review: { netSpendingMinor: 1200, scope: "available_history" },
    });
  });
  it("records weekly acceptance once, retains its evidence and never claims confirmed delivery", async () => {
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    mocks.weekly.mockResolvedValue({
      status: "accepted",
      providerReference: "weekly-reference",
      delivered: false,
    });
    const id = await weeklyQueued();
    await run(id);
    await run(id);
    expect(mocks.weekly).toHaveBeenCalledOnce();
    expect(
      (await mocks.store.list<any>("notifications"))[0].data,
    ).toMatchObject({
      status: "accepted",
      delivered: false,
      review: { netSpendingMinor: 1200 },
    });
  });
  it("prepares a requested review without calling either notification provider path", async () => {
    const id = await weeklyQueued(true);
    await run(id);
    expect(mocks.weekly).not.toHaveBeenCalled();
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data).toMatchObject({
      status: "succeeded",
      result: { status: "prepared", delivered: false },
    });
  });
  it("retains an occurrence for recovery and contacts no provider when the server flag is disabled", async () => {
    const id = await queued();
    await run(id);
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data).toMatchObject({
      status: "retry",
      error: "DELIVERY_PAUSED",
      attempts: 0,
    });
    expect(await mocks.store.list("notifications")).toEqual([]);
  });
  it("records provider acceptance without claiming delivery", async () => {
    const id = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    mocks.deliver.mockResolvedValue({
      providerReference: "accepted-reference",
      status: "accepted",
      delivered: false,
    });
    await run(id);
    const stream = detectRecurring(
      (await mocks.store.list<any>("transactions")).map((r) => r.data),
    )[0];
    const occurrenceId = fingerprint([
      "renewal",
      stream.id,
      stream.nextDate,
    ]).slice(0, 36);
    expect(mocks.deliver).toHaveBeenCalledExactlyOnceWith(
      "alice",
      occurrenceId,
    );
    expect((await mocks.store.get<Job>("jobs", id))?.data.status).toBe(
      "succeeded",
    );
    expect(
      (await mocks.store.get("notifications", occurrenceId))?.data,
    ).toMatchObject({
      status: "accepted",
      delivered: false,
      providerReference: "accepted-reference",
    });
  });
  it("defers quiet hours without a provider call or consuming a delivery attempt", async () => {
    const id = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    vi.setSystemTime(new Date("2026-11-11T03:00:00Z"));
    await run(id);
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data).toMatchObject({
      status: "retry",
      attempts: 0,
      dueAt: "2026-11-11T13:00:00.000Z",
      error: "QUIET_HOURS",
      leaseToken: null,
    });
  });
  it("honors the renewal topic opt-out even if an occurrence was already queued", async () => {
    const id = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    await mocks.store.mutate("mute", "mute", (tx) =>
      tx.put("profiles", "current", { renewalAlerts: false }, 1),
    );
    await run(id);
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data).toMatchObject({
      status: "succeeded",
      result: { status: "muted", delivered: false },
    });
    expect((await mocks.store.list<any>("reminders"))[0].data.status).toBe(
      "muted",
    );
  });
  it("does not resend an accepted renewal after a reminder rule is changed", async () => {
    const first = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    mocks.deliver.mockResolvedValue({
      providerReference: "accepted-once",
      status: "accepted",
      delivered: false,
    });
    await run(first);
    const stream = detectRecurring(
      (await mocks.store.list<any>("transactions")).map((r) => r.data),
    )[0];
    const next = await mocks.store.mutate(
      "change-rule",
      "change-rule",
      async (tx) => {
        const old = (await tx.get<any>("reminders", stream.id))!;
        const job = await schedule(
          tx,
          "reminder.deliver",
          "changed-rule",
          { subscriptionId: stream.id, evidenceHash: stream.evidenceHash },
          new Date(0),
        );
        await tx.put(
          "reminders",
          old.id,
          { ...old.data, jobId: job.id },
          old.version,
        );
        return job.id;
      },
    );
    await run(next);
    expect(mocks.deliver).toHaveBeenCalledTimes(1);
    expect((await mocks.store.get<Job>("jobs", next))?.data.result).toEqual({
      status: "already_accepted",
      delivered: false,
    });
  });
  it("rechecks expired renewal evidence before contacting the delivery provider", async () => {
    const id = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    vi.setSystemTime(new Date("2026-12-09T17:00:00Z"));
    await run(id);
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data.result).toEqual({
      status: "needs_review",
      delivered: false,
    });
    expect((await mocks.store.list<any>("reminders"))[0].data).toMatchObject({
      status: "needs_review",
      jobId: null,
    });
  });
  it("waits for a complete bank import instead of delivering from partial evidence", async () => {
    const id = await queued();
    vi.stubEnv("SPROUT_NOTIFICATIONS", "true");
    await mocks.store.mutate("importing", "importing", (tx) =>
      tx.put("connections", "bank", { status: "importing" }, 0),
    );
    await run(id);
    expect(mocks.deliver).not.toHaveBeenCalled();
    expect((await mocks.store.get<Job>("jobs", id))?.data.result).toEqual({
      status: "awaiting_data",
      delivered: false,
    });
  });
});
