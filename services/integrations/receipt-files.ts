import { createHash } from "node:crypto";
import { AppError } from "../contracts";
import type { ReceiptFiles } from "../domain/receipts";
import { fingerprint } from "../domain/finance";
import { PrivacyLedger } from "./privacy-ledger";

/** Bounded private file IO. The bucket has no client creation or broad read grant. */
export function receiptFiles(owner: string, key: string): ReceiptFiles {
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT,
    project = process.env.APPWRITE_FUNCTION_PROJECT_ID,
    bucketId = process.env.SPROUT_PRIVATE_BUCKET_ID;
  if (!endpoint || !project || !bucketId)
    throw new AppError(
      "NOT_CONFIGURED",
      "Private receipt retention is unavailable.",
      503,
    );
  const fileId = (id: string) =>
    fingerprint(["receipt", owner, id]).slice(0, 36);
  const headers = { "x-appwrite-project": project, "x-appwrite-key": key };
  const url = (id: string, suffix = "") =>
    `${endpoint}/storage/buckets/${encodeURIComponent(bucketId)}/files/${fileId(id)}${suffix}`;
  async function exists(id: string, sha256: string) {
    const response = await fetch(url(id), {
      headers,
      signal: AbortSignal.timeout(5000),
    });
    if (response.status === 404) return false;
    if (!response.ok)
      throw new AppError(
        "RECEIPT_RETRY",
        "The private upload could not be verified.",
        503,
      );
    const file = (await response.json()) as {
      $permissions: string[];
      sizeOriginal: number;
      name: string;
    };
    if (
      file.$permissions.length !== 1 ||
      file.$permissions[0] !== `read("user:${owner}")` ||
      file.sizeOriginal > 650000
    )
      throw new AppError(
        "RECEIPT_SCOPE",
        "Private receipt ownership could not be verified.",
        409,
      );
    const data = await fetch(url(id, "/download"), {
      headers,
      signal: AbortSignal.timeout(5000),
    });
    if (!data.ok)
      throw new AppError(
        "RECEIPT_RETRY",
        "The private upload could not be verified.",
        503,
      );
    const bytes = Buffer.from(await data.arrayBuffer());
    if (
      bytes.length > 650000 ||
      createHash("sha256").update(bytes).digest("hex") !== sha256
    )
      throw new AppError(
        "RECEIPT_CHANGED",
        "The retained receipt does not match the reviewed image.",
        409,
      );
    return true;
  }
  return {
    bucketId,
    fileId,
    exists,
    async put(id, bytes, sha256, deadline) {
      if (
        process.env.SPROUT_PRIVACY_DATABASE_ID &&
        (await new PrivacyLedger(key).get(owner))
      )
        throw new AppError(
          "ACCOUNT_DELETING",
          "New work is stopped for this account.",
          410,
        );
      if (Date.now() >= deadline)
        throw new AppError(
          "LEASE_LOST",
          "The saved private upload will be recovered before retry.",
          409,
        );
      const form = new FormData();
      form.set("fileId", fileId(id));
      form.set(
        "file",
        new Blob([new Uint8Array(bytes)], { type: "image/jpeg" }),
        "sprout-receipt.jpg",
      );
      form.append("permissions[]", `read("user:${owner}")`);
      const response = await fetch(
        `${endpoint}/storage/buckets/${encodeURIComponent(bucketId)}/files`,
        {
          method: "POST",
          headers,
          body: form,
          signal: AbortSignal.timeout(10000),
        },
      );
      if (response.status === 409) {
        if (await exists(id, sha256)) return;
      }
      if (!response.ok)
        throw new AppError(
          "RECEIPT_RETRY",
          "Your compressed receipt remains saved on this device. Upload will retry.",
          503,
        );
      const file = (await response.json()) as {
        $id: string;
        $permissions: string[];
        sizeOriginal: number;
      };
      if (
        file.$id !== fileId(id) ||
        file.sizeOriginal !== bytes.length ||
        file.$permissions.length !== 1 ||
        file.$permissions[0] !== `read("user:${owner}")`
      )
        throw new AppError(
          "RECEIPT_SCOPE",
          "The private file acknowledgment could not be verified.",
          409,
        );
    },
    async remove(id) {
      const response = await fetch(url(id), {
        method: "DELETE",
        headers,
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok && response.status !== 404)
        throw new AppError(
          "RECEIPT_RETRY",
          "Private receipt removal will retry.",
          503,
        );
    },
  };
}
