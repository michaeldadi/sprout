import { describe, expect, it } from "vitest";
import { MemoryStore } from "../domain/store";
import { execute, workspace } from "../domain/application";
import {
  envelope,
  profile,
  transaction,
  type Capabilities,
} from "../contracts";
import { detectRecurring } from "../domain/finance";
import type { Job } from "../domain/jobs";
const flags: Capabilities = {
  linking: false,
  cancellation: false,
  ai: false,
  forecasts: false,
  notifications: false,
  scanAssistance: false,
};
const make = (mutationId: string, expectedVersion = 0, minor = -2900) =>
  envelope.parse({
    mutationId,
    command: {
      type: "transaction.upsert",
      expectedVersion,
      transaction: {
        id: "lunch",
        amount: { minor, currency: "USD" },
        date: "2026-11-09",
        merchant: "Lunch",
        category: "Food",
        type: "expense",
        source: "manual",
      },
    },
  });
describe("transaction and account boundaries", () => {
  it("links budget advice only to the posted facts used by the normalized category calculation", async () => {
    const store = new MemoryStore();
    await store.mutate("budget-evidence-fixture", "fixture", async tx => {
      await tx.put("budgets", "food", {id: "food", category: "FOOD", month: "2026-11", limit: {minor: 10000, currency: "USD"}}, 0);
      for (const [id, patch] of Object.entries({
        posted: {}, refund: {type: "refund", amount: {minor: 500, currency: "USD"}},
        pending: {pending: true}, excluded: {excluded: true},
        transfer: {type: "transfer"}, income: {type: "income", amount: {minor: 10000, currency: "USD"}},
        prior: {date: "2026-10-10"},
      })) await tx.put("transactions", id, transaction.parse({id, merchant: "Fixture", category: " food ", date: "2026-11-10", type: "expense", source: "manual", amount: {minor: -8000, currency: "USD"}, ...patch}), 0);
    });
    const result = await workspace(store, flags, new Date("2026-11-10T12:00:00Z"));
    expect(result.snapshot.budget.spentMinor).toBe(7500);
    expect(result.insights).toHaveLength(1);
    expect(result.insights[0].evidenceIds.sort()).toEqual(["posted", "refund"]);
  });
  it("preserves notification preferences omitted by an older client while honoring explicit opt-outs", async () => {
    const store = new MemoryStore();
    const initial = profile.parse({
      name: "Saved",
      budgetAlerts: true,
      forecastAlerts: true,
      quietHours: { enabled: true, startMinute: 1260, endMinute: 480 },
    });
    await execute(
      store,
      envelope.parse({
        mutationId: "new-preferences",
        command: {
          type: "profile.update",
          expectedVersion: 0,
          profile: initial,
        },
      }),
      flags,
    );
    await execute(
      store,
      envelope.parse({
        mutationId: "old-client",
        command: {
          type: "profile.update",
          expectedVersion: 1,
          profile: profile.parse({ name: "Changed" }),
        },
      }),
      flags,
    );
    expect((await store.get<any>("profiles", "current"))?.data).toMatchObject({
      name: "Changed",
      budgetAlerts: true,
      forecastAlerts: true,
      quietHours: initial.quietHours,
    });
    await execute(
      store,
      envelope.parse({
        mutationId: "nullable-native-client",
        command: {
          type: "profile.update",
          expectedVersion: 2,
          profile: profile.parse({
            name: "Changed",
            budgetAlerts: null,
            forecastAlerts: null,
            quietHours: null,
          }),
        },
      }),
      flags,
    );
    expect((await store.get<any>("profiles", "current"))?.data).toMatchObject({
      budgetAlerts: true,
      forecastAlerts: true,
      quietHours: initial.quietHours,
    });
    await execute(
      store,
      envelope.parse({
        mutationId: "opt-out",
        command: {
          type: "profile.update",
          expectedVersion: 3,
          profile: profile.parse({
            budgetAlerts: false,
            quietHours: { enabled: false, startMinute: 1260, endMinute: 480 },
          }),
        },
      }),
      flags,
    );
    expect((await store.get<any>("profiles", "current"))?.data).toMatchObject({
      budgetAlerts: false,
      forecastAlerts: true,
      quietHours: { enabled: false },
    });
    expect(() =>
      profile.parse({
        quietHours: { enabled: true, startMinute: 480, endMinute: 480 },
      }),
    ).toThrow();
  });
  it("re-enables a cancelled renewal with a fresh live occurrence rather than a superseded job", async () => {
    const store = new MemoryStore();
    await store.mutate("recurrence", "recurrence", async (tx) => {
      for (const [index, date] of [
        "2026-09-08",
        "2026-10-08",
        "2026-11-08",
      ].entries())
        await tx.put(
          "transactions",
          `charge-${index}`,
          transaction.parse({
            id: `charge-${index}`,
            amount: { minor: -1299, currency: "USD" },
            date,
            merchant: "Stream",
            category: "Subscriptions",
            type: "expense",
            source: "manual",
          }),
          0,
        );
      await tx.put(
        "profiles",
        "current",
        profile.parse({ timezone: "America/Los_Angeles", renewalAlerts: true }),
        0,
      );
      return true;
    });
    const subscription = detectRecurring(
      (await store.list<any>("transactions")).map((r) => r.data),
    )[0];
    const command = (enabled: boolean) => ({
      type: "reminder.set",
      subscriptionId: subscription.id,
      enabled,
      daysBefore: 1,
    });
    const first = (await execute(
      store,
      envelope.parse({ mutationId: "enable", command: command(true) }),
      { ...flags, notifications: true },
    )) as any;
    const firstId = first.data.jobId;
    expect((await store.get<Job>("jobs", firstId))?.data.dueAt).toBe(
      "2026-12-07T17:00:00.000Z",
    );
    await execute(
      store,
      envelope.parse({ mutationId: "disable", command: command(false) }),
      { ...flags, notifications: true },
    );
    expect((await store.get<Job>("jobs", firstId))?.data).toMatchObject({
      status: "failed",
      error: "superseded",
    });
    const input = envelope.parse({
      mutationId: "enable-again",
      command: command(true),
    });
    const next = (await execute(store, input, {
      ...flags,
      notifications: true,
    })) as any;
    expect(next.data.jobId).not.toBe(firstId);
    expect((await store.get<Job>("jobs", next.data.jobId))?.data.status).toBe(
      "queued",
    );
    expect(
      await execute(store, input, { ...flags, notifications: true }),
    ).toEqual(next);
    expect(
      (await store.list<Job>("jobs")).filter(
        (r) => r.data.type === "reminder.deliver",
      ),
    ).toHaveLength(2);
    expect(
      (await store.list<Job>("jobs")).filter(
        (r) => r.data.type === "notification.plan",
      ),
    ).toHaveLength(1);
  });
  it("replays a lost response exactly once and rejects a reused identifier", async () => {
    const s = new MemoryStore();
    const a = await execute(s, make("m1"), flags);
    expect(await execute(s, make("m1"), flags)).toEqual(a);
    expect(await s.revision()).toBe(1);
    await expect(execute(s, make("m1", 0, -4000), flags)).rejects.toMatchObject(
      { code: "MUTATION_REUSED" },
    );
  });
  it("serializes concurrent edits and preserves the winner", async () => {
    const s = new MemoryStore();
    await execute(s, make("m1"), flags);
    const r = await Promise.allSettled([
      execute(s, make("m2", 1, -3000), flags),
      execute(s, make("m3", 1, -4000), flags),
    ]);
    expect(r.filter((v) => v.status === "fulfilled")).toHaveLength(1);
    expect((await s.get("transactions", "lunch"))?.version).toBe(2);
  });
  it("emits a tombstone and never resurrects it on a stale retry", async () => {
    const s = new MemoryStore();
    await execute(s, make("m1"), flags);
    await execute(
      s,
      envelope.parse({
        mutationId: "del",
        command: {
          type: "transaction.delete",
          id: "lunch",
          expectedVersion: 1,
        },
      }),
      flags,
    );
    expect(await s.list("transactions")).toHaveLength(0);
    expect((await s.changes(1))[0].changes[0].record.deleted).toBe(true);
    await expect(execute(s, make("m2", 1), flags)).rejects.toMatchObject({
      code: "VERSION_CONFLICT",
    });
  });
  it("prevents two offline devices from creating duplicate monthly category budgets", async () => {
    const s = new MemoryStore();
    const makeBudget = (id: string, category: string, month = "2026-11") =>
      envelope.parse({
        mutationId: id,
        command: {
          type: "budget.upsert",
          expectedVersion: 0,
          budget: {
            id,
            category,
            month,
            limit: { minor: 5000, currency: "USD" },
          },
        },
      });
    const attempts = await Promise.allSettled([
      execute(s, makeBudget("first", "Food"), flags),
      execute(s, makeBudget("second", "  FOOD  "), flags),
    ]);
    expect(attempts.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    expect(attempts.find((r) => r.status === "rejected")).toMatchObject({
      reason: { code: "VERSION_CONFLICT" },
    });
    await execute(s, make("expense", 0, -900), flags);
    const view = await workspace(s, flags, new Date("2026-11-09T12:00:00Z"));
    expect(view.snapshot.budget.categories).toHaveLength(1);
    expect(view.snapshot.budget.categories[0].spentMinor).toBe(900);
    await execute(s, makeBudget("prior-period", "food", "2026-10"), flags);
    expect(await s.list("budgets")).toHaveLength(2);
  });
  it("keeps owners independent", async () => {
    const alice = new MemoryStore(),
      bob = new MemoryStore();
    await execute(alice, make("m1"), flags);
    expect(await bob.list("transactions")).toHaveLength(0);
  });
  it("never fabricates balances or entitlement", async () => {
    const s = new MemoryStore();
    await execute(
      s,
      envelope.parse({
        mutationId: "p",
        command: {
          type: "profile.update",
          profile: profile.parse({ monthlyTargetMinor: 10000 }),
          expectedVersion: 0,
        },
      }),
      flags,
    );
    await execute(s, make("m1"), flags);
    const r = await workspace(s, flags, new Date("2026-11-09T17:00:00Z"));
    expect(r.snapshot.heroMinor).toBe(7100);
    expect(r.snapshot.balanceMinor).toBeNull();
    expect(r.entitlements.plus).toBe(false);
  });
  it("does not acknowledge an unscheduled reminder or unconfigured cancellation", async () => {
    const s = new MemoryStore();
    await expect(
      execute(
        s,
        envelope.parse({
          mutationId: "a",
          command: { type: "action.propose", subscriptionId: "example" },
        }),
        flags,
      ),
    ).rejects.toMatchObject({ code: "CAPABILITY_UNAVAILABLE" });
    expect(await s.revision()).toBe(0);
  });
  it("keeps virtual allocations separate from cash and spending, with replay and conflict protection", async () => {
    const store = new MemoryStore();
    await execute(store, make("expense"), flags);
    const before = await workspace(
      store,
      flags,
      new Date("2026-11-09T17:00:00Z"),
    );
    const create = envelope.parse({
      mutationId: "goal-create",
      command: {
        type: "goal.upsert",
        expectedVersion: 0,
        goal: {
          id: "emergency",
          name: "Emergency fund",
          target: { minor: 100000, currency: "USD" },
          allocated: { minor: 20000, currency: "USD" },
          targetDate: "2027-01-31",
          archived: false,
        },
      },
    });
    const record = await execute(store, create, flags);
    expect(await execute(store, create, flags)).toEqual(record);
    const after = await workspace(
      store,
      flags,
      new Date("2026-11-09T17:00:00Z"),
    );
    expect(after.goals).toHaveLength(1);
    expect(after.snapshot.budget.spentMinor).toBe(
      before.snapshot.budget.spentMinor,
    );
    expect(after.snapshot.heroMinor).toBe(before.snapshot.heroMinor);
    expect(after.snapshot.balanceMinor).toBe(before.snapshot.balanceMinor);
    await expect(
      execute(
        store,
        envelope.parse({ ...create, mutationId: "stale-goal" }),
        flags,
      ),
    ).rejects.toMatchObject({ code: "VERSION_CONFLICT" });
    expect(() =>
      envelope.parse({
        ...create,
        command: {
          ...create.command,
          goal: {
            ...(create.command as any).goal,
            allocated: { minor: 100001, currency: "USD" },
          },
        },
      }),
    ).toThrow();
  });
  it("keeps historical budget periods separate from the current monthly target and pace", async () => {
    const s = new MemoryStore();
    const historic = make("historical");
    if (historic.command.type === "transaction.upsert")
      historic.command.transaction.date = "2026-10-20";
    await execute(s, historic, flags);
    await execute(
      s,
      envelope.parse({
        mutationId: "october-budget",
        command: {
          type: "budget.upsert",
          expectedVersion: 0,
          budget: {
            id: "october",
            category: "Food",
            month: "2026-10",
            limit: { minor: 5000, currency: "USD" },
          },
        },
      }),
      flags,
    );
    const view = await workspace(s, flags, new Date("2026-11-09T17:00:00Z"));
    expect(view.snapshot.budget.spentMinor).toBe(0);
    const october = view.budgetPeriods.find((p) => p.month === "2026-10")!;
    expect(october.spentMinor).toBe(2900);
    expect(october.daysLeft).toBe(0);
    expect(october.state).toBe("closed");
    expect(october.categories[0].dailyMinor).toBe(0);
    expect(october.categories[0].aheadOfPace).toBe(false);
  });
  it("rejects client-authored bank facts", async () => {
    const s = new MemoryStore();
    const c = make("m");
    if (c.command.type === "transaction.upsert")
      c.command.transaction.source = "plaid";
    await expect(execute(s, c, flags)).rejects.toMatchObject({
      code: "PROVIDER_OWNED",
    });
  });
});
