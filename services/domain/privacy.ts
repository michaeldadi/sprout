import { createHash } from "node:crypto";
import { z } from "zod";
import { AppError } from "../contracts";

export const deletionReceipt = z
  .string()
  .regex(/^[A-Za-z0-9_-]{43}$/)
  .refine((value) => Buffer.from(value, "base64url").length === 32);
export const privacyHash = (value: string) =>
  createHash("sha256").update(value).digest("hex");
export interface DeletionProgress {
  status:
    | "queued"
    | "running"
    | "retry"
    | "needs_attention"
    | "active_data_removed";
  attempts: number;
  acceptedAt: string;
  updatedAt: string;
  steps: {
    accessRevoked: boolean;
    attachmentsRemoved: boolean;
    financialRecordsRemoved: boolean;
    identityAnonymized: boolean;
  };
  error?: "EXTERNAL_CLEANUP_REQUIRED" | "PRIVACY_RETRY";
}
export const deletionProgress = z
  .object({
    status: z.enum([
      "queued",
      "running",
      "retry",
      "needs_attention",
      "active_data_removed",
    ]),
    attempts: z.number().int().min(0).max(1000000),
    acceptedAt: z.iso.datetime({ offset: true }),
    updatedAt: z.iso.datetime({ offset: true }),
    steps: z
      .object({
        accessRevoked: z.boolean(),
        attachmentsRemoved: z.boolean(),
        financialRecordsRemoved: z.boolean(),
        identityAnonymized: z.boolean(),
      })
      .strict(),
    error: z.enum(["EXTERNAL_CLEANUP_REQUIRED", "PRIVACY_RETRY"]).optional(),
  })
  .strict();
export interface DeletionEffects {
  externalDependencies(): Promise<boolean>;
  revokeAccess(): Promise<void>;
  removeAttachments(): Promise<void>;
  removeFinancialRecords(): Promise<void>;
  anonymizeAndReserveIdentity(): Promise<void>;
  save(progress: DeletionProgress): Promise<void>;
  failure?(error: unknown): void;
}
/** Persist each checkpoint before the next effect. Effects must be replay safe;
 * the reserved disabled Auth ID prevents old row ACLs acquiring a new owner. */
export async function eraseActiveData(
  progress: DeletionProgress,
  effects: DeletionEffects,
  now = () => new Date().toISOString(),
) {
  let current = structuredClone(progress);
  if (current.status === "active_data_removed") return current;
  current = {
    ...current,
    status: "running",
    attempts: current.attempts + 1,
    updatedAt: now(),
    error: undefined,
  };
  await effects.save(current);
  try {
    // Disable first-party access even when a vendor still needs cleanup. Keep
    // vendor identifiers and first-party records for the scoped recovery worker.
    if (!current.steps.accessRevoked) {
      await effects.revokeAccess();
      current = {
        ...current,
        updatedAt: now(),
        steps: { ...current.steps, accessRevoked: true },
      };
      await effects.save(current);
    }
    if (await effects.externalDependencies()) {
      current = {
        ...current,
        status: "needs_attention",
        updatedAt: now(),
        error: "EXTERNAL_CLEANUP_REQUIRED",
      };
      await effects.save(current);
      return current;
    }
    const stages = [
      ["attachmentsRemoved", effects.removeAttachments],
      ["identityAnonymized", effects.anonymizeAndReserveIdentity],
      ["financialRecordsRemoved", effects.removeFinancialRecords],
    ] as const;
    for (const [step, effect] of stages)
      if (!current.steps[step]) {
        await effect();
        current = {
          ...current,
          updatedAt: now(),
          steps: { ...current.steps, [step]: true },
        };
        await effects.save(current);
      }
    current = {
      ...current,
      status: "active_data_removed",
      updatedAt: now(),
      error: undefined,
    };
    await effects.save(current);
    return current;
  } catch (error) {
    effects.failure?.(error);
    current = {
      ...current,
      status: current.attempts >= 6 ? "needs_attention" : "retry",
      updatedAt: now(),
      error: "PRIVACY_RETRY",
    };
    await effects.save(current);
    return current;
  }
}
export function assertDeletionPermit(
  progress: DeletionProgress | null,
  control: boolean,
) {
  if (progress && (!control || progress.steps.financialRecordsRemoved))
    throw new AppError(
      "ACCOUNT_DELETING",
      "New work is stopped for this account.",
      410,
    );
}
