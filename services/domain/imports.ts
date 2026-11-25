import { createHash } from "node:crypto";
import { z } from "zod";
import { requestReminderPlan } from "./reminders";
import {
  AppError,
  importRow,
  transactionImport,
  type TransactionImport,
  type Transaction,
} from "../contracts";
import type { UserStore, WriteStore } from "./store";
import { fingerprint } from "./finance";
import { schedule, type Job } from "./jobs";

export const importedTransactionId = (batchId: string, sourceIndex: number) =>
  "import-" +
  createHash("sha256").update(`${batchId}:${sourceIndex}`).digest("hex");
interface Part {
  id: string;
  start: number;
  count: number;
  checksum: string;
}
const manifest = z
  .array(
    z
      .object({
        id: z.string().regex(/^[a-f0-9]{36}$/),
        start: z.number().int().nonnegative(),
        count: z.number().int().min(1).max(100),
        checksum: z.string().regex(/^[a-f0-9]{64}$/),
      })
      .strict(),
  )
  .min(1)
  .max(25);
interface InputPart {
  batchId: string;
  part: number;
  checksum: string;
  rows: TransactionImport["rows"];
}
/** Keep each private input row and each financial commit within TablesDB limits. */
function inputParts(rows: TransactionImport["rows"]) {
  const parts: TransactionImport["rows"][] = [];
  let pending: TransactionImport["rows"] = [];
  for (const row of rows) {
    if (
      pending.length &&
      (pending.length >= 100 ||
        Buffer.byteLength(JSON.stringify([...pending, row])) > 60_000)
    ) {
      parts.push(pending);
      pending = [];
    }
    pending.push(row);
  }
  if (pending.length) parts.push(pending);
  if (parts.length > 25)
    throw new AppError(
      "PAYLOAD_TOO_LARGE",
      "Select fewer records for this import.",
      413,
    );
  return parts;
}

export function importProgress(job: Job) {
  if (job.type !== "transaction.import") return null;
  return {
    total: Number(job.payload.total ?? 0),
    processed: Number(job.payload.cursor ?? 0),
    imported: Number(job.payload.imported ?? 0),
    preserved: Number(job.payload.preserved ?? 0),
  };
}

/** The reviewed batch is immutable. A second request can recover its existing job. */
export async function queueImport(tx: WriteStore, input: TransactionImport) {
  const parsed = transactionImport.parse(input);
  const batch = {
    ...parsed,
    rows: [...parsed.rows].sort((a, b) => a.sourceIndex - b.sourceIndex),
  };
  for (const row of batch.rows)
    if (
      row.transaction.id !==
      importedTransactionId(batch.batchId, row.sourceIndex)
    )
      throw new AppError(
        "INVALID_REQUEST",
        "Review the source row identifiers before importing.",
      );
  const importHash = fingerprint(batch);
  const existing = await tx.get<Job>(
    "jobs",
    fingerprint(["transaction.import", batch.batchId]).slice(0, 36),
  );
  if (existing && !existing.deleted) {
    if (existing.data.payload.importHash !== importHash)
      throw new AppError(
        "IMPORT_CHANGED",
        "This file already has a different reviewed import. Check its progress and edit existing records in Activity.",
        409,
      );
    return {
      id: existing.id,
      status: existing.data.status,
      progress: importProgress(existing.data),
    };
  }
  const parts: Part[] = [];
  let start = 0;
  for (const [part, rows] of inputParts(batch.rows).entries()) {
    const id = fingerprint(["import-input", batch.batchId, part]).slice(0, 36),
      checksum = fingerprint(rows);
    await tx.put<InputPart>(
      "import_inputs",
      id,
      { batchId: batch.batchId, part, checksum, rows },
      0,
    );
    parts.push({ id, start, count: rows.length, checksum });
    start += rows.length;
  }
  const job = await schedule(tx, "transaction.import", batch.batchId, {
    batchId: batch.batchId,
    importHash,
    parts,
    total: batch.rows.length,
    cursor: 0,
    imported: 0,
    preserved: 0,
  });
  return {
    id: job.id,
    status: job.data.status,
    progress: importProgress(job.data),
  };
}

