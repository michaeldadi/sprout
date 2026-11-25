import { timingSafeEqual } from "node:crypto";
import { Query } from "node-appwrite";
import { z } from "zod";
import { AppError, id } from "../contracts";
import { AppwriteStore, privatePut } from "../integrations/appwrite-store";
import { PlaidClient } from "../integrations/plaid";
import { schedule } from "../domain/jobs";
import { fingerprint } from "../domain/finance";
import { failure, rawBody, serviceKey, type FunctionContext } from "./context";

const secretMatches = (
  actual: string | undefined,
  expected: string | undefined,
) =>
  !!actual &&
  !!expected &&
  Buffer.byteLength(actual) === Buffer.byteLength(expected) &&
  timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
export default async function main(context: FunctionContext) {
  try {
    if (context.req.method !== "POST")
      throw new AppError("METHOD_NOT_ALLOWED", "Use POST.", 405);
    const raw = rawBody(context);
    const path = new URL(context.req.path, "https://sprout.invalid").pathname;
    const key = serviceKey(context);
    if (path === "/plaid") {
      await new PlaidClient().verifyWebhook(
        raw,
        context.req.headers["plaid-verification"] ?? "",
      );
      const body = z
        .object({
          item_id: z.string().max(160),
          webhook_type: z.string(),
          webhook_code: z.string(),
        })
        .passthrough()
        .parse(JSON.parse(raw));
      const system = new AppwriteStore("system", key);
      const receiptId = fingerprint(raw).slice(0, 36);
      await privatePut(system, "webhook_receipts", receiptId, {
        provider: "plaid",
        receivedAt: new Date().toISOString(),
        body,
      });
      const connections = await system.tables.listRows({
        databaseId: system.database,
        tableId: "connections",
        queries: [
          Query.equal("provider_reference", body.item_id),
          Query.limit(2),
        ],
      });
      if (connections.rows.length === 1) {
        const row = connections.rows[0];
        const store = new AppwriteStore(String(row.owner), key);
        try {
          await store.mutate(
            `plaid-event:${receiptId}`,
            fingerprint(body),
            async (tx) =>
              schedule(tx, "bank.sync", receiptId, {
                connectionId: row.entity_id,
              }),
          );
        } catch (e) {
          if (!(e instanceof AppError && e.code === "ACCOUNT_DELETING"))
            throw e;
        }
      }
      return context.res.json({ accepted: true }, 202);
    }
    if (path === "/revenuecat") {
      if (
        !secretMatches(
          context.req.headers.authorization,
          process.env.REVENUECAT_WEBHOOK_AUTHORIZATION,
        )
      )
        throw new AppError(
          "INVALID_SIGNATURE",
          "Webhook authorization failed.",
          401,
        );
      const { event } = z
        .object({
          event: z
            .object({
              id: z.string().max(160),
              app_user_id: id,
              type: z.string(),
              environment: z.string(),
              event_timestamp_ms: z.number().int(),
              expiration_at_ms: z.number().int().nullable().optional(),
              grace_period_expiration_at_ms: z
                .number()
                .int()
                .nullable()
                .optional(),
              entitlement_ids: z.array(z.string()).nullable().optional(),
            })
            .passthrough(),
        })
        .parse(JSON.parse(raw));
      if (
        process.env.SPROUT_ENVIRONMENT === "production" &&
        event.environment !== "PRODUCTION"
      )
        return context.res.json({ accepted: true, ignored: "sandbox" }, 202);
      const store = new AppwriteStore(event.app_user_id, key);
      await privatePut(
        store,
        "webhook_receipts",
        fingerprint(event.id).slice(0, 36),
        {
          provider: "revenuecat",
          eventId: event.id,
          type: event.type,
          receivedAt: new Date().toISOString(),
        },
      );
      const entitlement =
        process.env.REVENUECAT_ENTITLEMENT_ID ?? "sprout_plus";
      if (event.entitlement_ids?.includes(entitlement)) {
        try {
          await store.mutate(
            `revenuecat:${fingerprint(event.id).slice(0, 40)}`,
            fingerprint(event),
            async (tx) => {
              const current = await tx.get<{ eventTimestamp: number }>(
                "entitlements",
                "current",
              );
              if (
                (current?.data.eventTimestamp ?? 0) >= event.event_timestamp_ms
              )
                return { ignored: true };
              const expiry = Math.max(
                event.expiration_at_ms ?? 0,
                event.grace_period_expiration_at_ms ?? 0,
              );
              const plus = expiry > Date.now() && event.type !== "EXPIRATION";
              return tx.put(
                "entitlements",
                "current",
                {
                  plus,
                  expiresAt: expiry ? new Date(expiry).toISOString() : null,
                  verifiedAt: new Date().toISOString(),
                  eventTimestamp: event.event_timestamp_ms,
                  source: "revenuecat",
                },
                current?.version ?? 0,
              );
            },
          );
        } catch (e) {
          if (!(e instanceof AppError && e.code === "ACCOUNT_DELETING"))
            throw e;
        }
      }
      return context.res.json({ accepted: true }, 202);
    }
    throw new AppError("NOT_FOUND", "Unknown webhook provider.", 404);
  } catch (error) {
    return failure(context.res, error);
  }
}
