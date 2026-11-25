import { afterEach, describe, expect, it, vi } from "vitest";
import { MemoryStore } from "../domain/store";
import { execute, workspace, type Action } from "../domain/application";
import { envelope, type Capabilities, type RecordValue } from "../contracts";
import { cancellationPartner } from "../integrations/cancellation";
const flags: Capabilities = {
  linking: false,
  cancellation: true,
  ai: false,
  forecasts: false,
  notifications: false,
  scanAssistance: false,
};
const now = new Date("2026-11-09T15:00:00Z");
async function setup() {
  const store = new MemoryStore();
  vi.spyOn(cancellationPartner, "eligibility").mockResolvedValue({
    merchantId: "fictional",
    supported: true,
    verifiedAt: now.toISOString(),
    conditions: [],
  });
  await store.mutate("entitlement", "seed", (tx) =>
    tx.put("entitlements", "current", {
      plus: true,
      expiresAt: null,
      verifiedAt: now.toISOString(),
    }),
  );
  for (const [i, date] of ["2026-08-18", "2026-09-18", "2026-10-18"].entries())
    await execute(
      store,
      envelope.parse({
        mutationId: `t-${i}`,
        command: {
          type: "transaction.upsert",
          expectedVersion: 0,
          transaction: {
            id: `t-${i}`,
            amount: { minor: -1199, currency: "USD" },
            date,
            merchant: "Fictional Service",
            category: "Entertainment",
            type: "expense",
            source: "manual",
          },
        },
      }),
      flags,
      now,
    );
  const subscription = (await workspace(store, flags, now)).subscriptions[0];
  return { store, subscription };
}
describe("cancellation approval state", () => {
  afterEach(() => vi.restoreAllMocks());
  it("preserves an approved action when the same subscription is proposed again", async () => {
    const { store, subscription } = await setup();
    const action = (await execute(
      store,
      {
        mutationId: "proposal",
        command: { type: "action.propose", subscriptionId: subscription.id },
      },
      flags,
      now,
    )) as RecordValue<Action>;
    const approved = (await execute(
      store,
      {
        mutationId: "approval",
        command: {
          type: "action.approve",
          id: action.id,
          evidenceHash: action.data.evidenceHash,
          expectedVersion: action.version,
        },
      },
      flags,
      now,
    )) as RecordValue<Action>;
    const repeated = (await execute(
      store,
      {
        mutationId: "another-proposal",
        command: { type: "action.propose", subscriptionId: subscription.id },
      },
      flags,
      now,
    )) as RecordValue<Action>;
    expect(repeated.id).toBe(approved.id);
    expect(repeated.data.state).toBe("approved");
    expect(repeated.version).toBe(approved.version);
    expect(await store.list("actions")).toHaveLength(1);
    expect(await store.list("action_events")).toHaveLength(2);
    expect(
      (
        await store.get<{ cancellationReservations: number }>(
          "usage",
          "2026-11",
        )
      )?.data.cancellationReservations,
    ).toBe(1);
  });
  it("rejects approval after charge evidence changes without consuming an allowance", async () => {
    const { store, subscription } = await setup();
    const action = (await execute(
      store,
      {
        mutationId: "proposal",
        command: { type: "action.propose", subscriptionId: subscription.id },
      },
      flags,
      now,
    )) as RecordValue<Action>;
    await execute(
      store,
      envelope.parse({
        mutationId: "correct-charge",
        command: {
          type: "transaction.upsert",
          expectedVersion: 1,
          transaction: {
            id: "t-2",
            amount: { minor: -1299, currency: "USD" },
            date: "2026-10-18",
            merchant: "Fictional Service",
            category: "Entertainment",
            type: "expense",
            source: "manual",
          },
        },
      }),
      flags,
      now,
    );
    await expect(
      execute(
        store,
        {
          mutationId: "approval",
          command: {
            type: "action.approve",
            id: action.id,
            evidenceHash: action.data.evidenceHash,
            expectedVersion: action.version,
          },
        },
        flags,
        now,
      ),
    ).rejects.toMatchObject({ code: "STALE_EVIDENCE" });
    expect(await store.list("action_events")).toHaveLength(1);
    expect(await store.list("usage")).toHaveLength(0);
  });
});
