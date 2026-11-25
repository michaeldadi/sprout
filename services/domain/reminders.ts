import {
  AppError,
  profile,
  type Profile,
  type RecordValue,
  type Transaction,
} from "../contracts";
import type { UserStore, WriteStore } from "./store";
import { detectRecurring, fingerprint } from "./finance";
import {
  localDate,
  localInstant,
  nextAllowedDelivery,
  reminderDue,
} from "./calendar";
import { schedule, type Job } from "./jobs";
import { planWeeklyReview } from "./weekly";

export interface ReminderRule {
  subscriptionId: string;
  enabled: boolean;
  daysBefore: number;
  renewalDate: string;
  evidenceHash: string;
  jobId: string | null;
  status: string;
  planHash?: string;
}
export const renewalOccurrence = (
  subscriptionId: string,
  renewalDate: string,
) => fingerprint(["renewal", subscriptionId, renewalDate]).slice(0, 36);

/** Coalesce fact changes at the next five-minute boundary. A change after that
 * boundary receives a new ID, including while the earlier planner is running. */
export async function requestReminderPlan(tx: WriteStore, now = new Date()) {
  if (
    !(await tx.list<ReminderRule>("reminders")).length &&
    !(await tx.get<Profile>("profiles", "current"))?.data.weeklyDigest
  )
    return null;
  const due = new Date((Math.floor(now.getTime() / 300000) + 1) * 300000);
  return schedule(
    tx,
    "notification.plan",
    `facts:${due.toISOString()}`,
    {},
    due,
  );
}

async function supersede(tx: WriteStore, id: string | null) {
  if (!id) return;
  const job = await tx.get<Job>("jobs", id);
  if (job && ["queued", "retry"].includes(job.data.status))
    await tx.put(
      "jobs",
      id,
      { ...job.data, status: "failed", error: "superseded" },
      job.version,
    );
}

/** Recalculate from current evidence inside the same canonical transaction.
 * Passing enabled=true records tracking intent; a muted topic stays muted. */