/** Commit financial facts, progress and the replay receipt together, in bounded chunks. */
export async function applyImportChunk(
  store: UserStore,
  jobId: string,
  token: string,
  now = new Date(),
) {
  const record = await store.get<Job>("jobs", jobId);
  if (!record || record.deleted || record.data.type !== "transaction.import")
    throw new AppError("NOT_FOUND", "Import not found.", 404);
  const assertLease = (job: Job | undefined) => {
    const until = Date.parse(job?.leaseUntil ?? "");
    if (
      !job ||
      job.status !== "running" ||
      job.leaseToken !== token ||
      !Number.isFinite(until) ||
      until <= now.getTime()
    )
      throw new AppError(
        "LEASE_LOST",
        "The import claim expired. Its saved progress can be resumed.",
        409,
      );
  };
  assertLease(record.data);
  const start = Number(record.data.payload.cursor ?? 0);
  return store.mutate(
    `import-chunk:${jobId}:${start}`,
    fingerprint([jobId, start]),
    async (tx) => {
      const current = await tx.get<Job>("jobs", jobId);
      if (!current || current.deleted)
        throw new AppError("NOT_FOUND", "Import not found.", 404);
      assertLease(current.data);
      const total = Number(current.data.payload.total),
        batchId = String(current.data.payload.batchId);
      const saved = manifest.safeParse(current.data.payload.parts);
      if (
        !Number.isSafeInteger(total) ||
        total < 1 ||
        total > 1000 ||
        !saved.success ||
        !Number.isSafeInteger(start) ||
        start < 0 ||
        start > total
      )
        throw new AppError(
          "IMPORT_STATE",
          "The saved import needs review.",
          409,
        );
      const parts = saved.data;
      let position = 0;
      for (const part of parts) {
        if (part.start !== position)
          throw new AppError(
            "IMPORT_STATE",
            "The saved import needs review.",
            409,
          );
        position += part.count;
      }
      if (position !== total)
        throw new AppError(
          "IMPORT_STATE",
          "The saved import needs review.",
          409,
        );
      if (Number(current.data.payload.cursor ?? 0) !== start)
        throw new AppError(
          "IMPORT_RETRY",
          "Import progress changed. Resume from the saved checkpoint.",
          409,
        );
      const privacy = await tx.get<{ type: string }>("privacy_jobs", "current");
      if (privacy && !privacy.deleted && privacy.data.type === "delete")
        throw new AppError(
          "ACCOUNT_DELETING",
          "New work is stopped for this account.",
          410,
        );
      let imported = Number(current.data.payload.imported ?? 0),
        preserved = Number(current.data.payload.preserved ?? 0);
      const rows: TransactionImport["rows"] = [];
      let bytes = 0;
      collect: for (const part of parts.filter(
        (p) => p.start + p.count > start,
      )) {
        const input = await tx.get<InputPart>("import_inputs", part.id);
        if (
          !input ||
          input.deleted ||
          input.data.batchId !== batchId ||
          input.data.checksum !== part.checksum ||
          fingerprint(input.data.rows) !== part.checksum ||
          input.data.rows.length !== part.count
        )
          throw new AppError(
            "IMPORT_INPUT_MISSING",
            "The saved import source needs review.",
            409,
          );
        for (const value of input.data.rows.slice(
          Math.max(0, start - part.start),
        )) {
          const row = importRow.parse(value),
            size = Buffer.byteLength(JSON.stringify(row));
          if (rows.length && (rows.length >= 20 || bytes + size > 40_000))
            break collect;
          rows.push(row);
          bytes += size;
        }
        if (
          rows.length >= 20 ||
          bytes >= 35_000 ||
          start + rows.length === total
        )
          break;
      }
      const end = start + rows.length;
      if (!rows.length && start < total)
        throw new AppError(
          "IMPORT_STATE",
          "The saved import checkpoint needs review.",
          409,
        );
      for (const row of rows) {
        if (
          row.transaction.id !== importedTransactionId(batchId, row.sourceIndex)
        )
          throw new AppError(
            "INVALID_REQUEST",
            "The saved import needs review.",
          );
        // Includes tombstones: repeating a file must never restore an intentional deletion.
        if (await tx.get<Transaction>("transactions", row.transaction.id)) {
          preserved++;
          continue;
        }
        await tx.put("transactions", row.transaction.id, row.transaction, 0);
        imported++;
      }
      if (end === total)
        for (const part of parts) {
          const input = await tx.get("import_inputs", part.id);
          if (input && !input.deleted)
            await tx.remove("import_inputs", part.id, input.version);
        }
      const next: Job = {
        ...current.data,
        leaseUntil: new Date(now.getTime() + 240_000).toISOString(),
        payload: { ...current.data.payload, cursor: end, imported, preserved },
      };
      await tx.put("jobs", jobId, next, current.version);
      if (end === total) await requestReminderPlan(tx, now);
      return { ...importProgress(next)!, complete: end === total };
    },
  );
}

export async function applyImport(
  store: UserStore,
  jobId: string,
  token: string,
) {
  const deadline = Date.now() + 180_000;
  while (Date.now() < deadline) {
    const progress = await applyImportChunk(store, jobId, token);
    if (progress.complete) return progress;
  }
  throw new AppError(
    "IMPORT_RETRY",
    "Import progress is saved and will resume shortly.",
    503,
  );
}

export async function resumeImport(tx: WriteStore, id: string) {
  const job = await tx.get<Job>("jobs", id);
  if (!job || job.deleted || job.data.type !== "transaction.import")
    throw new AppError("NOT_FOUND", "Import not found.", 404);
  if (job.data.status !== "needs_attention")
    return { id, status: job.data.status, progress: importProgress(job.data) };
  const next: Job = {
    ...job.data,
    status: "queued",
    attempts: 0,
    dueAt: new Date().toISOString(),
    leaseUntil: null,
    leaseToken: null,
    error: undefined,
  };
  await tx.put("jobs", id, next, job.version);
  return { id, status: next.status, progress: importProgress(next) };
}
