import { createHash, randomUUID } from "node:crypto";
import {
  AppError,
  receiptAttach,
  type ReceiptAttach,
  type Transaction,
  type RecordValue,
} from "../contracts";
import type { UserStore, ReadStore } from "./store";
import { fingerprint } from "./finance";
import { schedule, type Job } from "./jobs";

export interface Receipt {
  transactionId: string;
  sha256: string;
  bytes: number;
  fileId: string;
  bucketId: string;
  status: "awaiting_upload" | "uploading" | "ready" | "removing";
  leaseUntil: string | null;
  leaseToken: string | null;
}
export interface ReceiptFiles {
  fileId(id: string): string;
  bucketId: string;
  put(
    id: string,
    bytes: Buffer,
    sha256: string,
    deadline: number,
  ): Promise<void>;
  exists(id: string, sha256: string): Promise<boolean>;
  remove(id: string): Promise<void>;
}
export function privateFileWorkPending(
  receipts: RecordValue<Receipt>[],
  jobs: RecordValue<Job>[],
  now = Date.now(),
) {
  return (
    receipts.some((r) => {
      const lease = Date.parse(r.data.leaseUntil ?? "");
      return (
        (r.data.status === "uploading" && !Number.isFinite(lease)) ||
        (r.data.leaseUntil !== null &&
          (!Number.isFinite(lease) || lease + 30000 > now))
      );
    }) ||
    jobs.some((r) => {
      if (r.data.type !== "privacy.export") return false;
      if (r.data.status === "running") {
        const lease = Date.parse(r.data.leaseUntil ?? "");
        return !Number.isFinite(lease) || lease + 120000 > now;
      }
      if (["retry", "failed", "needs_attention"].includes(r.data.status)) {
        const updated = Date.parse(r.updatedAt);
        return !Number.isFinite(updated) || updated + 90000 > now;
      }
      return false;
    })
  );
}
export function receiptBytes(input: ReceiptAttach) {
  receiptAttach.parse(input);
  const bytes = Buffer.from(input.jpegBase64, "base64");
  if (
    bytes.length > 650000 ||
    bytes.length < 8 ||
    bytes.toString("base64") !== input.jpegBase64 ||
    bytes[0] !== 0xff ||
    bytes[1] !== 0xd8 ||
    bytes[2] !== 0xff ||
    bytes.at(-2) !== 0xff ||
    bytes.at(-1) !== 0xd9 ||
    createHash("sha256").update(bytes).digest("hex") !== input.sha256
  )
    throw new AppError(
      "INVALID_RECEIPT",
      "Choose a compressed JPEG receipt under 650 KB and review it before saving.",
    );
  return bytes;
}
const unavailable = () =>
  new AppError(
    "ATTACHMENT_TARGET_GONE",
    "This transaction is no longer available. Your local receipt has been preserved for review.",
    409,
  );
async function assertTarget(store: ReadStore, id: string) {
  const deletion = await store.get<{ type: string }>("privacy_jobs", "current");
  if (deletion && !deletion.deleted && deletion.data.type === "delete")
    throw new AppError(
      "ACCOUNT_DELETING",
      "New work is stopped for this account.",
      410,
    );
  const target = await store.get<Transaction>("transactions", id);
  if (!target || target.deleted) throw unavailable();
}

/** The durable reservation precedes file IO. Its lease also prevents erasure
 * from completing while a known upload could still be in flight. */
