import { deletionReceipt, privacyHash } from "../domain/privacy";
import { PrivacyLedger } from "../integrations/privacy-ledger";
import { z } from "zod";
import { AppError, capabilities, envelope } from "../contracts";
import { AppwriteStore, authenticate } from "../integrations/appwrite-store";
import { execute, workspace } from "../domain/application";
import { parseExpenseText } from "../domain/finance";
import { fingerprint } from "../domain/finance";
import { schedule, type Job } from "../domain/jobs";
import { importProgress } from "../domain/imports";
import { plusEntitlement } from "../domain/application";
import { linkSession, exchangeConnection } from "../domain/banking";
import { repairSession, repairedConnection } from "../domain/banking";
import { syncCursor, syncPage } from "../domain/sync";
import { wakeDispatcher } from "../integrations/dispatch";
import { invokeReceiptActor } from "../integrations/receipt-actor";
import { failure } from "./context";

interface Context {
  req: {
    path: string;
    queryString?: string;
    method: string;
    headers: Record<string, string>;
    bodyText?: string;
    bodyJson?: unknown;
  };
  res: { json: (value: unknown, status?: number) => unknown };
}
export default async function main({ req, res }: Context) {
  try {
    const user = await authenticate(req.headers["x-appwrite-user-jwt"]);
    if (req.headers["x-sprout-account"] !== user.id)
      throw new AppError(
        "ACCOUNT_CHANGED",
        "The signed-in account changed. No records were read or changed.",
        409,
      );
    const serviceKey =
      req.headers["x-appwrite-key"] ??
      process.env.APPWRITE_FUNCTION_API_KEY ??
      "";
    const store = new AppwriteStore(user.id, serviceKey);
    const url = new URL(req.path, "https://sprout.invalid");
    // Appwrite supplies req.path without the query portion.
    if (req.queryString) url.search = req.queryString;
    const flags = capabilities();
    if (req.method === "GET" && url.pathname === "/v1/bootstrap") {
      const snapshot = await workspace(store, flags);
      return res.json({
        ...snapshot,
        accountId: user.id,
        cursor: syncCursor(user.id, snapshot.revision),
      });
    }
    if (req.method === "GET" && url.pathname === "/v1/sync") {
      const cursor = z
        .string()
        .min(1)
        .max(2048)
        .parse(url.searchParams.get("cursor"));
      return res.json(await syncPage(store, user.id, flags, cursor));
    }
    if (req.method === "GET" && url.pathname.startsWith("/v1/jobs/")) {
      const id = z
        .string()
        .regex(/^[A-Za-z0-9_.:-]{1,128}$/)
        .parse(url.pathname.slice("/v1/jobs/".length));
      const job = await store.get<Job>("jobs", id);
      if (!job || job.deleted)
        throw new AppError("NOT_FOUND", "Job not found.", 404);
      return res.json({
        id: job.id,
        updatedAt: job.updatedAt,
        status: job.data.status,
        attempts: job.data.attempts,
        result: job.data.result ?? null,
        error: job.data.error ?? null,
        progress: importProgress(job.data),
      });
    }
    let raw = req.bodyText ?? JSON.stringify(req.bodyJson ?? {});
    if (
      Buffer.byteLength(raw) >
      (url.pathname === "/v1/commands" ? 1_000_000 : 100_000)
    )
      throw new AppError("PAYLOAD_TOO_LARGE", "Request is too large.", 413);
    if (req.method === "POST") {
      const body = z.record(z.string(), z.unknown()).parse(JSON.parse(raw));
      if (body._account !== user.id)
        throw new AppError(
          "ACCOUNT_CHANGED",
          "This change belongs to a different signed-in account. Sign in to its original account before retrying.",
          409,
        );
      delete body._account;
      raw = JSON.stringify(body);
      if (
        url.pathname !== "/v1/privacy" &&
        process.env.SPROUT_FINANCIAL_WRITES !== "true"
      )
        throw new AppError(
          "CONSISTENCY_GATE",
          "Financial sync is awaiting staged consistency verification. Your local change can be retried after setup is complete.",
          503,
        );
    }
    // Reject before provider session creation or other external work, not only
    // when a later canonical mutation attempts to commit.
    if (req.method === "POST" && url.pathname !== "/v1/privacy")
      await store.assertWritable();
    if (req.method === "POST" && url.pathname === "/v1/commands") {
      const input = envelope.parse(JSON.parse(raw));
      const result =
        input.command.type === "receipt.attach"
          ? await invokeReceiptActor(
              user.id,
              input.command,
              input.mutationId,
              serviceKey,
            )
          : await execute(store, input, flags);
      const importing =
        input.command.type === "transaction.import" ||
        input.command.type === "transaction.import.resume";
      if (
        importing ||
        ["receipt.remove", "receipt.cancel", "transaction.delete"].includes(
          input.command.type,
        )
      )
        await wakeDispatcher(serviceKey);
      return res.json(result, importing ? 202 : 200);
    }
    if (req.method === "POST" && url.pathname === "/v1/bank/link-token") {
      const input = z
        .object({ platform: z.enum(["ios", "android"]) })
        .strict()
        .parse(JSON.parse(raw));
      return res.json(await linkSession(store, input.platform, flags));
    }
    if (req.method === "POST" && url.pathname === "/v1/bank/exchange") {
      const input = z
        .object({
          publicToken: z.string().max(1000),
          requestId: z.string().uuid(),
        })
        .strict()
        .parse(JSON.parse(raw));
      const connection = await exchangeConnection(
        store,
        input.publicToken,
        input.requestId,
        flags,
      );
      await wakeDispatcher(serviceKey);
      return res.json(connection);
    }
    if (req.method === "POST" && url.pathname === "/v1/bank/repair") {
      const input = z
        .object({
          connectionId: z.string().uuid(),
          platform: z.enum(["ios", "android"]),
        })
        .strict()
        .parse(JSON.parse(raw));
      return res.json(
        await repairSession(store, input.connectionId, input.platform),
      );
    }
    if (req.method === "POST" && url.pathname === "/v1/bank/repaired") {
      const input = z
        .object({
          connectionId: z.string().uuid(),
          requestId: z.string().uuid(),
        })
        .strict()
        .parse(JSON.parse(raw));
      return res.json(
        await repairedConnection(store, input.connectionId, input.requestId),
      );
    }
    if (req.method === "POST" && url.pathname === "/v1/assistant") {
      if (!flags.ai)
        throw new AppError(
          "CAPABILITY_UNAVAILABLE",
          "AI is not enabled for this environment.",
          503,
        );
      const input = z
        .object({
          question: z.string().min(1).max(2000),
          context: z.string().max(160).nullable(),
          requestId: z.string().uuid(),
        })
        .strict()
        .parse(JSON.parse(raw));
      const result = await store.mutate(
        `assistant:${input.requestId}`,
        fingerprint(input),
        async (tx) => {
          const month = new Date().toISOString().slice(0, 7);
          const usage = await tx.get<{ ai: number }>("usage", month);
          const limit = (await plusEntitlement(tx, new Date())) ? 30 : 3;
          if ((usage?.data.ai ?? 0) >= limit)
            throw new AppError(
              "QUOTA_EXCEEDED",
              "Your monthly AI allowance has been used.",
              429,
            );
          await tx.put(
            "usage",
            month,
            { ...usage?.data, ai: (usage?.data.ai ?? 0) + 1 },
            usage?.version ?? 0,
          );
          const job = await schedule(tx, "assistant", input.requestId, input);
          return {
            id: job.id,
            status: job.data.status,
            message:
              "Your question is queued. Its result will appear in this conversation.",
          };
        },
      );
      await wakeDispatcher(serviceKey);
      return res.json(result, 202);
    }
    if (req.method === "POST" && url.pathname === "/v1/privacy") {
      const input = z
        .object({
          type: z.enum(["export", "delete"]),
          requestId: z.string().uuid(),
          receipt: deletionReceipt.optional(),
        })
        .strict()
        .parse(JSON.parse(raw));
      if (
        input.type === "delete" &&
        (process.env.SPROUT_FIRST_PARTY_ERASURE !== "true" || !input.receipt)
      )
        throw new AppError(
          "DELETION_PROOF_REQUIRED",
          "Account deletion is awaiting validation in this environment.",
          503,
        );
      const acceptedAt = new Date().toISOString();
      const result = await store.mutate(
        `privacy:${input.requestId}`,
        fingerprint(input),
        async (tx) => {
          if (input.type === "delete")
            await tx.put("privacy_jobs", "current", {
              type: "delete",
              status: "queued",
              acceptedAt,
            });
          const recentExport =
            input.type === "export"
              ? (await tx.list<Job>("jobs")).find(
                  (j) =>
                    j.data.type === "privacy.export" &&
                    ["queued", "running", "retry"].includes(j.data.status) &&
                    Date.parse(j.updatedAt) > Date.now() - 3_600_000,
                )
              : null;
          if (recentExport)
            return {
              id: recentExport.id,
              status: recentExport.data.status,
              reused: true,
            };
          const job = await schedule(
            tx,
            input.type === "export" ? "privacy.export" : "privacy.delete",
            input.requestId,
            input.type === "delete"
              ? { receiptHash: privacyHash(input.receipt!), acceptedAt }
              : {},
          );
          return { id: job.id, status: job.data.status, reused: false };
        },
      );
      if (input.type === "delete") {
        const job = await store.get<Job>("jobs", result.id);
        await new PrivacyLedger(serviceKey).accept(
          user.id,
          privacyHash(input.receipt!),
          String(job?.data.payload.acceptedAt ?? acceptedAt),
        );
      }
      await wakeDispatcher(serviceKey);
      return res.json(result, 202);
    }
    if (req.method === "POST" && url.pathname === "/v1/expense-drafts/parse") {
      const input = z
        .object({ text: z.string().min(1).max(4000) })
        .strict()
        .parse(JSON.parse(raw));
      return res.json(parseExpenseText(input.text));
    }
    throw new AppError(
      "NOT_FOUND",
      "This operation is not available in this build.",
      404,
    );
  } catch (error) {
    if (error instanceof z.ZodError)
      return res.json(
        {
          error: {
            code: "INVALID_REQUEST",
            message: "Review the supplied fields.",
            issues: error.issues.map((i) => ({
              path: i.path,
              message: i.message,
            })),
          },
        },
        400,
      );
    if (error instanceof SyntaxError)
      return res.json(
        {
          error: {
            code: "INVALID_JSON",
            message: "Request body must be valid JSON.",
          },
        },
        400,
      );
    if (error instanceof AppError)
      return res.json(
        { error: { code: error.code, message: error.message } },
        error.status,
      );
    return failure(res, error);
  }
}
