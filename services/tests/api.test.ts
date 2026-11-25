import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { randomUUID } from "node:crypto";
import { AppError } from "../contracts";
import { MemoryStore } from "../domain/store";
import { readSyncCursor, syncCursor } from "../domain/sync";
const { holder } = vi.hoisted(() => ({
  holder: { store: null as unknown as MemoryStore },
}));
const receiptActor = vi.hoisted(() => vi.fn());
vi.mock("../integrations/receipt-actor", () => ({
  invokeReceiptActor: receiptActor,
}));
vi.mock("../integrations/appwrite-store", () => ({
  authenticate: async () => ({
    id: "alice",
    name: "Alice",
    email: "alice@example.invalid",
  }),
  AppwriteStore: class {
    constructor() {
      return holder.store;
    }
  },
}));
vi.mock("../integrations/privacy-ledger", () => ({
  PrivacyLedger: class {
    async accept() {
      return null;
    }
  },
}));
import main from "../functions/api";

async function request(
  method: string,
  path: string,
  body: unknown,
  account = "alice",
  queryString?: string,
) {
  return main({
    req: {
      method,
      path,
      queryString,
      headers: {
        "x-appwrite-user-jwt": "fictional",
        "x-sprout-account": account,
      },
      bodyText: JSON.stringify(body),
    },
    res: { json: (body, status = 200) => ({ body, status }) },
  }) as Promise<{ body: any; status: number }>;
}
describe("account switching request boundary", () => {
  it("reads the sync cursor from the Appwrite runtime query string", async () => {
    for (let i = 0; i < 3; i++)
      await holder.store.mutate(`seed-${i}`, String(i), (tx) =>
        tx.put("profiles", String(i), {}),
      );
    const response = await request(
      "GET",
      "/v1/sync",
      {},
      "alice",
      `cursor=${syncCursor("alice", 2)}`,
    );
    expect(response.status).toBe(200);
    expect(response.body.events.map((event: any) => event.sequence)).toEqual([
      3,
    ]);
    expect(readSyncCursor("alice", response.body.nextCursor).after).toBe(3);
  });
  afterEach(() => {
    delete process.env.SPROUT_FINANCIAL_WRITES;
    delete process.env.SPROUT_AI;
    delete process.env.SPROUT_FIRST_PARTY_ERASURE;
    delete process.env.SPROUT_SYNC_CURSOR_KEY;
  });
  beforeEach(() => {
    receiptActor.mockReset();
    receiptActor.mockResolvedValue({ status: "ready" });
    holder.store = Object.assign(new MemoryStore(), {
      async assertWritable() {
        const pending = await holder.store.get<{ type: string }>(
          "privacy_jobs",
          "current",
        );
        if (pending?.data.type === "delete")
          throw new AppError("ACCOUNT_DELETING", "New work is stopped.", 410);
      },
    });
    process.env.SPROUT_FINANCIAL_WRITES = "true";
    process.env.SPROUT_SYNC_CURSOR_KEY = Buffer.alloc(32, 7).toString("base64");
  });
  it("forwards only the verified owner to the private file actor and rejects client owner injection", async () => {
    const command = {
      type: "receipt.attach",
      id: randomUUID(),
      transactionId: "expense",
      sha256: "a".repeat(64),
      jpegBase64: "/9j/4AECAwT/2Q==",
    };
    const result = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: "receipt",
      command,
    });
    expect(result.status).toBe(200);
    expect(receiptActor).toHaveBeenCalledOnce();
    expect(receiptActor.mock.calls[0].slice(0, 3)).toEqual([
      "alice",
      command,
      "receipt",
    ]);
    receiptActor.mockClear();
    expect(
      (
        await request("POST", "/v1/commands", {
          _account: "bob",
          mutationId: "wrong",
          command,
        })
      ).status,
    ).toBe(409);
    expect(
      (
        await request("POST", "/v1/commands", {
          _account: "alice",
          mutationId: "injected",
          command: { ...command, owner: "bob" },
        })
      ).status,
    ).toBe(400);
    expect(receiptActor).not.toHaveBeenCalled();
  });
  it("deduplicates an AI request before charging its allowance and enforces the free preview limit", async () => {
    process.env.SPROUT_AI = "true";
    const input = {
      _account: "alice",
      question: "Explain my budget",
      context: null,
      requestId: randomUUID(),
    };
    expect((await request("POST", "/v1/assistant", input)).status).toBe(202);
    expect((await request("POST", "/v1/assistant", input)).status).toBe(202);
    for (let i = 0; i < 2; i++)
      expect(
        (
          await request("POST", "/v1/assistant", {
            ...input,
            requestId: randomUUID(),
          })
        ).status,
      ).toBe(202);
    expect(
      (
        await request("POST", "/v1/assistant", {
          ...input,
          requestId: randomUUID(),
        })
      ).status,
    ).toBe(429);
    expect(await holder.store.list("jobs")).toHaveLength(3);
  });
  it("reuses recent export requests across devices without creating another job", async () => {
    const input = {
      _account: "alice",
      type: "export",
      requestId: randomUUID(),
    };
    const first = await request("POST", "/v1/privacy", input);
    expect(first.status).toBe(202);
    const second = await request("POST", "/v1/privacy", {
      ...input,
      requestId: randomUUID(),
    });
    expect(second.status).toBe(202);
    expect(second.body.id).toBe(first.body.id);
    expect(second.body.reused).toBe(true);
    expect(await holder.store.list("jobs")).toHaveLength(1);
  });
  it("queues a first-party review without enabling provider delivery", async () => {
    const command = { type: "review.weekly" };
    const first = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: randomUUID(),
      command,
    });
    const next = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: randomUUID(),
      command,
    });
    expect(first.status).toBe(200);
    expect(next.body.id).toBe(first.body.id);
    expect((await holder.store.list<any>("jobs"))[0].data.type).toBe(
      "review.prepare",
    );
    expect(await holder.store.get("profiles", "current")).toBeNull();
  });
  it.each(["succeeded", "failed", "needs_attention"])(
    "starts a fresh export after a %s export while replaying the same request safely",
    async (status) => {
      const input = {
        _account: "alice",
        type: "export",
        requestId: randomUUID(),
      };
      const first = await request("POST", "/v1/privacy", input);
      await holder.store.mutate(
        "finish-export",
        "finish-export",
        async (tx) => {
          const job = (await tx.get<any>("jobs", first.body.id))!;
          await tx.put("jobs", job.id, { ...job.data, status }, job.version);
        },
      );
      const replay = await request("POST", "/v1/privacy", input);
      expect(replay.body.id).toBe(first.body.id);
      const next = await request("POST", "/v1/privacy", {
        ...input,
        requestId: randomUUID(),
      });
      expect(next.status).toBe(202);
      expect(next.body.id).not.toBe(first.body.id);
      expect(next.body.reused).toBe(false);
      expect(await holder.store.list("jobs")).toHaveLength(2);
    },
  );
  it("stops new financial commands after deletion is accepted", async () => {
    process.env.SPROUT_FIRST_PARTY_ERASURE = "true";
    expect(
      (
        await request("POST", "/v1/privacy", {
          _account: "alice",
          type: "delete",
          receipt: "a".repeat(43),
          requestId: randomUUID(),
        })
      ).status,
    ).toBe(202);
    const response = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: "m",
      command: {
        type: "transaction.upsert",
        expectedVersion: 0,
        transaction: {
          id: "expense",
          amount: { minor: -29, currency: "USD" },
          date: "2026-11-09",
          merchant: "Coffee",
          category: "Food",
          type: "expense",
          source: "manual",
        },
      },
    });
    expect(response.status).toBe(410);
    expect(await holder.store.list("transactions")).toHaveLength(0);
    expect(
      (
        await request("POST", "/v1/bank/link-token", {
          _account: "alice",
          platform: "ios",
        })
      ).status,
    ).toBe(410);
  });
  it("keeps live mutations closed until consistency verification is explicitly enabled", async () => {
    process.env.SPROUT_FINANCIAL_WRITES = "false";
    const response = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: "m",
      command: {
        type: "transaction.delete",
        id: "expense",
        expectedVersion: 1,
      },
    });
    expect(response.body.error.code).toBe("CONSISTENCY_GATE");
    expect(await holder.store.revision()).toBe(0);
  });
  it("rejects a request whose expected account differs from verified identity before reading records", async () => {
    expect((await request("GET", "/v1/bootstrap", {}, "bob")).status).toBe(409);
    expect(await holder.store.revision()).toBe(0);
  });
  it("rejects a queued change that belongs to a different account", async () => {
    const response = await request("POST", "/v1/commands", {
      _account: "bob",
      mutationId: "m",
      command: { type: "transaction.delete", id: "other", expectedVersion: 1 },
    });
    expect(response.body.error.code).toBe("ACCOUNT_CHANGED");
    expect(await holder.store.revision()).toBe(0);
  });
  it("echoes verified snapshot ownership for the local cache check", async () => {
    const response = await request("GET", "/v1/bootstrap", {});
    expect(response.status).toBe(200);
    expect(response.body.accountId).toBe("alice");
  });
  it("removes the account marker only after checking it and validates the command", async () => {
    const response = await request("POST", "/v1/commands", {
      _account: "alice",
      mutationId: "m",
      command: {
        type: "transaction.upsert",
        expectedVersion: 0,
        transaction: {
          id: "expense",
          amount: { minor: -29, currency: "USD" },
          date: "2026-11-09",
          merchant: "Coffee",
          category: "Food",
          type: "expense",
          source: "manual",
        },
      },
    });
    expect(response.status).toBe(200);
    expect(await holder.store.list("transactions")).toHaveLength(1);
  });
});