export async function retainReceipt(
  store: UserStore,
  files: ReceiptFiles,
  input: ReceiptAttach,
  mutationId: string,
  now = new Date(),
) {
  const bytes = receiptBytes(input),
    hash = fingerprint(input);
  await store.mutate(mutationId, hash, async (tx) => {
    await assertTarget(tx, input.transactionId);
    const previous = await tx.get<Receipt>("receipts", input.id);
    if (previous) {
      if (previous.deleted || previous.data.status === "removing")
        throw new AppError(
          "RECEIPT_REMOVED",
          "This receipt was removed. Choose a new receipt to retain.",
          409,
        );
      if (
        previous.data.sha256 !== input.sha256 ||
        previous.data.transactionId !== input.transactionId
      )
        throw new AppError(
          "RECEIPT_CHANGED",
          "This receipt identifier already belongs to different content.",
          409,
        );
      return { id: previous.id };
    }
    const receipts = await tx.list<Receipt>("receipts");
    if (
      receipts.length >= 100 ||
      receipts.reduce((n, r) => n + r.data.bytes, 0) + bytes.length > 50_000_000
    )
      throw new AppError(
        "RECEIPT_LIMIT",
        "Remove an older retained receipt before adding another.",
        409,
      );
    await tx.put<Receipt>(
      "receipts",
      input.id,
      {
        transactionId: input.transactionId,
        sha256: input.sha256,
        bytes: bytes.length,
        fileId: files.fileId(input.id),
        bucketId: files.bucketId,
        status: "awaiting_upload",
        leaseUntil: null,
        leaseToken: null,
      },
      0,
    );
    return { id: input.id };
  });
  const token = randomUUID();
  const reserved = await store.mutate(
    `receipt-claim:${token}`,
    fingerprint([input.id, token]),
    async (tx) => {
      await assertTarget(tx, input.transactionId);
      const row = await tx.get<Receipt>("receipts", input.id);
      if (!row || row.deleted) throw unavailable();
      if (row.data.status === "ready") return row;
      if (row.data.status === "removing")
        throw new AppError(
          "RECEIPT_REMOVED",
          "This receipt is being removed.",
          409,
        );
      if (
        row.data.status === "uploading" &&
        !Number.isFinite(Date.parse(row.data.leaseUntil ?? ""))
      )
        throw new AppError(
          "RECEIPT_STATE",
          "The saved upload needs recovery before retry.",
          503,
        );
      if (
        row.data.leaseUntil &&
        Date.parse(row.data.leaseUntil) > now.getTime()
      )
        throw new AppError(
          "RECEIPT_BUSY",
          "Your receipt is saved locally. Upload recovery will retry shortly.",
          503,
        );
      const leaseUntil = new Date(now.getTime() + 90_000).toISOString();
      const next = await tx.put(
        "receipts",
        row.id,
        { ...row.data, status: "uploading", leaseToken: token, leaseUntil },
        row.version,
      );
      await schedule(
        tx,
        "receipt.reconcile",
        `${row.id}:${token}`,
        { receiptId: row.id },
        new Date(now.getTime() + 125_000),
      );
      return next;
    },
  );
  if (reserved.data.status === "ready")
    return { id: reserved.id, status: "ready" };
  if (Date.parse(reserved.data.leaseUntil ?? "") <= Date.now())
    throw new AppError(
      "LEASE_LOST",
      "Receipt recovery will resume the private upload.",
      409,
    );
  // Every retry uses the same private file identity and verified content hash.
  await files.put(
    input.id,
    bytes,
    input.sha256,
    Date.parse(reserved.data.leaseUntil!),
  );
  return store.mutate(
    `receipt-ready:${token}`,
    fingerprint([input.id, token]),
    async (tx) => {
      await assertTarget(tx, input.transactionId);
      const row = await tx.get<Receipt>("receipts", input.id);
      if (!row || row.deleted) throw unavailable();
      if (
        row.data.status === "removing" ||
        row.data.leaseToken !== token ||
        Date.parse(row.data.leaseUntil ?? "") <= Date.now()
      )
        throw new AppError(
          "LEASE_LOST",
          "Receipt recovery will reconcile the private upload.",
          409,
        );
      await tx.put(
        "receipts",
        row.id,
        { ...row.data, status: "ready", leaseToken: null, leaseUntil: null },
        row.version,
      );
      const recoveryId = fingerprint([
          "receipt.reconcile",
          `${row.id}:${token}`,
        ]).slice(0, 36),
        recovery = await tx.get<Job>("jobs", recoveryId);
      if (recovery && !recovery.deleted && recovery.data.status === "queued")
        await tx.put(
          "jobs",
          recovery.id,
          {
            ...recovery.data,
            status: "succeeded",
            result: { status: "ready" },
          },
          recovery.version,
        );
      return { id: row.id, status: "ready" };
    },
  );
}

/** A recovery job closes unknown upload outcomes, or removes a deleted target's
 * file after its upload lease has safely elapsed. No image bytes enter the log. */
export async function reconcileReceipt(
  store: UserStore,
  files: ReceiptFiles,
  id: string,
  now = new Date(),
) {
  const row = await store.get<Receipt>("receipts", id);
  if (!row || row.deleted) return { status: "removed" };
  if (
    (row.data.status === "uploading" || row.data.leaseUntil !== null) &&
    !Number.isFinite(Date.parse(row.data.leaseUntil ?? ""))
  )
    throw new AppError(
      "RECEIPT_STATE",
      "The saved upload timing needs recovery.",
      503,
    );
  if (
    row.data.leaseUntil &&
    Date.parse(row.data.leaseUntil) + 30000 > now.getTime()
  )
    throw new AppError(
      "RECEIPT_BUSY",
      "The private upload is still being reconciled.",
      503,
    );
  const target = await store.get<Transaction>(
    "transactions",
    row.data.transactionId,
  );
  if (!target || target.deleted || row.data.status === "removing") {
    await files.remove(id);
    await store.mutate(
      `receipt-remove:${id}:${row.version}`,
      fingerprint([id, row.version]),
      async (tx) => {
        const current = await tx.get<Receipt>("receipts", id);
        if (current && !current.deleted)
          await tx.remove("receipts", id, current.version);
        return { status: "removed" };
      },
    );
    return { status: "removed" };
  }
  const ready = await files.exists(id, row.data.sha256);
  await store.mutate(
    `receipt-reconcile:${id}:${row.version}`,
    fingerprint([id, row.version, ready]),
    async (tx) => {
      const current = await tx.get<Receipt>("receipts", id);
      if (!current || current.deleted || current.version !== row.version)
        return null;
      return tx.put(
        "receipts",
        id,
        {
          ...current.data,
          status: ready ? "ready" : "awaiting_upload",
          leaseToken: null,
          leaseUntil: null,
        },
        current.version,
      );
    },
  );
  return { status: ready ? "ready" : "awaiting_upload" };
}
