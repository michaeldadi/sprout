import { Query } from "node-appwrite";
import { randomUUID } from "node:crypto";
import { AppError, type Transaction, type Capabilities } from "../contracts";
import {
  AppwriteStore,
  privateGet,
  privatePut,
} from "../integrations/appwrite-store";
import {
  PlaidClient,
  sealToken,
  openToken,
  bankFact,
  assertTokenConfiguration,
} from "../integrations/plaid";
import { fingerprint } from "./finance";
import { plusEntitlement } from "./application";
import { schedule } from "./jobs";
import { requestReminderPlan } from "./reminders";

export interface Connection {
  itemId: string;
  status:
    | "exchanging"
    | "connected"
    | "importing"
    | "ready"
    | "repair"
    | "disconnected";
  cursor?: string;
  sourceAsOf?: string;
  /** Retrieval time is not a claim about when the institution refreshed its data. */
  retrievedAt?: string;
  leaseId?: string;
  leaseUntil?: string;
  exchangeNonce?: string;
}

export async function repairSession(
  store: AppwriteStore,
  connectionId: string,
  platform: "ios" | "android",
) {
  const current = await store.get<Connection>("connections", connectionId);
  if (!current || current.deleted || current.data.status === "disconnected")
    throw new AppError("NOT_FOUND", "Connection not found.", 404);
  const credential = await privateGet<{ sealed: string }>(
    store,
    "provider_credentials",
    connectionId,
  );
  if (!credential)
    throw new AppError(
      "LINK_RECOVERY",
      "This connection has no recoverable provider credential. Contact support to release the pending reservation.",
      409,
    );
  return new PlaidClient().linkToken(
    store.owner,
    platform,
    openToken(credential.sealed, store.owner, connectionId),
  );
}
export async function repairedConnection(
  store: AppwriteStore,
  connectionId: string,
  requestId: string,
) {
  const credential = await privateGet<{ sealed: string }>(
    store,
    "provider_credentials",
    connectionId,
  );
  if (!credential)
    throw new AppError("NOT_FOUND", "Connection not found.", 404);
  await new PlaidClient().post("/item/get", {
    access_token: openToken(credential.sealed, store.owner, connectionId),
  });
  return store.mutate(
    `repair:${requestId}`,
    fingerprint(connectionId),
    async (tx) => {
      const current = await tx.get<Connection>("connections", connectionId);
      if (!current || current.deleted || current.data.status === "disconnected")
        throw new AppError("NOT_FOUND", "Connection not found.", 404);
      const job = await schedule(tx, "bank.sync", `repair:${requestId}`, {
        connectionId,
      });
      return { connectionId, jobId: job.id, status: "connected" };
    },
  );
}
export async function linkSession(
  store: AppwriteStore,
  platform: "ios" | "android",
  flags: Capabilities,
) {
  assertTokenConfiguration();
  if (!flags.linking)
    throw new AppError(
      "CAPABILITY_UNAVAILABLE",
      "Bank linking is not enabled.",
      503,
    );
  const count = (await store.list<Connection>("connections")).filter(
    (c) => c.data.status !== "disconnected",
  ).length;
  const allowance = (await plusEntitlement(store, new Date())) ? 3 : 1;
  if (count >= allowance)
    throw new AppError(
      "CONNECTION_LIMIT",
      "Choose an existing connection to keep live, or upgrade before adding another.",
      403,
    );
  return new PlaidClient().linkToken(store.owner, platform);
}
export async function exchangeConnection(
  store: AppwriteStore,
  publicToken: string,
  requestId: string,
  flags: Capabilities,
) {
  assertTokenConfiguration();
  if (!flags.linking)
    throw new AppError(
      "CAPABILITY_UNAVAILABLE",
      "Bank linking is not enabled.",
      503,
    );
  const exchangeNonce = randomUUID();
  const reservation = await store.mutate(
    `link:${requestId}`,
    fingerprint(publicToken),
    async (tx) => {
      const connections = await tx.list<Connection>("connections");
      const allowance = (await plusEntitlement(tx, new Date())) ? 3 : 1;
      if (
        connections.filter((c) => c.data.status !== "disconnected").length >=
        allowance
      )
        throw new AppError(
          "CONNECTION_LIMIT",
          "Connection allowance reached.",
          403,
        );
      return tx.put<Connection>(
        "connections",
        requestId,
        {
          itemId: `reserved:${requestId}`,
          status: "exchanging",
          exchangeNonce,
        },
        0,
      );
    },
  );
  const previous = await privateGet<{ sealed: string; itemId: string }>(
    store,
    "provider_credentials",
    requestId,
  );
  // A lost exchange response is not retried automatically against a one-use token.
  // An exchanging reservation with no credential needs Link recovery/support.
  if (!previous && reservation.data.exchangeNonce !== exchangeNonce)
    throw new AppError(
      "LINK_RECOVERY",
      "The exchange outcome needs recovery. Do not resubmit this token.",
      409,
    );
  const result: { sealed: string; itemId: string } =
    previous ??
    (await new PlaidClient().exchange(publicToken).then((r) => ({
      sealed: sealToken(r.access_token, store.owner, requestId),
      itemId: r.item_id,
    })));
  await privatePut(store, "provider_credentials", requestId, result);
  return store.mutate(
    `linked:${requestId}`,
    fingerprint(result.itemId),
    async (tx) => {
      const current = await tx.get<Connection>("connections", requestId);
      if (!current || current.data.status !== "exchanging")
        throw new AppError(
          "LINK_STATE",
          "Connection is no longer awaiting exchange.",
          409,
        );
      const connection = await tx.put<Connection>(
        "connections",
        requestId,
        { itemId: result.itemId, status: "connected" },
        current.version,
      );
      const job = await schedule(tx, "bank.sync", `initial:${requestId}`, {
        connectionId: requestId,
      });
      return { connection, jobId: job.id };
    },
  );
}
export async function ingestConnection(
  store: AppwriteStore,
  connectionId: string,
  leaseId: string,
) {
  const started = await store.mutate(
    `bank-start:${leaseId}`,
    fingerprint(connectionId),
    async (tx) => {
      const current = await tx.get<Connection>("connections", connectionId);
      if (!current || current.deleted || current.data.status === "disconnected")
        throw new AppError("NOT_FOUND", "Connection is unavailable.", 404);
      if (
        current.data.leaseUntil &&
        Date.parse(current.data.leaseUntil) > Date.now() &&
        current.data.leaseId !== leaseId
      )
        throw new AppError("BANK_BUSY", "Another ingestion is running.", 409);
      return tx.put<Connection>(
        "connections",
        connectionId,
        {
          ...current.data,
          status: "importing",
          leaseId,
          leaseUntil: new Date(Date.now() + 240_000).toISOString(),
        },
        current.version,
      );
    },
  );
  const credential = await privateGet<{ sealed: string }>(
    store,
    "provider_credentials",
    connectionId,
  );
  if (!credential)
    throw new AppError(
      "CONNECTION_REPAIR",
      "Reconnect this bank to continue.",
      409,
    );
  const provider = new PlaidClient();
  const cycle = await provider.syncCycle(
    openToken(credential.sealed, store.owner, connectionId),
    started.data.cursor,
  );
  const accountData = await provider.accounts(
    openToken(credential.sealed, store.owner, connectionId),
  );
  const operations = [
    ...cycle.added.map((t) => ({ kind: "upsert" as const, t })),
    ...cycle.modified.map((t) => ({ kind: "upsert" as const, t })),
    ...cycle.removed.map((t) => ({ kind: "remove" as const, t })),
  ];
  for (let offset = 0; offset < operations.length; offset += 15) {
    const batch = operations.slice(offset, offset + 15);
    await store.mutate(
      `bank:${fingerprint([connectionId, started.data.cursor, cycle.cursor, batch]).slice(0, 48)}`,
      fingerprint(batch),
      async (tx) => {
        const connection = await tx.get<Connection>(
          "connections",
          connectionId,
        );
        if (connection?.data.leaseId !== leaseId)
          throw new AppError(
            "LEASE_LOST",
            "Bank ingestion lease expired.",
            409,
          );
        for (const operation of batch) {
          if (operation.kind === "upsert") {
            const fact = bankFact(operation.t, connectionId);
            if (fact.pendingTransactionId) {
              // bankFact uses a raw provider ID hash, matching the original pending fact.
              const pending = (await tx.list<Transaction>("transactions")).find(
                (r) =>
                  r.data.providerId === fact.pendingTransactionId &&
                  r.data.accountId === fact.accountId,
              );
              if (pending)
                await tx.remove("transactions", pending.id, pending.version);
            }
            await tx.put("transactions", fact.id, fact);
          } else {
            const current = (await tx.list<Transaction>("transactions")).find(
              (r) => r.data.providerId === operation.t.transaction_id,
            );
            if (current)
              await tx.remove("transactions", current.id, current.version);
          }
        }
        return { applied: batch.length };
      },
    );
  }
  for (const account of accountData.accounts) {
    if (account.balances.iso_currency_code !== "USD") continue;
    await store.mutate(
      `account:${fingerprint([connectionId, cycle.cursor, account]).slice(0, 48)}`,
      fingerprint(account),
      async (tx) => {
        const connection = await tx.get<Connection>(
          "connections",
          connectionId,
        );
        if (connection?.data.leaseId !== leaseId)
          throw new AppError(
            "LEASE_LOST",
            "Bank ingestion lease expired.",
            409,
          );
        return tx.put("accounts", account.account_id, {
          connectionId,
          providerId: account.account_id,
          name: account.name,
          mask: account.mask,
          type: account.type,
          subtype: account.subtype,
          currency: "USD",
          currentMinor:
            account.balances.current === null
              ? null
              : Math.round(account.balances.current * 100),
          availableMinor:
            account.balances.available === null
              ? null
              : Math.round(account.balances.available * 100),
          retrievedAt: new Date().toISOString(),
        });
      },
    );
  }
  return store.mutate(
    `bank-finish:${leaseId}`,
    fingerprint(cycle.cursor),
    async (tx) => {
      const current = await tx.get<Connection>("connections", connectionId);
      if (current?.data.leaseId !== leaseId)
        throw new AppError("LEASE_LOST", "Bank ingestion lease expired.", 409);
      const result = await tx.put<Connection>(
        "connections",
        connectionId,
        {
          itemId: current.data.itemId,
          status: "ready",
          cursor: cycle.cursor,
          retrievedAt: new Date().toISOString(),
        },
        current.version,
      );
      await requestReminderPlan(tx);
      return result;
    },
  );
}
