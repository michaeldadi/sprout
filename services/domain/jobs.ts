import { AppError, type RecordValue } from "../contracts";
import type { UserStore, WriteStore } from "./store";
import { fingerprint } from "./finance";

export interface Job {
  type:
    | "bank.sync"
    | "transaction.import"
    | "receipt.reconcile"
    | "receipt.cleanup"
    | "assistant"
    | "reminder.deliver"
    | "digest.deliver"
    | "review.prepare"
    | "notification.plan"
    | "action.reconcile"
    | "privacy.export"
    | "privacy.delete";
  status:
    | "queued"
    | "running"
    | "retry"
    | "succeeded"
    | "failed"
    | "needs_attention";
  dueAt: string;
  attempts: number;
  leaseUntil: string | null;
  leaseToken: string | null;
  payload: Record<string, unknown>;
  result?: unknown;
  error?: string;
}
export async function schedule(
  tx: WriteStore,
  type: Job["type"],
  key: string,
  payload: Record<string, unknown>,
  due = new Date(),
) {
  const id = fingerprint([type, key]).slice(0, 36);
  const existing = await tx.get<Job>("jobs", id);
  if (existing && !existing.deleted) return existing;
  return tx.put<Job>(
    "jobs",
    id,
    {
      type,
      status: "queued",
      dueAt: due.toISOString(),
      attempts: 0,
      leaseUntil: null,
      leaseToken: null,
      payload,
    },
    0,
  );
}
export async function claim(
  store: UserStore,
  id: string,
  token: string,
  now = new Date(),
): Promise<RecordValue<Job> | null> {
  return store.mutate(
    `claim:${token}`,
    fingerprint([id, token]),
    async (tx) => {
      const job = await tx.get<Job>("jobs", id);
      if (
        !job ||
        job.deleted ||
        !["queued", "retry", "running"].includes(job.data.status) ||
        Date.parse(job.data.dueAt) > now.getTime() ||
        (job.data.leaseUntil && Date.parse(job.data.leaseUntil) > now.getTime())
      )
        return null;
      return tx.put<Job>(
        "jobs",
        id,
        {
          ...job.data,
          status: "running",
          attempts: job.data.attempts + 1,
          leaseUntil: new Date(now.getTime() + 240_000).toISOString(),
          leaseToken: token,
        },
        job.version,
      );
    },
  );
}
/** Policy deferral is not a failed delivery attempt. Only the current live
 * claim can release the job, and it cannot move due work into the past. */
export async function defer(
  store: UserStore,
  id: string,
  token: string,
  until: Date,
  reason: string,
  now = new Date(),
) {
  if (
    !Number.isFinite(until.getTime()) ||
    until.getTime() <= now.getTime() ||
    until.getTime() > now.getTime() + 27 * 3_600_000
  )
    throw new AppError("INVALID_TIME", "This job deferral needs review.");
  return store.mutate(
    `defer:${token}`,
    fingerprint([id, token, until.toISOString(), reason]),
    async (tx) => {
      const job = await tx.get<Job>("jobs", id);
      if (
        !job ||
        job.data.status !== "running" ||
        job.data.leaseToken !== token ||
        !Number.isFinite(Date.parse(job.data.leaseUntil ?? "")) ||
        Date.parse(job.data.leaseUntil ?? "") <= now.getTime()
      )
        throw new AppError("LEASE_LOST", "Job claim expired.", 409);
      return tx.put<Job>(
        "jobs",
        id,
        {
          ...job.data,
          status: "retry",
          dueAt: until.toISOString(),
          attempts: Math.max(0, job.data.attempts - 1),
          leaseUntil: null,
          leaseToken: null,
          error: reason,
        },
        job.version,
      );
    },
  );
}

export async function finish(
  store: UserStore,
  id: string,
  token: string,
  result: unknown,
  error?: string,
  now = new Date(),
) {
  return store.mutate(
    `finish:${token}`,
    fingerprint([id, token, error ?? null, result ?? null]),
    async (tx) => {
      const job = await tx.get<Job>("jobs", id);
      if (
        !job ||
        job.data.leaseToken !== token ||
        job.data.status !== "running"
      )
        throw new AppError("LEASE_LOST", "Job claim expired.", 409);
      const stopped = error === "ACCOUNT_DELETING";
      if (
        !error &&
        job.data.type === "transaction.import" &&
        job.data.payload.cursor !== job.data.payload.total
      )
        throw new AppError(
          "IMPORT_INCOMPLETE",
          "The import has unprocessed records. Resume from its saved checkpoint.",
          409,
        );
      const failed = error && job.data.attempts >= 6;
      return tx.put<Job>(
        "jobs",
        id,
        {
          ...job.data,
          payload:
            !error && job.data.type === "transaction.import"
              ? Object.fromEntries(
                  Object.entries(job.data.payload).filter(
                    ([key]) => key !== "rows",
                  ),
                )
              : job.data.payload,
          status: stopped
            ? "failed"
            : error
              ? failed
                ? "needs_attention"
                : "retry"
              : "succeeded",
          leaseUntil: null,
          leaseToken: null,
          dueAt: new Date(
            now.getTime() +
              Math.min(3_600_000, 30_000 * 2 ** job.data.attempts),
          ).toISOString(),
          ...(error
            ? { error, result: undefined }
            : { result, error: undefined }),
        },
        job.version,
      );
    },
  );
}
