import { expect, it } from "vitest";
import { MemoryStore } from "../domain/store";
import {
  exportFinancialRecords,
  verifiedExportArtifact,
} from "../domain/privacy-export";

it("exports receipt references without IO leases and temporary import metadata without raw inputs", async () => {
  const store = new MemoryStore();
  await store.mutate("seed", "seed", async (tx) => {
    await tx.put(
      "receipts",
      "copy",
      {
        transactionId: "expense",
        fileId: "private-file",
        sha256: "a".repeat(64),
        status: "ready",
        leaseToken: "internal-receipt-nonce",
        leaseUntil: "2026-11-10T17:00:00Z",
      },
      0,
    );
    await tx.put(
      "import_inputs",
      "part",
      {
        batchId: "batch",
        part: 0,
        checksum: "b".repeat(64),
        rows: [{ merchant: "temporary source text" }],
      },
      0,
    );
    await tx.put(
      "transactions",
      "expense",
      {
        merchant: "Reviewed expense",
        amount: { minor: -540, currency: "USD" },
      },
      0,
    );
    await tx.put("jobs", "private-job", { leaseToken: "worker-nonce" }, 0);
    await tx.put(
      "notifications",
      "weekly",
      {
        topic: "weekly",
        status: "accepted",
        providerReference: "internal-delivery-reference",
        review: { week: "2026-11-16", netSpendingMinor: 540 },
      },
      0,
    );
    return true;
  });
  const records = await exportFinancialRecords(store),
    raw = JSON.stringify(records);
  expect(raw).not.toContain("internal-receipt-nonce");
  expect(raw).not.toContain("leaseUntil");
  expect(raw).not.toContain("temporary source text");
  expect(raw).not.toContain("worker-nonce");
  expect(raw).not.toContain("internal-delivery-reference");
  expect(records.notifications?.[0]).toMatchObject({
    data: { topic: "weekly", review: { netSpendingMinor: 540 } },
  });
  expect(records.receipts?.[0]).toMatchObject({
    data: { transactionId: "expense", fileId: "private-file", status: "ready" },
  });
  expect(records.import_inputs?.[0]).toMatchObject({
    data: { batchId: "batch", part: 0, count: 1 },
  });
  expect(records.transactions?.[0]).toMatchObject({
    data: {
      merchant: "Reviewed expense",
      amount: { minor: -540, currency: "USD" },
    },
  });
});

it("recovers the revision and checksum of the actual saved export", () => {
  const bytes = Buffer.from(
    JSON.stringify({
      schemaVersion: 1,
      exportedAt: "2026-11-10T10:00:00.000Z",
      revision: 12,
      records: { transactions: [] },
    }),
  );
  expect(
    verifiedExportArtifact(
      bytes,
      ["owner"],
      "owner",
      "2026-11-10T10:00:01.000Z",
    ),
  ).toMatchObject({
    snapshotRevision: 12,
    exportedAt: "2026-11-10T10:00:00.000Z",
    size: bytes.length,
    sha256: expect.stringMatching(/^[a-f0-9]{64}$/),
  });
  for (const permissions of [[], ["peer"], ["owner", "peer"], ["owner", "any"]])
    expect(() =>
      verifiedExportArtifact(
        bytes,
        permissions,
        "owner",
        "2026-11-10T10:00:01.000Z",
      ),
    ).toThrow();
  for (const invalid of [
    "not-json",
    JSON.stringify({
      schemaVersion: 1,
      exportedAt: "wrong",
      revision: 12,
      records: {},
    }),
    JSON.stringify({
      schemaVersion: 1,
      exportedAt: "2026-11-11T10:00:00.000Z",
      revision: 12,
      records: {},
    }),
  ])
    expect(() =>
      verifiedExportArtifact(
        Buffer.from(invalid),
        ["owner"],
        "owner",
        "2026-11-10T10:00:01.000Z",
      ),
    ).toThrow();
});
