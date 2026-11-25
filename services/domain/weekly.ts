import {
  AppError,
  profile,
  type Profile,
  type Transaction,
} from "../contracts";
import { checkedSum, detectRecurring, fingerprint } from "./finance";
import { localDate, nextWeeklyReview } from "./calendar";
import { schedule, type Job } from "./jobs";
import type { UserStore, WriteStore } from "./store";

export const weeklyOccurrence = (week: string) =>
  fingerprint(["weekly-review", week]).slice(0, 36);
export const weeklyPolicyHash = (preferences: Profile) =>
  fingerprint([
    preferences.weeklyDigest,
    preferences.timezone,
    preferences.quietHours ?? null,
  ]);
export interface WeeklyReview {
  week: string;
  fromDate: string;
  throughDate: string;
  netSpendingMinor: number;
  incomeMinor: number;
  transactionCount: number;
  trackedRenewals: number;
  evidenceIds: string[];
  accountIds: string[];
  scope: "available_history";
  preparedAt: string;
}
const day = 86_400_000;
const shifted = (date: string, days: number) =>
  new Date(Date.parse(date + "T00:00:00Z") + days * day)
    .toISOString()
    .slice(0, 10);

export async function queueWeeklyReview(tx: WriteStore, now = new Date()) {
  const row = await tx.get<Profile>("profiles", "current"),
    preferences = profile.parse(row?.data ?? {}),
    today = localDate(now, preferences.timezone);
  const weekday = new Date(today + "T00:00:00Z").getUTCDay(),
    week = shifted(today, -(weekday + 6) % 7);
  return schedule(
    tx,
    "review.prepare",
    `${week}:${preferences.timezone}`,
    { week, policyHash: fingerprint([preferences.timezone]) },
    now,
  );
}

export async function planWeeklyReview(tx: WriteStore, now = new Date()) {
  const row = await tx.get<Profile>("profiles", "current"),
    preferences = profile.parse(row?.data ?? {});
  if (!preferences.weeklyDigest) return null;
  const due = nextWeeklyReview(
      now,
      preferences.timezone,
      preferences.quietHours ?? undefined,
    ),
    local = localDate(due, preferences.timezone);
  const weekday = new Date(local + "T00:00:00Z").getUTCDay(),
    week = shifted(local, -(weekday + 6) % 7);
  return schedule(
    tx,
    "digest.deliver",
    `${week}:${row!.version}`,
    {
      week,
      profileVersion: row!.version,
      policyHash: weeklyPolicyHash(preferences),
    },
    due,
  );
}

/** Persist one evidence-bound review per week. Delivery retries use that same
 * snapshot; missing history never becomes an account-wide completeness claim. */
export async function prepareWeeklyReview(
  store: UserStore,
  jobId: string,
  token: string,
  now = new Date(),
) {
  return store.mutate(
    `weekly:${jobId}:${token}`,
    fingerprint([jobId, token]),
    async (tx) => {
      const job = await tx.get<Job>("jobs", jobId);
      if (
        !job ||
        job.data.status !== "running" ||
        job.data.leaseToken !== token ||
        !(Date.parse(job.data.leaseUntil ?? "") > now.getTime())
      )
        throw new AppError("LEASE_LOST", "Weekly review claim expired.", 409);
      const row = await tx.get<Profile>("profiles", "current"),
        preferences = profile.parse(row?.data ?? {});
      const manual = job.data.type === "review.prepare";
      if (!manual && !preferences.weeklyDigest)
        return { status: "muted" as const };
      if (
        job.data.payload.policyHash !==
        (manual
          ? fingerprint([preferences.timezone])
          : weeklyPolicyHash(preferences))
      )
        return { status: "superseded" as const };
      const week = String(job.data.payload.week);
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(week) ||
        new Date(week + "T00:00:00Z").getUTCDay() !== 1
      )
        throw new AppError("INVALID_JOB", "Weekly review period needs review.");
      const today = localDate(now, preferences.timezone);
      if (week > today || today >= shifted(week, 7))
        return { status: "superseded" as const };
      const occurrenceId = weeklyOccurrence(week),
        saved = await tx.get<{ review: WeeklyReview; status: string }>(
          "notifications",
          occurrenceId,
        );
      if (saved)
        return {
          status: "ready" as const,
          occurrenceId,
          review: saved.data.review,
          accepted: ["accepted", "delivered"].includes(saved.data.status),
        };
      const connections = await tx.list<{ status: string }>("connections"),
        jobs = await tx.list<Job>("jobs");
      if (
        connections.some((r) =>
          ["importing", "exchanging"].includes(r.data.status),
        ) ||
        jobs.some(
          (r) =>
            r.data.type === "transaction.import" &&
            !["succeeded", "failed"].includes(r.data.status),
        )
      )
        return { status: "incomplete" as const };
      const all = (await tx.list<Transaction>("transactions")).map(
          (r) => r.data,
        ),
        fromDate = shifted(week, -7),
        throughDate = shifted(week, -1);
      const facts = all.filter(
        (t) =>
          !t.pending &&
          !t.excluded &&
          t.type !== "transfer" &&
          t.date >= fromDate &&
          t.date <= throughDate,
      );
      if (!facts.length) return { status: "empty" as const };
      const confirmed = new Set(
        (await tx.list<{ decision: string }>("recurring_decisions"))
          .filter((r) => r.data.decision === "confirmed")
          .map((r) => r.id),
      );
      const review: WeeklyReview = {
        week,
        fromDate,
        throughDate,
        netSpendingMinor: -checkedSum(
          facts
            .filter((t) => ["expense", "refund"].includes(t.type))
            .map((t) => t.amount.minor),
        ),
        incomeMinor: checkedSum(
          facts.filter((t) => t.type === "income").map((t) => t.amount.minor),
        ),
        transactionCount: facts.length,
        trackedRenewals: detectRecurring(all).filter(
          (s) =>
            confirmed.has(s.id) &&
            s.nextDate >= week &&
            s.nextDate < shifted(week, 7),
        ).length,
        evidenceIds: facts
          .map((t) => t.id)
          .sort()
          .slice(0, 20),
        accountIds: [...new Set(facts.map((t) => t.accountId))].sort(),
        scope: "available_history",
        preparedAt: now.toISOString(),
      };
      await tx.put(
        "notifications",
        occurrenceId,
        { topic: "weekly", status: "prepared", review, jobId },
        0,
      );
      return {
        status: "ready" as const,
        occurrenceId,
        review,
        accepted: false,
      };
    },
  );
}