export async function planReminder(
  tx: WriteStore,
  subscriptionId: string,
  options?: { enabled: boolean; daysBefore: number },
  now = new Date(),
) {
  const old = await tx.get<ReminderRule>("reminders", subscriptionId);
  if (!old && !options) return null;
  const preferences = profile.parse(
    (await tx.get<Profile>("profiles", "current"))?.data ?? {},
  );
  const enabled = options?.enabled ?? old!.data.enabled,
    daysBefore = options?.daysBefore ?? old!.data.daysBefore;
  const stream = detectRecurring(
    (await tx.list<Transaction>("transactions")).map((r) => r.data),
  ).find((s) => s.id === subscriptionId);
  const decision = await tx.get<{ decision: string }>(
    "recurring_decisions",
    subscriptionId,
  );
  if (options && !stream && (!old || options.enabled))
    throw new AppError("NOT_FOUND", "Subscription not found.", 404);
  const oldId = old?.data.jobId ?? null;
  const importing = (await tx.list<{ status: string }>("connections")).some(
    (r) => ["importing", "exchanging"].includes(r.data.status),
  );
  const expired =
    !!stream && stream.nextDate < localDate(now, preferences.timezone);
  const hash = fingerprint([
    enabled,
    daysBefore,
    stream?.evidenceHash ?? null,
    stream?.nextDate ?? null,
    decision?.data.decision ?? null,
    preferences.renewalAlerts,
    preferences.timezone,
    preferences.quietHours ?? null,
    importing,
    expired,
  ]);
  const priorJob = oldId ? await tx.get<Job>("jobs", oldId) : null;
  if (
    old?.data.planHash === hash &&
    priorJob?.data.status === "needs_attention" &&
    old.data.status !== "needs_attention"
  )
    return tx.put<ReminderRule>(
      "reminders",
      old.id,
      { ...old.data, status: "needs_attention" },
      old.version,
    );
  if (
    old?.data.planHash === hash &&
    (!oldId ||
      (priorJob &&
        ["queued", "retry", "running", "needs_attention"].includes(
          priorJob.data.status,
        )))
  )
    return old;
  let status = !enabled
    ? "cancelled"
    : !preferences.renewalAlerts
      ? "muted"
      : importing
        ? "awaiting_data"
        : !stream || decision?.data.decision === "dismissed"
          ? "needs_review"
          : "scheduled";
  let due: Date | undefined;
  if (status === "scheduled" && stream) {
    const accepted = await tx.get<{ status: string }>(
      "notifications",
      renewalOccurrence(stream.id, stream.nextDate),
    );
    if (accepted && ["accepted", "delivered"].includes(accepted.data.status))
      status = accepted.data.status;
    else {
      const requested = reminderDue(
        stream.nextDate,
        daysBefore,
        preferences.timezone,
      );
      due = nextAllowedDelivery(
        new Date(Math.max(now.getTime(), requested.getTime())),
        preferences.timezone,
        preferences.quietHours ?? undefined,
      );
      if (stream.nextDate < localDate(due, preferences.timezone)) {
        status = "needs_review";
        due = undefined;
      }
    }
  }
  await supersede(tx, oldId);
  let jobId: string | null = null;
  if (due && stream) {
    const job = await schedule(
      tx,
      "reminder.deliver",
      `${subscriptionId}:${hash}:${(old?.version ?? 0) + 1}`,
      {
        subscriptionId,
        evidenceHash: stream.evidenceHash,
        renewalDate: stream.nextDate,
      },
      due,
    );
    jobId = job.id;
  }
  return tx.put<ReminderRule>(
    "reminders",
    subscriptionId,
    {
      subscriptionId,
      enabled,
      daysBefore,
      renewalDate: stream?.nextDate ?? old?.data.renewalDate ?? "",
      evidenceHash: stream?.evidenceHash ?? old?.data.evidenceHash ?? "",
      jobId,
      status,
      planHash: hash,
    },
    old?.version ?? 0,
  );
}

/** Each rule is its own bounded transaction. The current planner lease fences
 * every write; a daily check recovers missed change events without fake renewals. */
export async function reconcileReminders(
  store: UserStore,
  jobId: string,
  token: string,
  now = new Date(),
) {
  const rules = await store.list<ReminderRule>("reminders");
  const assertClaim = async (tx: WriteStore) => {
    const job = await tx.get<Job>("jobs", jobId),
      lease = Date.parse(job?.data.leaseUntil ?? "");
    if (
      !job ||
      job.data.status !== "running" ||
      job.data.leaseToken !== token ||
      !Number.isFinite(lease) ||
      lease <= Date.now()
    )
      throw new AppError("LEASE_LOST", "Planner claim expired.", 409);
  };
  for (const rule of rules)
    await store.mutate(
      `plan:${token}:${rule.id}`,
      fingerprint([jobId, rule.id]),
      async (tx) => {
        await assertClaim(tx);
        await planReminder(tx, rule.id, undefined, now);
        return { id: rule.id };
      },
    );
  await store.mutate(`plan-next:${token}`, fingerprint(jobId), async (tx) => {
    await assertClaim(tx);
    await planWeeklyReview(tx, now);
    if (
      (await tx.list<ReminderRule>("reminders")).some((r) => r.data.enabled) ||
      (await tx.get<Profile>("profiles", "current"))?.data.weeklyDigest
    ) {
      const preferences = profile.parse(
        (await tx.get<Profile>("profiles", "current"))?.data ?? {},
      );
      const tomorrow = new Date(
        Date.parse(localDate(now, preferences.timezone) + "T00:00:00Z") +
          86400000,
      )
        .toISOString()
        .slice(0, 10);
      await schedule(
        tx,
        "notification.plan",
        `daily:${tomorrow}:${preferences.timezone}`,
        {},
        localInstant(tomorrow, 9 * 60, preferences.timezone),
      );
    }
    return { rules: rules.length };
  });
  return { rules: rules.length };
}
