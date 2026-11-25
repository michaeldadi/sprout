import { randomUUID } from "node:crypto";
import { z } from "zod";
import {
  AppError,
  id,
  profile,
  type Profile,
  type Transaction,
} from "../contracts";
import { AppwriteStore } from "../integrations/appwrite-store";
import {
  deliverReminder,
  deliverWeeklyReview,
} from "../integrations/notifications";
import { cancellationPartner } from "../integrations/cancellation";
import { claim, defer, finish } from "../domain/jobs";
import { nextAllowedDelivery } from "../domain/calendar";
import {
  planReminder,
  reconcileReminders,
  renewalOccurrence,
} from "../domain/reminders";
import { applyImport } from "../domain/imports";
import { ingestConnection } from "../domain/banking";
import { detectRecurring, fingerprint } from "../domain/finance";
import { prepareWeeklyReview, weeklyPolicyHash } from "../domain/weekly";
import { failure, rawBody, serviceKey, type FunctionContext } from "./context";

export default async function main(context: FunctionContext) {
  try {
    const input = z
      .object({ owner: id, jobId: id })
      .strict()
      .parse(JSON.parse(rawBody(context)));
    const control = new AppwriteStore(input.owner, serviceKey(context), true);
    const store = new AppwriteStore(input.owner, serviceKey(context));
    const token = randomUUID();
    const job = await claim(control, input.jobId, token);
    if (!job)
      return context.res.json({ status: "already_claimed_or_finished" });
    try {
      const deletion = await store.get<{ type: string }>(
        "privacy_jobs",
        "current",
      );
      if (
        deletion?.data.type === "delete" &&
        job.data.type !== "action.reconcile"
      )
        throw new AppError(
          "ACCOUNT_DELETING",
          "New work is stopped for this account.",
          410,
        );
      let result: unknown;
      if (job.data.type === "transaction.import")
        result = await applyImport(store, job.id, token);
      else if (job.data.type === "notification.plan")
        result = await reconcileReminders(store, job.id, token);
      else if (job.data.type === "bank.sync")
        result = await ingestConnection(
          store,
          z.string().parse(job.data.payload.connectionId),
          token,
        );
      else if (
        job.data.type === "digest.deliver" ||
        job.data.type === "review.prepare"
      ) {
        const review = await prepareWeeklyReview(store, job.id, token);
        if (review.status === "incomplete") {
          await defer(
            control,
            job.id,
            token,
            new Date(Date.now() + 6 * 3_600_000),
            "INCOMPLETE_HISTORY",
          );
          return context.res.json({ status: "deferred" });
        }
        if (review.status !== "ready" || review.accepted) {
          await finish(control, job.id, token, {
            status:
              review.status === "ready" ? "already_accepted" : review.status,
            delivered: false,
          });
          return context.res.json({ status: "finished" });
        }
        if (job.data.type === "review.prepare") {
          await finish(control, job.id, token, {
            status: "prepared",
            delivered: false,
          });
          return context.res.json({ status: "prepared" });
        }
        const preferencesRow = await store.get<Profile>("profiles", "current"),
          preferences = profile.parse(preferencesRow?.data ?? {}),
          now = new Date();
        if (
          !preferences.weeklyDigest ||
          weeklyPolicyHash(preferences) !== job.data.payload.policyHash
        ) {
          await finish(control, job.id, token, {
            status: "superseded",
            delivered: false,
          });
          return context.res.json({ status: "superseded" });
        }
        const allowed =
          process.env.SPROUT_NOTIFICATIONS !== "true"
            ? new Date(now.getTime() + 24 * 3_600_000)
            : nextAllowedDelivery(
                now,
                preferences.timezone,
                preferences.quietHours ?? undefined,
              );
        if (allowed.getTime() > now.getTime()) {
          await defer(
            control,
            job.id,
            token,
            allowed,
            process.env.SPROUT_NOTIFICATIONS !== "true"
              ? "DELIVERY_PAUSED"
              : "QUIET_HOURS",
            now,
          );
          return context.res.json({ status: "deferred" });
        }
        await store.assertWritable();
        result = await deliverWeeklyReview(input.owner, review.occurrenceId);
        await control.mutate(
          `notification:${review.occurrenceId}`,
          fingerprint(result),
          async (tx) => {
            const current = (await tx.get<Record<string, unknown>>(
              "notifications",
              review.occurrenceId,
            ))!;
            return tx.put(
              "notifications",
              current.id,
              {
                ...current.data,
                ...(result as object),
                attemptedAt: now.toISOString(),
              },
              current.version,
            );
          },
        );
      } else if (job.data.type === "reminder.deliver") {
        const reminder = await store.get<{
          enabled: boolean;
          evidenceHash: string;
          jobId: string;
        }>("reminders", String(job.data.payload.subscriptionId));
        const stream = detectRecurring(
          (await store.list<Transaction>("transactions")).map((t) => t.data),
        ).find((s) => s.id === job.data.payload.subscriptionId);
        if (!reminder?.data.enabled || reminder.data.jobId !== job.id)
          result = { status: "superseded", delivered: false };
        else {
          const planned = await store.mutate(
            `verify-reminder:${job.id}:${token}`,
            fingerprint(job.id),
            (tx) => planReminder(tx, reminder.id),
          );
          if (
            !planned ||
            planned.data.jobId !== job.id ||
            !stream ||
            stream.evidenceHash !== planned.data.evidenceHash
          ) {
            const status = planned?.data.status ?? "superseded";
            await finish(control, job.id, token, { status, delivered: false });
            return context.res.json({ status });
          }
          if (process.env.SPROUT_NOTIFICATIONS !== "true") {
            await defer(
              control,
              job.id,
              token,
              new Date(Date.now() + 24 * 3_600_000),
              "DELIVERY_PAUSED",
            );
            return context.res.json({ status: "deferred" });
          }
          const preferences = profile.parse(
            (await store.get("profiles", "current"))?.data ?? {},
          );
          if (!preferences.renewalAlerts) {
            await control.mutate(
              `reminder-muted:${job.id}:${reminder.version}`,
              fingerprint([job.id, reminder.version]),
              async (tx) => {
                const current = await tx.get<{ jobId: string }>(
                  "reminders",
                  reminder.id,
                );
                if (current?.data.jobId === job.id)
                  await tx.put(
                    "reminders",
                    current.id,
                    { ...current.data, status: "muted" },
                    current.version,
                  );
                return { status: "muted" };
              },
            );
            await finish(control, job.id, token, {
              status: "muted",
              delivered: false,
            });
            return context.res.json({ status: "muted" });
          }
          const now = new Date(),
            allowed = nextAllowedDelivery(
              now,
              preferences.timezone,
              preferences.quietHours ?? undefined,
            );
          if (allowed.getTime() > now.getTime()) {
            await defer(control, job.id, token, allowed, "QUIET_HOURS", now);
            return context.res.json({ status: "deferred" });
          }
          // A changed reminder rule is still the same renewal occurrence.
          const occurrenceId = renewalOccurrence(stream.id, stream.nextDate);
          const accepted = await store.get<{
            status: string;
            providerReference?: string;
          }>("notifications", occurrenceId);
          if (
            accepted &&
            ["accepted", "delivered"].includes(accepted.data.status)
          ) {
            await finish(control, job.id, token, {
              status: "already_accepted",
              delivered: accepted.data.status === "delivered",
            });
            return context.res.json({ status: "already_accepted" });
          }
          await store.assertWritable();
          result = await deliverReminder(input.owner, occurrenceId);
          // Retain authoritative provider acceptance even if deletion began in flight.
          await control.mutate(
            `notification:${occurrenceId}`,
            fingerprint(result),
            async (tx) =>
              tx.put("notifications", occurrenceId, {
                ...(result as object),
                subscriptionId: job.data.payload.subscriptionId,
                renewalDate: stream.nextDate,
                jobId: job.id,
                attemptedAt: new Date().toISOString(),
              }),
          );
        }
      } else if (job.data.type === "action.reconcile")
        result = await cancellationPartner.reconcile(
          String(job.data.payload.providerReference),
        );
      else
        throw new AppError(
          "INVALID_JOB",
          "This worker does not handle this job type.",
        );
      await finish(control, job.id, token, result);
      return context.res.json({ status: "succeeded" });
    } catch (error) {
      await finish(
        control,
        job.id,
        token,
        null,
        error instanceof AppError ? error.code : "WORKER_RETRY",
      );
      return context.res.json({ status: "retry_or_attention" }, 202);
    }
  } catch (error) {
    return failure(context.res, error);
  }
}
