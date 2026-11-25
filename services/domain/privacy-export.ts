import { createHash } from "node:crypto";
import { z } from "zod";
import { AppError, kinds, journalRecord, type Kind } from "../contracts";
import type { ReadStore } from "./store";

/** Export user records using the same redaction boundary as owner sync.
 * Operational nonces and temporary CSV source parts are not user artifacts. */
export async function exportFinancialRecords(store: ReadStore) {
  const records: Partial<Record<Kind, unknown[]>> = {};
  for (const kind of kinds.filter(
    (k) => !["jobs", "usage", "notifications"].includes(k),
  ))
    records[kind] = (await store.list(kind)).map((row) =>
      journalRecord(kind, row),
    );
  // Weekly reviews are user-facing artifacts; exclude transport identifiers
  // and delivery machinery while retaining the reviewed financial snapshot.
  records.notifications = (
    await store.list<{ topic: string; review?: unknown }>("notifications")
  )
    .filter((row) => row.data.topic === "weekly" && row.data.review)
    .map((row) => ({
      ...row,
      data: { topic: "weekly", review: row.data.review },
    }));
  return records;
}

/** A retried job can recover its original immutable snapshot, never describe
 * the newly computed snapshot as the bytes saved by an earlier attempt. */
export function verifiedExportArtifact(
  bytes: Uint8Array,
  permissions: string[],
  ownerPermission: string,
  createdAt: string,
) {
  const invalid = () =>
    new AppError(
      "EXPORT_RECOVERY",
      "This export needs an ownership or integrity review.",
      409,
    );
  if (
    bytes.byteLength > 9_000_000 ||
    permissions.length !== 1 ||
    permissions[0] !== ownerPermission
  )
    throw invalid();
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(bytes).toString("utf8"));
  } catch {
    throw invalid();
  }
  const result = z
    .object({
      schemaVersion: z.literal(1),
      exportedAt: z.iso.datetime(),
      revision: z.number().int().nonnegative().safe(),
      records: z.record(z.string(), z.array(z.unknown())),
    })
    .strict()
    .safeParse(parsed);
  if (
    !result.success ||
    !Number.isFinite(Date.parse(createdAt)) ||
    Date.parse(result.data.exportedAt) > Date.parse(createdAt) + 60_000
  )
    throw invalid();
  return {
    snapshotRevision: result.data.revision,
    exportedAt: result.data.exportedAt,
    sha256: createHash("sha256").update(bytes).digest("hex"),
    size: bytes.byteLength,
  };
}
