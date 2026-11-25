import { PrivacyLedger } from "../integrations/privacy-ledger";
import { eraseFirstParty } from "../integrations/privacy-erasure";
import { randomUUID } from "node:crypto";
import { Client, Storage, Permission, Role } from "node-appwrite";
import { InputFile } from "node-appwrite/file";
import { z } from "zod";
import { id, AppError, receiptAttach } from "../contracts";
import {
  exportFinancialRecords,
  verifiedExportArtifact,
} from "../domain/privacy-export";
import {
  retainReceipt,
  reconcileReceipt,
  type Receipt,
} from "../domain/receipts";
import { receiptFiles } from "../integrations/receipt-files";
import { AppwriteStore, rowId } from "../integrations/appwrite-store";
import { claim, finish } from "../domain/jobs";
import { fingerprint } from "../domain/finance";
import { failure, rawBody, serviceKey, type FunctionContext } from "./context";

export default async function main(context: FunctionContext) {
  try {
    const input = z
      .object({
        owner: id,
        jobId: id.optional(),
        recovery: z.literal(true).optional(),
        receipt: receiptAttach.optional(),
        mutationId: id.optional(),
      })
      .refine(
        (v) =>
          [!!v.jobId, !!v.recovery, !!v.receipt].filter(Boolean).length === 1 &&
          (v.receipt ? !!v.mutationId : !v.mutationId),
      )
      .strict()
      .parse(JSON.parse(rawBody(context, 1_000_000)));
    const key = serviceKey(context);
    if (input.receipt) {
      if (process.env.SPROUT_FINANCIAL_WRITES !== "true")
        throw new AppError(
          "CONSISTENCY_GATE",
          "Financial sync has not been enabled for this environment.",
          503,
        );
      const financial = new AppwriteStore(input.owner, key);
      await financial.assertWritable();
      return context.res.json(
        await retainReceipt(
          financial,
          receiptFiles(input.owner, key),
          input.receipt,
          input.mutationId!,
        ),
      );
    }
    const store = new AppwriteStore(input.owner, key, true);
    if (input.recovery) {
      if (process.env.SPROUT_FIRST_PARTY_ERASURE !== "true")
        throw new AppError(
          "DELETION_PROOF_REQUIRED",
          "Deletion validation has not been completed.",
          503,
        );
      if (!(await new PrivacyLedger(key).get(input.owner)))
        throw new AppError("NOT_FOUND", "Privacy request not found.", 404);
      const progress = await eraseFirstParty(store, key);
      return context.res.json({ status: progress.status });
    }
    const token = randomUUID();
    const job = await claim(store, input.jobId!, token);
    if (!job)
      return context.res.json({ status: "already_claimed_or_finished" });
    try {
      if (job.data.type.startsWith("receipt.")) {
        const financial = new AppwriteStore(input.owner, key);
        await financial.assertWritable();
        const files = receiptFiles(input.owner, key);
        let result: unknown;
        if (job.data.type === "receipt.reconcile")
          result = await reconcileReceipt(
            financial,
            files,
            z.string().uuid().parse(job.data.payload.receiptId),
          );
        else if (job.data.type === "receipt.cleanup") {
          const transactionId = id.parse(job.data.payload.transactionId);
          for (const receipt of (
            await financial.list<Receipt>("receipts")
          ).filter((r) => r.data.transactionId === transactionId))
            await reconcileReceipt(financial, files, receipt.id);
          result = { status: "removed" };
        } else
          throw new AppError("INVALID_JOB", "Private file job is unavailable.");
        await finish(store, job.id, token, result);
        return context.res.json({ status: "succeeded" });
      }
      if (job.data.type === "privacy.export") {
        const writable = new AppwriteStore(input.owner, key);
        await writable.assertWritable();
        const revision = await store.revision();
        const records = await exportFinancialRecords(store);
        if (revision !== (await store.revision()))
          throw new AppError(
            "EXPORT_CHANGED",
            "Records changed during export. The export will retry.",
            409,
          );
        const data = JSON.stringify({
          schemaVersion: 1,
          exportedAt: new Date().toISOString(),
          revision,
          records,
        });
        if (Buffer.byteLength(data) > 9_000_000)
          throw new AppError(
            "EXPORT_TOO_LARGE",
            "This account requires a larger export job.",
            413,
          );
        const storage = new Storage(
          new Client()
            .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
            .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
            .setKey(key),
        );
        const bucket = process.env.SPROUT_PRIVATE_BUCKET_ID;
        if (!bucket)
          throw new AppError(
            "NOT_CONFIGURED",
            "Private exports are not configured.",
            503,
          );
        const fileId = rowId(input.owner, "export", job.id);
        if (Date.parse(job.data.leaseUntil ?? "") - Date.now() < 20000)
          throw new AppError(
            "LEASE_LOST",
            "Export recovery will retry before creating a private file.",
            409,
          );
        await writable.assertWritable();
        try {
          await storage.createFile({
            bucketId: bucket,
            fileId,
            file: InputFile.fromPlainText(data, "sprout-export.json"),
            permissions: [Permission.read(Role.user(input.owner))],
          });
        } catch (error) {
          if (
            !(
              typeof error === "object" &&
              error !== null &&
              "code" in error &&
              error.code === 409
            )
          )
            throw error;
        }
        const exportedFile = await storage.getFile({
          bucketId: bucket,
          fileId,
        });
        try {
          await writable.assertWritable();
        } catch (error) {
          try {
            await storage.deleteFile({ bucketId: bucket, fileId });
          } catch {
            /* The registered export lease keeps erasure in recovery until its file sweep is safe. */
          }
          throw error;
        }
        // node-appwrite decodes JSON before applying its arrayBuffer option.
        // Read actual bytes so recovery hashes the saved file, not reserialized JSON.
        if (
          exportedFile.sizeOriginal > 9_000_000 ||
          exportedFile.$permissions.length !== 1 ||
          exportedFile.$permissions[0] !==
            Permission.read(Role.user(input.owner))
        )
          throw new AppError(
            "EXPORT_RECOVERY",
            "This export needs an ownership or integrity review.",
            409,
          );
        const downloaded = await fetch(
          `${process.env.APPWRITE_FUNCTION_API_ENDPOINT}/storage/buckets/${encodeURIComponent(bucket)}/files/${encodeURIComponent(fileId)}/download`,
          {
            headers: {
              "x-appwrite-project": process.env.APPWRITE_FUNCTION_PROJECT_ID!,
              "x-appwrite-key": key,
            },
            signal: AbortSignal.timeout(15000),
          },
        );
        if (!downloaded.ok)
          throw new AppError(
            "EXPORT_RECOVERY",
            "The private export could not be verified. It will retry.",
            503,
          );
        const downloadedBytes = new Uint8Array(await downloaded.arrayBuffer());
        if (downloadedBytes.byteLength !== exportedFile.sizeOriginal)
          throw new AppError(
            "EXPORT_RECOVERY",
            "This export needs an integrity review.",
            409,
          );
        const artifact = verifiedExportArtifact(
          downloadedBytes,
          exportedFile.$permissions,
          Permission.read(Role.user(input.owner)),
          exportedFile.$createdAt,
        );
        await finish(store, job.id, token, {
          fileId,
          bucketId: bucket,
          status: "ready",
          generatedAt: exportedFile.$createdAt,
          ...artifact,
        });
      } else if (job.data.type === "privacy.delete") {
        if (process.env.SPROUT_FIRST_PARTY_ERASURE !== "true")
          throw new AppError(
            "DELETION_PROOF_REQUIRED",
            "Deletion validation has not been completed.",
            503,
          );
        const receiptHash = z
          .string()
          .length(64)
          .parse(job.data.payload.receiptHash);
        const progress = await eraseFirstParty(
          store,
          key,
          receiptHash,
          job.data.payload.acceptedAt as string,
        );
        // The deletion worker removes its financial job row last. Final state
        // lives in the independent privacy ledger, never recreated in backups.
        if (progress.status === "needs_attention")
          await store.mutate(
            `privacy:attention:${token}`,
            fingerprint(job.id),
            async (tx) => {
              const current = await tx.get<import("../domain/jobs").Job>(
                "jobs",
                job.id,
              );
              if (current && current.data.leaseToken === token)
                await tx.put(
                  "jobs",
                  job.id,
                  {
                    ...current.data,
                    status: "needs_attention",
                    leaseUntil: null,
                    leaseToken: null,
                    error: "EXTERNAL_CLEANUP_REQUIRED",
                  },
                  current.version,
                );
              return null;
            },
          );
        return context.res.json({ status: progress.status });
      } else
        throw new AppError(
          "INVALID_JOB",
          "This worker only processes privacy requests.",
        );
      return context.res.json({
        status: "succeeded",
      });
    } catch (error) {
      await finish(
        store,
        job.id,
        token,
        null,
        error instanceof AppError ? error.code : "PRIVACY_RETRY",
      );
      return context.res.json({ status: "retry_or_attention" }, 202);
    }
  } catch (error) {
    return failure(context.res, error);
  }
}
