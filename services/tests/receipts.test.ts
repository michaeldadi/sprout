import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createHash, randomUUID } from "node:crypto";
import { envelope, transaction, type ReceiptAttach } from "../contracts";
import { MemoryStore } from "../domain/store";
import {
  retainReceipt,
  reconcileReceipt,
  receiptBytes,
  privateFileWorkPending,
  type Receipt,
  type ReceiptFiles,
} from "../domain/receipts";
import { execute } from "../domain/application";

const flags = {
  linking: false,
  ai: false,
  forecasts: false,
  notifications: false,
  cancellation: false,
  scanAssistance: false,
};
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9]);
function input(): ReceiptAttach {
  return {
    type: "receipt.attach",
    id: randomUUID(),
    transactionId: "expense",
    sha256: createHash("sha256").update(jpeg).digest("hex"),
    jpegBase64: jpeg.toString("base64"),
  };
}
function adapter() {
  const files = new Map<string, Buffer>();
  const put = vi.fn(async (id: string, bytes: Buffer) => {
    files.set(id, bytes);
  });
  const api: ReceiptFiles = {
    bucketId: "private",
    fileId: (id) => `file-${id}`,
    put,
    exists: async (id, sha) =>
      files.has(id) &&
      createHash("sha256").update(files.get(id)!).digest("hex") === sha,
    remove: vi.fn(async (id) => {
      files.delete(id);
    }),
  };
  return { files, api, put };
}
async function setup() {
  const store = new MemoryStore();
  await store.mutate("seed", "seed", (tx) =>
    tx.put(
      "transactions",
      "expense",
      transaction.parse({
        id: "expense",
        amount: { minor: -540, currency: "USD" },
        date: "2026-11-10",
        merchant: "Cafe",
        category: "Food",
        type: "expense",
        source: "manual",
      }),
      0,
    ),
  );
  return { store, ...adapter(), value: input() };
}
describe("reviewed private receipt retention", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-11-10T12:00:00Z"));
  });
  afterEach(() => vi.useRealTimers());
  it("retains one immutable file across lost-response retries without putting image bytes or leases in the journal", async () => {
    const { store, api, put, value } = await setup();
    expect(await retainReceipt(store, api, value, "save")).toEqual({
      id: value.id,
      status: "ready",
    });
    expect(await retainReceipt(store, api, value, "save")).toEqual({
      id: value.id,
      status: "ready",
    });
    await retainReceipt(store, api, value, "same-file-other-request");
    expect(put).toHaveBeenCalledTimes(1);
    expect(await store.list("receipts")).toHaveLength(1);
    const log = JSON.stringify(await store.changes(0));
    expect(log).not.toContain(value.jpegBase64);
    expect(
      JSON.stringify(
        (await store.changes(0))
          .flatMap((e) => e.changes)
          .filter((c) => c.kind === "receipts"),
      ),
    ).not.toContain("leaseToken");
    const changed = {
      ...value,
      jpegBase64: Buffer.from([...jpeg.slice(0, -2), 9, 0xff, 0xd9]).toString(
        "base64",
      ),
    };
    changed.sha256 = createHash("sha256")
      .update(Buffer.from(changed.jpegBase64, "base64"))
      .digest("hex");
    await expect(
      retainReceipt(store, api, changed, "changed"),
    ).rejects.toMatchObject({ code: "RECEIPT_CHANGED" });
  });
  it("recovers an unknown upload response before retrying the same private file", async () => {
    const { store, api, put, files, value } = await setup();
    put.mockImplementationOnce(async (id, bytes) => {
      files.set(id, bytes);
      throw new Error("lost response");
    });
    await expect(retainReceipt(store, api, value, "save")).rejects.toThrow(
      "lost response",
    );
    await expect(
      retainReceipt(store, api, value, "save"),
    ).rejects.toMatchObject({ code: "RECEIPT_BUSY" });
    vi.advanceTimersByTime(125000);
    expect(await reconcileReceipt(store, api, value.id)).toEqual({
      status: "ready",
    });
    expect(await retainReceipt(store, api, value, "save")).toEqual({
      id: value.id,
      status: "ready",
    });
    expect(put).toHaveBeenCalledTimes(1);
  });
  it("waits out in-flight IO and removes a receipt when its transaction is deleted", async () => {
    const { store, api, put, files, value } = await setup();
    put.mockImplementationOnce(async (id, bytes) => {
      files.set(id, bytes);
      await execute(
        store,
        envelope.parse({
          mutationId: "delete",
          command: {
            type: "transaction.delete",
            id: "expense",
            expectedVersion: 1,
          },
        }),
        flags,
      );
    });
    await expect(
      retainReceipt(store, api, value, "save"),
    ).rejects.toMatchObject({ code: "ATTACHMENT_TARGET_GONE" });
    await expect(reconcileReceipt(store, api, value.id)).rejects.toMatchObject({
      code: "RECEIPT_BUSY",
    });
    expect(files.has(value.id)).toBe(true);
    vi.advanceTimersByTime(125000);
    expect(await reconcileReceipt(store, api, value.id)).toEqual({
      status: "removed",
    });
    expect(files.has(value.id)).toBe(false);
    expect((await store.get("transactions", "expense"))?.deleted).toBe(true);
    expect((await store.get("receipts", value.id))?.deleted).toBe(true);
  });
  it("preserves the upload lease and refuses confirmation after account deletion begins", async () => {
    const { store, api, put, value } = await setup();
    put.mockImplementationOnce(async () => {
      await store.mutate("delete-account", "delete-account", (tx) =>
        tx.put("privacy_jobs", "current", { type: "delete" }, 0),
      );
    });
    await expect(
      retainReceipt(store, api, value, "save"),
    ).rejects.toMatchObject({ code: "ACCOUNT_DELETING" });
    expect(
      (await store.get<Receipt>("receipts", value.id))?.data,
    ).toMatchObject({ status: "uploading" });
    expect(
      Date.parse(
        (await store.get<Receipt>("receipts", value.id))!.data.leaseUntil!,
      ),
    ).toBeGreaterThan(Date.now());
    expect(
      privateFileWorkPending(await store.list<Receipt>("receipts"), []),
    ).toBe(true);
    vi.advanceTimersByTime(125000);
    expect(
      privateFileWorkPending(await store.list<Receipt>("receipts"), []),
    ).toBe(false);
  });
  it("never mistakes corrupt file-work timing or a recently failed export for completed IO", async () => {
    const receipt = {
      id: "r",
      version: 1,
      deleted: false,
      updatedAt: new Date().toISOString(),
      data: { status: "uploading", leaseUntil: "invalid" },
    } as any;
    expect(privateFileWorkPending([receipt], [])).toBe(true);
    const job = {
      id: "j",
      version: 1,
      deleted: false,
      updatedAt: new Date().toISOString(),
      data: { type: "privacy.export", status: "retry", leaseUntil: null },
    } as any;
    expect(privateFileWorkPending([], [job])).toBe(true);
    vi.advanceTimersByTime(125000);
    expect(privateFileWorkPending([], [job])).toBe(false);
    job.data.status = "running";
    job.data.leaseUntil = new Date(Date.now() + 240000).toISOString();
    expect(privateFileWorkPending([], [job])).toBe(true);
    vi.advanceTimersByTime(361000);
    expect(privateFileWorkPending([], [job])).toBe(false);
  });
  it("validates the exact reviewed bytes and refuses missing or cross-account targets before file IO", async () => {
    const { api, put, value } = await setup();
    expect(() => receiptBytes({ ...value, sha256: "a".repeat(64) })).toThrow();
    expect(() =>
      receiptBytes({
        ...value,
        jpegBase64: Buffer.from("not a receipt").toString("base64"),
      }),
    ).toThrow();
    await expect(
      retainReceipt(new MemoryStore(), api, value, "foreign"),
    ).rejects.toMatchObject({ code: "ATTACHMENT_TARGET_GONE" });
    expect(put).not.toHaveBeenCalled();
  });
  it("keeps a removal durable and repeat-safe without restoring its private file", async () => {
    const { store, api, files, value } = await setup();
    await retainReceipt(store, api, value, "save");
    const row = (await store.get<Receipt>("receipts", value.id))!;
    await execute(
      store,
      envelope.parse({
        mutationId: "remove",
        command: {
          type: "receipt.remove",
          id: value.id,
          expectedVersion: row.version,
        },
      }),
      flags,
    );
    expect((await store.get<Receipt>("receipts", value.id))?.data.status).toBe(
      "removing",
    );
    await reconcileReceipt(store, api, value.id);
    await reconcileReceipt(store, api, value.id);
    expect(files.size).toBe(0);
    await expect(
      retainReceipt(store, api, value, "new-request"),
    ).rejects.toMatchObject({ code: "RECEIPT_REMOVED" });
  });
  it("makes a cancellation arriving before an upload a tombstone, so the later request cannot resurrect it", async () => {
    const { store, api, put, value } = await setup();
    const cancel = envelope.parse({
      mutationId: "cancel-before-upload",
      command: { type: "receipt.cancel", id: value.id },
    });
    await execute(store, cancel, flags);
    await execute(store, cancel, flags);
    await expect(
      retainReceipt(store, api, value, "late-upload"),
    ).rejects.toMatchObject({ code: "RECEIPT_REMOVED" });
    expect(put).not.toHaveBeenCalled();
    expect((await store.get("receipts", value.id))?.deleted).toBe(true);
  });
});
