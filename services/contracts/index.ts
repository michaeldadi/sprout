import { z } from "zod";

export const id = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[A-Za-z0-9_.:-]+$/);
export const money = z
  .object({ minor: z.number().int().safe(), currency: z.literal("USD") })
  .strict();
export const date = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((value) => {
    const parsed = new Date(`${value}T00:00:00Z`);
    return (
      Number.isFinite(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === value
    );
  }, "Invalid calendar date");
export const transaction = z
  .object({
    id,
    amount: money,
    date,
    merchant: z.string().max(160),
    category: z.string().min(1).max(80),
    type: z.enum(["income", "expense", "refund", "transfer"]),
    source: z.enum(["manual", "voice", "scan", "shortcut", "import", "plaid"]),
    accountId: id.default("cash"),
    description: z.string().max(1000).default(""),
    pending: z.boolean().default(false),
    excluded: z.boolean().default(false),
    providerId: z.string().max(160).optional(),
    pendingTransactionId: z.string().max(160).optional(),
  })
  .strict()
  .refine(
    (t) =>
      t.type === "transfer" ||
      (t.type === "expense" ? t.amount.minor <= 0 : t.amount.minor >= 0),
    "Amount direction does not match transaction type",
  );
export type Transaction = z.infer<typeof transaction>;
export const budget = z
  .object({
    id,
    category: z.string().min(1).max(80),
    month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/),
    limit: money.refine((v) => v.minor > 0),
  })
  .strict();
export type Budget = z.infer<typeof budget>;
/** Virtual planning only: no bank transfer or reduction of recorded spending. */
export const goal = z
  .object({
    id,
    name: z.string().trim().min(1).max(80),
    target: money.refine((v) => v.minor > 0),
    allocated: money.refine((v) => v.minor >= 0),
    targetDate: date.nullable(),
    archived: z.boolean(),
  })
  .strict()
  .refine(
    (v) => v.allocated.minor <= v.target.minor,
    "Allocation cannot exceed the goal target",
  );
export type Goal = z.infer<typeof goal>;
export const quietHours = z
  .object({
    enabled: z.boolean(),
    startMinute: z.number().int().min(0).max(1439),
    endMinute: z.number().int().min(0).max(1439),
  })
  .strict()
  .refine(
    (v) => v.startMinute !== v.endMinute,
    "Choose different quiet-hours start and end times",
  );
export const profile = z
  .object({
    name: z.string().max(100).default(""),
    onboarding: z
      .enum([
        "welcome",
        "connect-bank",
        "subscriptions-found",
        "your-plan",
        "complete",
      ])
      .default("welcome"),
    monthlyTargetMinor: z
      .number()
      .int()
      .safe()
      .positive()
      .nullable()
      .default(null),
    timezone: z
      .string()
      .max(80)
      .default("America/New_York")
      .refine((v) => {
        try {
          new Intl.DateTimeFormat("en-US", { timeZone: v });
          return true;
        } catch {
          return false;
        }
      }),
    appearance: z.enum(["system", "light", "dark"]).default("system"),
    renewalAlerts: z.boolean().default(false),
    priceAlerts: z.boolean().default(false),
    weeklyDigest: z.boolean().default(false),
    // Optional on the wire so an older native client cannot silently reset a
    // newer preference while saving an unrelated profile field.
    budgetAlerts: z.boolean().nullish(),
    forecastAlerts: z.boolean().nullish(),
    quietHours: quietHours.nullish(),
  })
  .strict();
export type Profile = z.infer<typeof profile>;
export const importRow = z
  .object({
    sourceIndex: z.number().int().min(0).max(9999),
    transaction: transaction.refine(
      (v) =>
        v.source === "import" &&
        v.accountId === "cash" &&
        v.providerId === undefined &&
        v.pendingTransactionId === undefined &&
        !v.pending,
      "Imports contain reviewed manual cash records only",
    ),
  })
  .strict();
export const transactionImport = z
  .object({
    type: z.literal("transaction.import"),
    batchId: z.string().regex(/^[a-f0-9]{64}$/),
    rows: z.array(importRow).min(1).max(1000),
  })
  .strict()
  .refine(
    (v) => new Set(v.rows.map((r) => r.sourceIndex)).size === v.rows.length,
    "Source rows must be unique",
  );
export type TransactionImport = z.infer<typeof transactionImport>;
export const receiptAttach = z
  .object({
    type: z.literal("receipt.attach"),
    id: z.string().uuid(),
    transactionId: id,
    sha256: z.string().regex(/^[a-f0-9]{64}$/),
    jpegBase64: z
      .string()
      .min(8)
      .max(866668)
      .regex(/^[A-Za-z0-9+/]+={0,2}$/),
  })
  .strict();
