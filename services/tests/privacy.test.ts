import { describe, expect, it } from "vitest";
import { randomBytes } from "node:crypto";
import {
  eraseActiveData,
  assertDeletionPermit,
  deletionReceipt,
  type DeletionProgress,
  type DeletionEffects,
} from "../domain/privacy";
const initial = (): DeletionProgress => ({
  status: "queued",
  attempts: 0,
  acceptedAt: "2026-11-09T12:00:00Z",
  updatedAt: "2026-11-09T12:00:00Z",
  steps: {
    accessRevoked: false,
    attachmentsRemoved: false,
    financialRecordsRemoved: false,
    identityAnonymized: false,
  },
});
describe("privacy erasure checkpoints", () => {
  it("revokes access while preserving records needed for an external cleanup dependency", async () => {
    const calls: string[] = [];
    const effects: DeletionEffects = {
      externalDependencies: async () => true,
      revokeAccess: async () => {
        calls.push("revoke");
      },
      removeAttachments: async () => {
        calls.push("files");
      },
      removeFinancialRecords: async () => {
        calls.push("rows");
      },
      anonymizeAndReserveIdentity: async () => {
        calls.push("identity");
      },
      save: async () => {},
    };
    const result = await eraseActiveData(initial(), effects);
    expect(result.status).toBe("needs_attention");
    expect(result.error).toBe("EXTERNAL_CLEANUP_REQUIRED");
    expect(calls).toEqual(["revoke"]);
    expect(result.steps.accessRevoked).toBe(true);
    expect(result.steps.financialRecordsRemoved).toBe(false);
  });
  it("resumes a failed effect without repeating completed checkpoints and reserves identity before removing the ledger's financial counterpart", async () => {
    const calls: string[] = [];
    let saved = initial();
    let fail = true;
    const effects: DeletionEffects = {
      externalDependencies: async () => false,
      revokeAccess: async () => {
        calls.push("revoke");
      },
      removeAttachments: async () => {
        calls.push("files");
        if (fail) throw new Error("provider details must never escape");
      },
      removeFinancialRecords: async () => {
        calls.push("rows");
      },
      anonymizeAndReserveIdentity: async () => {
        calls.push("identity");
      },
      save: async (p) => {
        saved = structuredClone(p);
      },
    };
    expect((await eraseActiveData(saved, effects)).status).toBe("retry");
    expect(saved.steps.accessRevoked).toBe(true);
    fail = false;
    const result = await eraseActiveData(saved, effects);
    expect(result.status).toBe("active_data_removed");
    expect(calls).toEqual(["revoke", "files", "files", "identity", "rows"]);
    expect(result.error).toBeUndefined();
    await eraseActiveData(result, effects);
    expect(calls).toHaveLength(5);
    expect(() => assertDeletionPermit(result, true)).toThrow();
    expect(() => assertDeletionPermit(initial(), false)).toThrow();
    expect(() => assertDeletionPermit(initial(), true)).not.toThrow();
  });
  it("requires a full entropy receipt and never uses an account identifier as the public lookup", () => {
    expect(
      deletionReceipt.safeParse(randomBytes(32).toString("base64url")).success,
    ).toBe(true);
    expect(deletionReceipt.safeParse("alice").success).toBe(false);
  });
});
