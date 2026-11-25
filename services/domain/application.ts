import {
  AppError,
  profile,
  transaction,
  type CommandEnvelope,
  type Transaction,
  type Budget,
  type Goal,
  type Capabilities,
  type Profile,
} from "../contracts";
import {
  budgetSummary,
  categoryKey,
  checkedSum,
  detectRecurring,
  fingerprint,
  formatUSD,
} from "./finance";
import type { UserStore, ReadStore } from "./store";
import { schedule } from "./jobs";
import { importProgress, queueImport, resumeImport } from "./imports";
import { planReminder, requestReminderPlan } from "./reminders";
import type { Receipt } from "./receipts";
import { queueWeeklyReview, type WeeklyReview } from "./weekly";
import { cancellationPartner } from "../integrations/cancellation";

export interface Action {
  subscriptionId: string;
  merchant: string;
  state:
    | "proposed"
    | "approved"
    | "awaiting_partner"
    | "submitted"
    | "verifying"
    | "succeeded"
    | "failed"
    | "needs_attention";
  evidenceHash: string;
  approvalExpiresAt?: string;
  providerReference?: string;
}
export interface Entitlement {
  plus: boolean;
  expiresAt: string | null;
  verifiedAt: string;
}
export async function plusEntitlement(store: ReadStore, now: Date) {
  const r = await store.get<Entitlement>("entitlements", "current");
  return (
    !!r &&
    !r.deleted &&
    r.data.plus &&
    (!r.data.expiresAt || Date.parse(r.data.expiresAt) > now.getTime())
  );
}
export async function workspace(
  store: UserStore,
  flags: Capabilities,
  now = new Date(),
) {
  for (let retry = 0; retry < 3; retry++) {
    const revision = await store.revision();
    const [
      p,
      tx,
      bs,
      goals,
      decisions,
      reminders,
      actions,
      feedback,
      accounts,
      connections,
      plus,
    ] = await Promise.all([
      store.get<Profile>("profiles", "current"),
      store.list<Transaction>("transactions"),
      store.list<Budget>("budgets"),
      store.list<Goal>("goals"),
      store.list<{ decision: string }>("recurring_decisions"),
      store.list("reminders"),
      store.list<Action>("actions"),
      store.list<{ feedback: string; until?: string }>("insight_feedback"),
      store.list("accounts"),
      store.list("connections"),
      plusEntitlement(store, now),
    ]);
    if (revision !== (await store.revision())) continue;
    const transactions = tx.map((r) => ({
      ...r.data,
      version: r.version,
      updatedAt: r.updatedAt,
    }));
    const candidates = detectRecurring(transactions).map((s) => ({
      ...s,
      decision:
        decisions.find((d) => d.id === s.id)?.data.decision ?? "inferred",
      decisionVersion: decisions.find((d) => d.id === s.id)?.version ?? 0,
    }));
    const subscriptions = candidates.filter((s) => s.decision !== "dismissed");
    const today = new Intl.DateTimeFormat("en-CA", {
      timeZone: p?.data.timezone ?? "America/New_York",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(now);
    const budget = budgetSummary(
      transactions,
      bs.map((b) => b.data),
      today,
    );
    const months = [
      ...new Set([
        today.slice(0, 7),
        ...transactions.map((t) => t.date.slice(0, 7)),
        ...bs.map((b) => b.data.month),
      ]),
    ]
      .sort()
      .reverse();
    const budgetPeriods = months.map((month) => {
      const current = month === today.slice(0, 7);
      const closed = month < today.slice(0, 7);
      const last = new Date(`${month}-01T12:00:00Z`);
      last.setUTCMonth(last.getUTCMonth() + 1);
      last.setUTCDate(0);
      const result = budgetSummary(
        transactions,
        bs.map((b) => b.data),
        current
          ? today
          : closed
            ? last.toISOString().slice(0, 10)
            : `${month}-01`,
      );
      return {
        ...result,
        remainingMinor: checkedSum([result.plannedMinor, -result.spentMinor]),
        state: current ? "current" : closed ? "closed" : "upcoming",
        daysLeft: closed ? 0 : result.daysLeft,
        categories: result.categories.map((c) => ({
          ...c,
          dailyMinor: closed ? 0 : c.dailyMinor,
          aheadOfPace: current && c.aheadOfPace,
        })),
      };
    });
    const insights = budget.categories
      .filter((c) => c.aheadOfPace)
      .map((c) => ({
        id: `budget:${budget.month}:${c.id}`,
        kind: "budget",
        title: `${c.category} is ahead of its planned pace`,
        detail: `${formatUSD(c.dailyMinor)} per day remains in this category budget.`,
        category: c.category,
        evidenceIds: transactions
          .filter(
            (t) =>
              categoryKey(t.category) === categoryKey(c.category) &&
              t.date.startsWith(budget.month) &&
              (t.type === "expense" || t.type === "refund") &&
              !t.pending && !t.excluded,
          )
          .map((t) => t.id),
      }))
      .filter(
        (i) =>
          !feedback.some(
            (f) =>
              f.id === i.id &&
              (f.data.feedback === "dismissed" ||
                (f.data.feedback === "snoozed" &&
                  !!f.data.until &&
                  Date.parse(f.data.until) > now.getTime())),
          ),
      );
    const target = p?.data.monthlyTargetMinor ?? null;
    const cash = accounts.filter(
      (a) =>
        (a.data as any).type === "depository" &&
        (a.data as any).currency === "USD" &&
        Number.isSafeInteger((a.data as any).currentMinor),
    );
    const balanceMinor = cash.length
      ? checkedSum(cash.map((a) => (a.data as any).currentMinor))
      : null;
    const [conversations, jobs, privacyJobs, receipts, notifications] =
      await Promise.all([
        store.list("conversations"),
        store.list("jobs"),
        store.list("privacy_jobs"),
        store.list<Receipt>("receipts"),
        store.list<{ topic: string; review?: WeeklyReview }>("notifications"),
      ]);
    if (revision !== (await store.revision())) continue;
    for (const saved of notifications
      .filter((r) => r.data.topic === "weekly" && r.data.review)
      .sort((a, b) => b.data.review!.week.localeCompare(a.data.review!.week))
      .slice(0, 4)) {
      const review = saved.data.review!;
      if (
        feedback.some(
          (f) =>
            f.id === saved.id &&
            (f.data.feedback === "dismissed" ||
              (f.data.feedback === "snoozed" &&
                !!f.data.until &&
                Date.parse(f.data.until) > now.getTime())),
        )
      )
        continue;
      insights.push({
        id: saved.id,
        kind: "weekly",
        title: `Your week of ${review.fromDate}`,
        detail: `Available history for ${review.fromDate}–${review.throughDate}: ${formatUSD(review.netSpendingMinor)} net spending and ${formatUSD(review.incomeMinor)} income. ${review.trackedRenewals} tracked renewal estimate(s) for ${review.week}–${new Date(Date.parse(review.week + "T00:00:00Z") + 6 * 86400000).toISOString().slice(0, 10)}. This covers ${review.accountIds.length} recorded account(s). Prepared ${review.preparedAt.slice(0, 10)}.`,
        category: "",
        evidenceIds: review.evidenceIds,
      });
    }
    const importing = jobs.some(
      (j) =>
        (j.data as any).type === "transaction.import" &&
        !["succeeded", "failed"].includes((j.data as any).status),
    );
    return {
      contractVersion: 1,
      projectionVersion: 3,
      changeChannel: store.changeChannel ?? null,
      revision,
      today,
      profile: p?.data ?? profile.parse({}),
      profileVersion: p?.version ?? 0,
      transactions,
      budgets: bs,
      budgetPeriods,
      goals,
      subscriptions,
      reminders,
      actions,
      accounts,
      connections,
      insights: importing ? [] : insights,
      conversations,
      jobs: jobs.map((j) => ({
        id: j.id,
        updatedAt: j.updatedAt,
        type: (j.data as any).type,
        status: (j.data as any).status,
        result: (j.data as any).result ?? null,
        error: (j.data as any).error ?? null,
        batchId:
          (j.data as any).type === "transaction.import"
            ? (j.data as any).payload.batchId
            : null,
        progress: importProgress(j.data as import("./jobs").Job),
      })),
      privacyJobs,
      receipts: receipts.map((r) => ({
        id: r.id,
        version: r.version,
        updatedAt: r.updatedAt,
        transactionId: r.data.transactionId,
        status: r.data.status,
        sha256: r.data.sha256,
        bytes: r.data.bytes,
        ...(r.data.status === "ready"
          ? { fileId: r.data.fileId, bucketId: r.data.bucketId }
          : {}),
      })),
      entitlements: {
        plus,
        connectionLimit: plus ? 3 : 1,
        aiAllowance: plus ? 30 : 3,
        cancellationAllowance: plus ? 3 : 0,
      },
      capabilities: flags,
      snapshot: {
        importing,
        revision,
        asOf: now.toISOString(),
        balanceMinor,
        heroLabel: "Remaining budget",
        heroMinor:
          target === null ? null : checkedSum([target, -budget.spentMinor]),
        monthlySubscriptionsMinor: checkedSum(
          subscriptions
            .filter((s) => s.decision === "confirmed")
            .map((s) => s.monthlyMinor),
        ),
        budget,
        coverage:
          (importing
            ? "Import in progress. Totals reflect records received so far. "
            : "") +
          (cash.length
            ? `${cash.length} connected USD cash account(s). Spending reflects saved transactions; unlinked accounts are not included. Bank balance source timestamps are unavailable.`
            : "Saved transactions only; connected balances are not yet included."),
      },
    };
  }
  throw new AppError(
    "SNAPSHOT_BUSY",
    "Your records are changing. Refresh again shortly.",
    409,
  );
}
export async function execute(
  store: UserStore,
  input: CommandEnvelope,
  flags: Capabilities,
  now = new Date(),
) {
  return store.mutate(
    input.mutationId,
    fingerprint(input.command),
    async (tx) => {
      const privacy = await tx.get<{ type: string }>("privacy_jobs", "current");
      if (privacy && !privacy.deleted && privacy.data.type === "delete")
        throw new AppError(
          "ACCOUNT_DELETING",
          "New work is stopped while this account is being deleted.",
          410,
        );
      const c = input.command;
      switch (c.type) {
        case "review.weekly":
          return queueWeeklyReview(tx, now);
        case "transaction.import":
          return queueImport(tx, c);
        case "transaction.import.resume":
          return resumeImport(tx, c.id);
        case "receipt.attach":
          throw new AppError(
            "INVALID_REQUEST",
            "Receipt uploads require the authenticated storage boundary.",
          );
        case "receipt.cancel": {
          const row = await tx.get<Receipt>("receipts", c.id);
          if (!row) {
            await tx.put("receipts", c.id, { cancelled: true }, 0);
            await tx.remove("receipts", c.id, 1);
            return { id: c.id, status: "removed" };
          }
          if (row.deleted) return { id: c.id, status: "removed" };
          await tx.put(
            "receipts",
            c.id,
            { ...row.data, status: "removing" },
            row.version,
          );
          await schedule(
            tx,
            "receipt.reconcile",
            `cancel:${c.id}:${row.version}`,
            { receiptId: c.id },
            new Date(
              Math.max(
                now.getTime(),
                row.data.leaseUntil
                  ? (Date.parse(row.data.leaseUntil) || now.getTime()) + 30000
                  : 0,
              ),
            ),
          );
          return { id: c.id, status: "removing" };
        }
        case "receipt.remove": {
          const row = await tx.get<Receipt>("receipts", c.id);
          if (!row || row.deleted)
            throw new AppError("NOT_FOUND", "Receipt not found.", 404);
          await tx.put(
            "receipts",
            c.id,
            { ...row.data, status: "removing" },
            c.expectedVersion,
          );
          await schedule(
            tx,
            "receipt.reconcile",
            `remove:${c.id}:${row.version}`,
            { receiptId: c.id },
            new Date(
              Math.max(
                now.getTime(),
                row.data.leaseUntil
                  ? (Date.parse(row.data.leaseUntil) || now.getTime()) + 30000
                  : 0,
              ),
            ),
          );
          return { id: c.id, status: "removing" };
        }
        case "transaction.upsert": {
          if (c.transaction.source === "plaid" || c.transaction.providerId)
            throw new AppError(
              "PROVIDER_OWNED",
              "Bank transactions must be reconciled by the provider worker.",
              403,
            );
          const old = await tx.get<Transaction>(
            "transactions",
            c.transaction.id,
          );
          if (old && !old.deleted && old.data.source === "plaid")
            throw new AppError(
              "PROVIDER_OWNED",
              "Use a separate annotation to correct a bank transaction.",
              403,
            );
          const result = await tx.put(
            "transactions",
            c.transaction.id,
            transaction.parse(c.transaction),
            c.expectedVersion,
          );
          await requestReminderPlan(tx, now);
          return result;
        }
        case "transaction.delete": {
          const old = await tx.get<Transaction>("transactions", c.id);
          if (old && !old.deleted && old.data.source === "plaid")
            throw new AppError(
              "PROVIDER_OWNED",
              "Bank transactions cannot be deleted by a client.",
              403,
            );
          await tx.remove("transactions", c.id, c.expectedVersion);
          if (
            (await tx.list<Receipt>("receipts")).some(
              (r) => r.data.transactionId === c.id,
            )
          )
            await schedule(
              tx,
              "receipt.cleanup",
              `${c.id}:${c.expectedVersion}`,
              { transactionId: c.id },
            );
          await requestReminderPlan(tx, now);
          return { id: c.id, deleted: true };
        }
        case "profile.update": {
          const current = await tx.get<Profile>("profiles", "current");
          const preferences = {
            ...c.profile,
            budgetAlerts: c.profile.budgetAlerts ?? current?.data.budgetAlerts,
            forecastAlerts:
              c.profile.forecastAlerts ?? current?.data.forecastAlerts,
            quietHours: c.profile.quietHours ?? current?.data.quietHours,
          };
          const result = await tx.put(
            "profiles",
            "current",
            preferences,
            c.expectedVersion,
          );
          await requestReminderPlan(tx, now);
          return result;
        }
        case "goal.upsert":
          return tx.put("goals", c.goal.id, c.goal, c.expectedVersion);
        case "budget.upsert": {
          const value = { ...c.budget, category: c.budget.category.trim() };
          if (!value.category)
            throw new AppError(
              "INVALID_REQUEST",
              "Enter a category name.",
              400,
            );
          // The per-user transaction guard serializes this logical uniqueness
          // check, including two offline devices creating different client IDs.
          const peers = await tx.list<Budget>("budgets");
          if (
            peers.some(
              (b) =>
                b.id !== value.id &&
                b.data.month === value.month &&
                categoryKey(b.data.category) === categoryKey(value.category),
            )
          )
            throw new AppError(
              "VERSION_CONFLICT",
              "A budget already exists for this category and month. Refresh and edit that budget.",
              409,
            );
          return tx.put("budgets", value.id, value, c.expectedVersion);
        }
        case "recurring.decide": {
          const candidates = detectRecurring(
            (await tx.list<Transaction>("transactions")).map((r) => r.data),
          );
          if (!candidates.some((r) => r.id === c.id))
            throw new AppError(
              "STALE_EVIDENCE",
              "This recurring candidate is no longer supported. Refresh.",
              409,
            );
          const result = await tx.put(
            "recurring_decisions",
            c.id,
            { decision: c.decision },
            c.expectedVersion,
          );
          await requestReminderPlan(tx, now);
          return result;
        }
        case "reminder.set": {
          if (c.enabled && !flags.notifications)
            throw new AppError(
              "CAPABILITY_UNAVAILABLE",
              "Reminder delivery has not been configured for this environment.",
              503,
            );
          const result = await planReminder(
            tx,
            c.subscriptionId,
            { enabled: c.enabled, daysBefore: c.daysBefore },
            now,
          );
          await requestReminderPlan(tx, now);
          return result;
        }
        case "action.propose": {
          if (!flags.cancellation)
            throw new AppError(
              "CAPABILITY_UNAVAILABLE",
              "Direct cancellation is awaiting verified provider coverage.",
              503,
            );
          if (!(await plusEntitlement(tx, now)))
            throw new AppError(
              "PLUS_REQUIRED",
              "Cancellation requires Sprout Plus.",
              403,
            );
          const s = detectRecurring(
            (await tx.list<Transaction>("transactions")).map((r) => r.data),
          ).find((s) => s.id === c.subscriptionId);
          if (!s)
            throw new AppError(
              "STALE_EVIDENCE",
              "Subscription evidence changed.",
              409,
            );
          if (!(await cancellationPartner.eligibility(s.merchant)).supported)
            throw new AppError(
              "UNSUPPORTED_MERCHANT",
              "Verified cancellation coverage is unavailable for this merchant.",
              403,
            );
          const existing = (await tx.list<Action>("actions")).find(
            (a) => a.data.subscriptionId === s.id && a.data.state !== "failed",
          );
          if (existing) return existing;
          const proposed = await tx.put<Action>(
            "actions",
            fingerprint([s.id, s.evidenceHash, input.mutationId]).slice(0, 32),
            {
              subscriptionId: s.id,
              merchant: s.merchant,
              state: "proposed",
              evidenceHash: s.evidenceHash,
            },
            0,
          );
          await tx.put(
            "action_events",
            fingerprint([proposed.id, proposed.version]).slice(0, 36),
            {
              actionId: proposed.id,
              state: "proposed",
              version: proposed.version,
              evidenceHash: s.evidenceHash,
              at: now.toISOString(),
            },
            0,
          );
          return proposed;
        }
        case "action.approve": {
          const action = await tx.get<Action>("actions", c.id);
          if (!flags.cancellation || !(await plusEntitlement(tx, now)))
            throw new AppError(
              "CAPABILITY_UNAVAILABLE",
              "Cancellation is unavailable.",
              403,
            );
          if (
            !action ||
            action.data.state !== "proposed" ||
            action.data.evidenceHash !== c.evidenceHash
          )
            throw new AppError(
              "STALE_APPROVAL",
              "Refresh the action before approving.",
              409,
            );
          const s = detectRecurring(
            (await tx.list<Transaction>("transactions")).map((r) => r.data),
          ).find((s) => s.id === action.data.subscriptionId);
          if (!s || s.evidenceHash !== c.evidenceHash)
            throw new AppError(
              "STALE_EVIDENCE",
              "Subscription evidence changed.",
              409,
            );
          if (!(await cancellationPartner.eligibility(s.merchant)).supported)
            throw new AppError(
              "UNSUPPORTED_MERCHANT",
              "Verified cancellation coverage is unavailable for this merchant.",
              403,
            );
          const month = now.toISOString().slice(0, 7);
          const usage = await tx.get<{ cancellationReservations?: number }>(
            "usage",
            month,
          );
          if ((usage?.data.cancellationReservations ?? 0) >= 3)
            throw new AppError(
              "QUOTA_EXCEEDED",
              "Your monthly cancellation allowance is fully reserved or used.",
              429,
            );
          await tx.put(
            "usage",
            month,
            {
              ...usage?.data,
              cancellationReservations:
                (usage?.data.cancellationReservations ?? 0) + 1,
            },
            usage?.version ?? 0,
          );
          const approved = await tx.put(
            "actions",
            c.id,
            {
              ...action.data,
              state: "approved",
              approvalExpiresAt: new Date(
                now.getTime() + 86400000,
              ).toISOString(),
            },
            c.expectedVersion,
          );
          await tx.put(
            "action_events",
            fingerprint([approved.id, approved.version]).slice(0, 36),
            {
              actionId: approved.id,
              state: "approved",
              version: approved.version,
              evidenceHash: s.evidenceHash,
              at: now.toISOString(),
            },
            0,
          );
          return approved;
        }
        case "insight.feedback":
          return tx.put("insight_feedback", c.id, {
            feedback: c.feedback,
            at: now.toISOString(),
            ...(c.feedback === "snoozed"
              ? { until: new Date(now.getTime() + 7 * 86400000).toISOString() }
              : {}),
          });
      }
    },
  );
}