export type ReceiptAttach = z.infer<typeof receiptAttach>;
export const command = z.discriminatedUnion("type", [
  receiptAttach,
  z
    .object({
      type: z.literal("receipt.remove"),
      id: z.string().uuid(),
      expectedVersion: z.number().int().positive(),
    })
    .strict(),
  z
    .object({ type: z.literal("receipt.cancel"), id: z.string().uuid() })
    .strict(),
  transactionImport,
  z.object({ type: z.literal("transaction.import.resume"), id }).strict(),
  z
    .object({
      type: z.literal("goal.upsert"),
      goal,
      expectedVersion: z.number().int().nonnegative(),
    })
    .strict(),
  z
    .object({
      type: z.literal("transaction.upsert"),
      transaction,
      expectedVersion: z.number().int().nonnegative(),
    })
    .strict(),
  z
    .object({
      type: z.literal("transaction.delete"),
      id,
      expectedVersion: z.number().int().positive(),
    })
    .strict(),
  z
    .object({
      type: z.literal("profile.update"),
      profile,
      expectedVersion: z.number().int().nonnegative(),
    })
    .strict(),
  z
    .object({
      type: z.literal("budget.upsert"),
      budget,
      expectedVersion: z.number().int().nonnegative(),
    })
    .strict(),
  z
    .object({
      type: z.literal("recurring.decide"),
      id,
      decision: z.enum(["confirmed", "dismissed"]),
      expectedVersion: z.number().int().nonnegative(),
    })
    .strict(),
  z
    .object({
      type: z.literal("reminder.set"),
      subscriptionId: id,
      enabled: z.boolean(),
      daysBefore: z.number().int().min(0).max(30),
    })
    .strict(),
  z.object({ type: z.literal("action.propose"), subscriptionId: id }).strict(),
  z
    .object({
      type: z.literal("action.approve"),
      id,
      expectedVersion: z.number().int().positive(),
      evidenceHash: z.string().length(64),
    })
    .strict(),
  z
    .object({
      type: z.literal("insight.feedback"),
      id,
      feedback: z.enum(["dismissed", "snoozed", "useful"]),
    })
    .strict(),
  z.object({ type: z.literal("review.weekly") }).strict(),
]);
export const envelope = z.object({ mutationId: id, command }).strict();
export type CommandEnvelope = z.infer<typeof envelope>;
export const kinds = [
  "profiles",
  "transactions",
  "budgets",
  "goals",
  "recurring_decisions",
  "reminders",
  "actions",
  "action_events",
  "insight_feedback",
  "connections",
  "accounts",
  "jobs",
  "entitlements",
  "conversations",
  "privacy_jobs",
  "usage",
  "notifications",
  "import_inputs",
  "receipts",
] as const;
export type Kind = (typeof kinds)[number];
export interface RecordValue<T = Record<string, unknown>> {
  id: string;
  version: number;
  updatedAt: string;
  deleted: boolean;
  data: T;
}
export interface Change {
  kind: Kind;
  record: RecordValue<unknown>;
}
export interface SyncEvent {
  sequence: number;
  changes: Change[];
}
/** Operational import inputs are server-only; the journal records metadata only. */
export function journalRecord(
  kind: Kind,
  record: RecordValue<unknown>,
): RecordValue<unknown> {
  if (kind === "receipts" && record.data && !record.deleted) {
    const {
      leaseToken: _token,
      leaseUntil: _lease,
      ...data
    } = record.data as Record<string, unknown>;
    return { ...record, data };
  }
  if (kind !== "import_inputs" || record.deleted || !record.data) return record;
  const input = record.data as {
    batchId: string;
    part: number;
    checksum: string;
    rows: unknown[];
  };
  return {
    ...record,
    data: {
      batchId: input.batchId,
      part: input.part,
      checksum: input.checksum,
      count: input.rows.length,
    },
  };
}
export class AppError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400,
  ) {
    super(message);
  }
}
export interface Capabilities {
  linking: boolean;
  cancellation: boolean;
  ai: boolean;
  forecasts: boolean;
  notifications: boolean;
  scanAssistance: boolean;
}
export const capabilities = (): Capabilities => ({
  linking: process.env.SPROUT_LINKING === "true",
  cancellation: process.env.SPROUT_CANCELLATION === "true",
  ai: process.env.SPROUT_AI === "true",
  forecasts: process.env.SPROUT_FORECASTS === "true",
  notifications: process.env.SPROUT_NOTIFICATIONS === "true",
  scanAssistance: process.env.SPROUT_SCAN_ASSISTANCE === "true",
});
