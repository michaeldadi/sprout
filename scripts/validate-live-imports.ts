/** Synthetic staging-only checkpoint, private-input and replay proof. */
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import {
  Account,
  Client,
  ExecutionMethod,
  Functions,
  TablesDB,
} from "node-appwrite";
import { AppwriteStore, rowId } from "../services/integrations/appwrite-store";
import {
  applyImportChunk,
  importedTransactionId,
  queueImport,
} from "../services/domain/imports";
import { finish, type Job } from "../services/domain/jobs";
import { fingerprint } from "../services/domain/finance";
import { transactionImport } from "../services/contracts";

let stage = "configuration";
let close: (() => Promise<unknown>) | undefined;
async function main() {
  const project = "6af0f72200383d2f1084",
    endpoint = "https://nyc.cloud.appwrite.io/v1",
    directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  assert.equal(process.env.APPWRITE_FUNCTION_PROJECT_ID, project);
  assert.ok(directory && process.env.SPROUT_TEST_SERVICE_KEY);
  const identity = JSON.parse(
    await readFile(`${directory}/test-identities.json`, "utf8"),
  )[0];
  const login = await fetch(`${endpoint}/account/sessions/email`, {
    method: "POST",
    headers: {
      "x-appwrite-project": project,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      email: identity.email,
      password: identity.password,
    }),
  });
  assert.equal(login.status, 201);
  const cookie = login.headers
    .getSetCookie()
    .map((v) => v.split(";")[0])
    .join("; ");
  close = () =>
    fetch(`${endpoint}/account/sessions/current`, {
      method: "DELETE",
      headers: { "x-appwrite-project": project, cookie },
      signal: AbortSignal.timeout(5000),
    });
  const response = await fetch(`${endpoint}/account/jwts`, {
    method: "POST",
    headers: {
      "x-appwrite-project": project,
      "content-type": "application/json",
      cookie,
    },
    body: "{}",
  });
  assert.equal(response.status, 201);
  const client = new Client()
    .setEndpoint(endpoint)
    .setProject(project)
    .setJWT(((await response.json()) as any).jwt);
  assert.equal((await new Account(client).get()).$id, identity.id);
  const store = new AppwriteStore(
    identity.id,
    process.env.SPROUT_TEST_SERVICE_KEY!,
  );
  const batchId = createHash("sha256").update(randomUUID()).digest("hex"),
    token = randomUUID();
  const batch = transactionImport.parse({
    type: "transaction.import",
    batchId,
    rows: Array.from({ length: 65 }, (_, sourceIndex) => ({
      sourceIndex,
      transaction: {
        id: importedTransactionId(batchId, sourceIndex),
        amount: { minor: -101, currency: "USD" },
        date: "2026-11-10",
        merchant: `Checkpoint import ${sourceIndex}`,
        category: "Other",
        description: "試".repeat(900),
        type: "expense",
        source: "import",
        accountId: "cash",
      },
    })),
  });
  stage = "atomic private-input queue";
  const queued = await store.mutate(
    `import-proof:${batchId}`,
    fingerprint(batch),
    async (tx) => {
      const result = await queueImport(tx, batch),
        job = (await tx.get<Job>("jobs", result.id))!;
      await tx.put(
        "jobs",
        job.id,
        {
          ...job.data,
          status: "running",
          attempts: 1,
          leaseToken: token,
          leaseUntil: new Date(Date.now() + 240000).toISOString(),
        },
        job.version,
      );
      return result;
    },
  );
  const job = (await store.get<Job>("jobs", queued.id))!;
  const parts = job.data.payload.parts as Array<{ id: string }>;
  assert.ok(parts.length > 1);
  stage = "server-only input permissions";
  for (const part of parts)
    await assert.rejects(
      new TablesDB(client).getRow({
        databaseId: store.database,
        tableId: "import_inputs",
        rowId: rowId(identity.id, "import_inputs", part.id),
      }),
      (error: any) => [401, 403, 404].includes(error.code),
    );
  const events = await store.changes((await store.revision()) - 1, 1);
  assert.ok(!JSON.stringify(events).includes("試"));
  stage = "checkpoint and stale-worker rejection";
  const first = await applyImportChunk(store, job.id, token);
  assert.ok(first.processed > 0 && first.processed < 65);
  await assert.rejects(
    applyImportChunk(store, job.id, "expired-worker"),
    (error: any) => error.code === "LEASE_LOST",
  );
  const firstRow = batch.rows[0].transaction;
  const current = (await store.get<any>("transactions", firstRow.id))!;
  await store.mutate(`correct-import:${batchId}`, "correction", (tx) =>
    tx.put(
      "transactions",
      current.id,
      { ...current.data, merchant: "Reviewed existing import correction" },
      current.version,
    ),
  );
  let progress = first;
  while (!progress.complete)
    progress = await applyImportChunk(store, job.id, token);
  await finish(store, job.id, token, progress);
  assert.equal(progress.imported, 65);
  assert.equal(
    (await store.get<any>("transactions", firstRow.id))!.data.merchant,
    "Reviewed existing import correction",
  );
  for (const part of parts) {
    const row = await store.get("import_inputs", part.id);
    assert.equal(row?.deleted, true);
    assert.equal(row?.data, null);
  }
  stage = "public API replay and privacy";
  const request = async (path: string, body?: unknown) => {
    const execution = await new Functions(client).createExecution({
      functionId: "sprout-api",
      async: false,
      xpath: path,
      method: body ? ExecutionMethod.POST : ExecutionMethod.GET,
      body: body
        ? JSON.stringify({ ...(body as object), _account: identity.id })
        : undefined,
      headers: { "x-sprout-account": identity.id },
    });
    assert.ok(
      execution.responseStatusCode < 300,
      `API status ${execution.responseStatusCode}`,
    );
    return JSON.parse(execution.responseBody);
  };
  const replay = await request("/v1/commands", {
    mutationId: randomUUID(),
    command: batch,
  });
  assert.equal(replay.id, job.id);
  const view = await request("/v1/bootstrap");
  assert.ok(!JSON.stringify(view).includes('"import_inputs"'));
  assert.equal(
    view.transactions.filter((v: any) =>
      batch.rows.some((r) => r.transaction.id === v.id),
    ).length,
    65,
  );
  assert.equal(
    view.jobs.find((j: any) => j.id === job.id).progress.processed,
    65,
  );
  const results = {
    project,
    checkedAt: new Date().toISOString(),
    status: "passed",
    rows: 65,
    tests: [
      "large Unicode review is queued in bounded private input parts",
      "even the owning mobile session cannot read raw input parts",
      "sync journal omits private input text",
      "each checkpoint commits financial facts and progress atomically",
      "stale worker cannot continue the import",
      "resumption preserves a user correction to an already imported record",
      "completed inputs become empty tombstones",
      "public command replay returns the same import without duplicate records",
      "bootstrap exposes progress without operational input records",
    ],
  };
  await writeFile(
    `${directory}/live-import-checkpoint-results.json`,
    JSON.stringify(results, null, 2),
  );
  process.stdout.write(
    "Verified live import checkpoints, private inputs, replay and user corrections.\n",
  );
}
main()
  .catch((error: any) => {
    process.stderr.write(
      `Live import proof failed at ${stage} (${error?.code ?? error?.name ?? "unknown"}).\n`,
    );
    process.exitCode = 1;
  })
  .finally(async () => {
    if (close) await close();
  });
