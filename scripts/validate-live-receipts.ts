/** Real JPEG, authenticated API and private storage acceptance; staging only. */
import assert from "node:assert/strict";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import {
  Account,
  Client,
  ExecutionMethod,
  Functions,
  TablesDB,
} from "node-appwrite";
import { rowId } from "../services/integrations/appwrite-store";
import { fingerprint } from "../services/domain/finance";

const endpoint = "https://nyc.cloud.appwrite.io/v1",
  project = "6af0f72200383d2f1084";
let stage = "configuration";
let transientRetries = 0;
const sessions: Array<() => Promise<unknown>> = [];
async function main() {
  const directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  assert.ok(directory && process.env.SPROUT_TEST_RECEIPT_JPEG);
  const identities = JSON.parse(
    await readFile(`${directory}/test-identities.json`, "utf8"),
  );
  const jpeg = await readFile(process.env.SPROUT_TEST_RECEIPT_JPEG!);
  assert.ok(jpeg.length < 650000 && jpeg[0] === 255 && jpeg[1] === 216);
  const sha256 = createHash("sha256").update(jpeg).digest("hex");
  async function login(identity: any) {
    const response = await fetch(`${endpoint}/account/sessions/email`, {
      method: "POST",
      headers: {
        "x-appwrite-project": project,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        email: identity.email,
        password: identity.password,
      }),
      signal: AbortSignal.timeout(15000),
    });
    assert.equal(response.status, 201, "Synthetic identity must authenticate");
    const cookie = response.headers
      .getSetCookie()
      .map((v) => v.split(";")[0])
      .join("; ");
    sessions.push(() =>
      fetch(`${endpoint}/account/sessions/current`, {
        method: "DELETE",
        headers: { "x-appwrite-project": project, cookie },
        signal: AbortSignal.timeout(5000),
      }),
    );
    const token = await fetch(`${endpoint}/account/jwts`, {
      method: "POST",
      headers: {
        "x-appwrite-project": project,
        "content-type": "application/json",
        cookie,
      },
      body: "{}",
      signal: AbortSignal.timeout(10000),
    });
    assert.equal(token.status, 201);
    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(project)
      .setJWT(((await token.json()) as any).jwt);
    assert.equal((await new Account(client).get()).$id, identity.id);
    const functions = new Functions(client);
    const execute = async (functionId: string, path: string, body?: any) => {
      const execution = await functions.createExecution({
        functionId,
        async: false,
        xpath: path,
        method: body ? ExecutionMethod.POST : ExecutionMethod.GET,
        headers: { "x-sprout-account": identity.id },
        body: body
          ? JSON.stringify({
              ...body,
              ...(functionId === "sprout-api" ? { _account: identity.id } : {}),
            })
          : undefined,
      });
      let value: any;
      try {
        value = JSON.parse(execution.responseBody);
      } catch {
        value = {};
      }
      return { status: execution.responseStatusCode, value };
    };
    const request = async (path: string, body?: any) => {
      let r = await execute("sprout-api", path, body);
      for (let attempt = 1; r.status >= 500 && attempt <= 5; attempt++) {
        transientRetries++;
        await new Promise((resolve) =>
          setTimeout(resolve, 250 * attempt * attempt),
        );
        // The exact request and mutation identity remain unchanged on retry.
        r = await execute("sprout-api", path, body);
      }
      assert.ok(
        r.status >= 200 && r.status < 300,
        `API ${r.status} ${r.value.error?.code ?? ""}`,
      );
      return r.value;
    };
    return {
      client,
      request,
      execute,
      command: (command: any, mutationId = randomUUID()) =>
        request("/v1/commands", { command, mutationId }),
      download: (file: any) =>
        fetch(
          `${endpoint}/storage/buckets/${file.bucketId}/files/${file.fileId}/download`,
          {
            headers: { "x-appwrite-project": project, cookie },
            signal: AbortSignal.timeout(10000),
          },
        ),
    };
  }
  const alice = await login(identities[0]),
    bob = await login(identities[1]);
  const beforeBob = await bob.request("/v1/bootstrap");
  const transactionId = randomUUID();
  stage = "reviewed financial parent";
  await alice.command({
    type: "transaction.upsert",
    expectedVersion: 0,
    transaction: {
      id: transactionId,
      amount: { minor: -540, currency: "USD" },
      date: "2026-11-10",
      merchant: "Synthetic retained receipt acceptance",
      category: "Other",
      description: "Synthetic JPEG only",
      type: "expense",
      source: "manual",
      accountId: "cash",
    },
  });
  const receiptId = randomUUID(),
    mutationId = randomUUID();
  const attach = {
    type: "receipt.attach",
    id: receiptId,
    transactionId,
    sha256,
    jpegBase64: jpeg.toString("base64"),
  };
  stage = "owner-only retention through private actor";
  await alice.command(attach, mutationId);
  let view = await alice.request("/v1/bootstrap");
  const file = view.receipts.find((r: any) => r.id === receiptId);
  assert.equal(file?.status, "ready");
  assert.equal(file.sha256, sha256);
  assert.equal(file.bytes, jpeg.length);
  assert.ok(!JSON.stringify(view).includes(attach.jpegBase64));
  assert.ok(!JSON.stringify(file).includes("leaseToken"));
  const downloaded = await alice.download(file);
  assert.equal(downloaded.status, 200);
  assert.equal(
    createHash("sha256")
      .update(Buffer.from(await downloaded.arrayBuffer()))
      .digest("hex"),
    sha256,
  );
  stage = "peer, anonymous and private function isolation";
  assert.ok([401, 403, 404].includes((await bob.download(file)).status));
  assert.ok(
    [401, 403, 404].includes(
      (
        await fetch(
          `${endpoint}/storage/buckets/${file.bucketId}/files/${file.fileId}/download`,
          {
            headers: { "x-appwrite-project": project },
            signal: AbortSignal.timeout(10000),
          },
        )
      ).status,
    ),
  );
  await assert.rejects(
    new TablesDB(alice.client).getRow({
      databaseId: "6af0f7c600244c241e44",
      tableId: "receipts",
      rowId: rowId(identities[0].id, "receipts", receiptId),
    }),
    (e: any) => [401, 403, 404].includes(e.code),
  );
  await assert.rejects(
    new Functions(alice.client).createExecution({
      functionId: "sprout-privacy",
      async: false,
      body: JSON.stringify({
        owner: identities[1].id,
        receipt: attach,
        mutationId: randomUUID(),
      }),
    }),
    (e: any) => [401, 403, 404].includes(e.code),
  );
  stage = "repeat submission and changed-content rejection";
  await alice.command(attach, mutationId);
  await alice.command(attach);
  view = await alice.request("/v1/bootstrap");
  assert.equal(view.receipts.filter((r: any) => r.id === receiptId).length, 1);
  const changed = await alice.execute("sprout-api", "/v1/commands", {
    mutationId: randomUUID(),
    command: { ...attach, sha256: "a".repeat(64) },
  });
  assert.ok(changed.status >= 400 && changed.status < 500);
  stage = "remove and authoritative file absence";
  await alice.command({
    type: "receipt.remove",
    id: receiptId,
    expectedVersion: file.version,
  });
  for (let n = 0; n < 70; n++) {
    view = await alice.request("/v1/bootstrap");
    if (!view.receipts.some((r: any) => r.id === receiptId)) break;
    await new Promise((r) => setTimeout(r, 5000));
  }
  assert.ok(!view.receipts.some((r: any) => r.id === receiptId));
  assert.equal((await alice.download(file)).status, 404);
  const resurrect = await alice.execute("sprout-api", "/v1/commands", {
    mutationId: randomUUID(),
    command: attach,
  });
  assert.equal(resurrect.status, 409);
  stage = "cancel before a delayed upload";
  const cancelledId = randomUUID();
  await alice.command({ type: "receipt.cancel", id: cancelledId });
  const delayed = await alice.execute("sprout-api", "/v1/commands", {
    mutationId: randomUUID(),
    command: { ...attach, id: cancelledId },
  });
  assert.equal(delayed.status, 409);
  stage = "parent deletion cleans private copy";
  const secondId = randomUUID();
  await alice.command({ ...attach, id: secondId });
  view = await alice.request("/v1/bootstrap");
  const secondFile = view.receipts.find((r: any) => r.id === secondId);
  assert.equal(secondFile?.status, "ready");
  await alice.command({
    type: "transaction.delete",
    id: transactionId,
    expectedVersion: view.transactions.find((r: any) => r.id === transactionId)
      .version,
  });
  for (let n = 0; n < 70; n++) {
    view = await alice.request("/v1/bootstrap");
    if (!view.receipts.some((r: any) => r.id === secondId)) break;
    await new Promise((r) => setTimeout(r, 5000));
  }
  assert.ok(!view.receipts.some((r: any) => r.id === secondId));
  assert.equal((await alice.download(secondFile)).status, 404);
  assert.deepEqual(
    (await bob.request("/v1/bootstrap")).transactions,
    beforeBob.transactions,
  );
  assert.deepEqual(
    (await bob.request("/v1/bootstrap")).receipts,
    beforeBob.receipts,
  );
  if (process.argv[2] === "privacy") {
    stage = "dedicated private-file erasure identity";
    const owner = randomUUID(),
      target = randomUUID(),
      retained = randomUUID(),
      racing = randomUUID();
    const identity = {
      id: owner,
      email: `sprout-file-erasure-${owner}@example.invalid`,
      password: "aA1!" + randomBytes(24).toString("base64url"),
      receipt: randomBytes(32).toString("base64url"),
      deletionRequestId: randomUUID(),
    };
    await writeFile(
      `${directory}/receipt-erasure-identity.json`,
      JSON.stringify(identity),
      { mode: 0o600 },
    );
    await new Account(
      new Client().setEndpoint(endpoint).setProject(project),
    ).create({
      userId: owner,
      email: identity.email,
      password: identity.password,
      name: "Synthetic private file erasure",
    });
    const subject = await login(identity);
    await subject.command({
      type: "transaction.upsert",
      expectedVersion: 0,
      transaction: {
        id: target,
        amount: { minor: -540, currency: "USD" },
        date: "2026-11-10",
        merchant: "Synthetic erasure receipt",
        category: "Other",
        type: "expense",
        source: "manual",
        accountId: "cash",
      },
    });
    await subject.command({ ...attach, id: retained, transactionId: target });
    assert.equal(
      (await subject.request("/v1/bootstrap")).receipts.find(
        (r: any) => r.id === retained,
      )?.status,
      "ready",
    );
    stage = "concurrent upload, export and accepted deletion";
    await writeFile(
      `${directory}/receipt-erasure-expected-files.json`,
      JSON.stringify({
        project,
        owner,
        bucketId: "sprout-private",
        receiptFileIds: [retained, racing].map((id) =>
          fingerprint(["receipt", owner, id]).slice(0, 36),
        ),
      }),
      { mode: 0o600 },
    );
    const concurrent = Promise.allSettled([
      subject.command({ ...attach, id: racing, transactionId: target }),
      subject.request("/v1/privacy", {
        type: "export",
        requestId: randomUUID(),
      }),
    ]);
    await new Promise((resolve) => setTimeout(resolve, 500));
    await subject.request("/v1/privacy", {
      type: "delete",
      requestId: identity.deletionRequestId,
      receipt: identity.receipt,
    });
    const attempts = await concurrent;
    const publicFunctions = new Functions(
      new Client().setEndpoint(endpoint).setProject(project),
    );
    let progress: any;
    for (let n = 0; n < 150; n++) {
      const execution = await publicFunctions.createExecution({
        functionId: "sprout-privacy-status",
        async: false,
        method: ExecutionMethod.POST,
        body: JSON.stringify({ receipt: identity.receipt }),
      });
      assert.equal(execution.responseStatusCode, 200);
      progress = JSON.parse(execution.responseBody);
      if (progress.status === "active_data_removed") break;
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
    assert.equal(progress.status, "active_data_removed");
    assert.ok(Object.values(progress.steps).every(Boolean));
    await assert.rejects(new Account(subject.client).get(), (e: any) =>
      [401, 403].includes(e.code),
    );
    assert.deepEqual(
      (await bob.request("/v1/bootstrap")).transactions,
      beforeBob.transactions,
    );
    await writeFile(
      `${directory}/receipt-erasure-proof.json`,
      JSON.stringify(
        {
          project,
          checkedAt: new Date().toISOString(),
          status: "awaiting_independent_admin_readback",
          owner,
          bucketId: "sprout-private",
          receiptFileIds: [retained, racing].map((id) =>
            fingerprint(["receipt", owner, id]).slice(0, 36),
          ),
          progress,
          concurrentAttempts: attempts.map((r) => r.status),
          transientRetries,
          limitations: [
            "requests overlap; no claim that an upload reached storage before the deletion ledger was accepted",
          ],
        },
        null,
        2,
      ),
      { mode: 0o600 },
    );
    process.stdout.write(
      "Private-file deletion completed and access is revoked; independent scoped storage readback remains.\n",
    );
  }
  await writeFile(
    `${directory}/live-receipts-results.json`,
    JSON.stringify(
      {
        project,
        checkedAt: new Date().toISOString(),
        status: "passed",
        jpegSha256: sha256,
        jpegBytes: jpeg.length,
        transientRetries,
        tests: [
          "real JPEG retained through verified-owner API and server-only private actor",
          "owner download SHA matches reviewed compressed image",
          "peer, anonymous, direct private-function and direct receipt-row access denied",
          "no JPEG or internal lease in public workspace",
          "same and new mutation retries do not duplicate files",
          "changed content rejected",
          "explicit removal makes private file return 404",
          "cancel before delayed upload prevents resurrection",
          "parent deletion removes the retained copy",
          "unrelated synthetic account unchanged",
        ],
        limitations: [
          "simulated IO races remain domain tests; account-erasure concurrency is validated separately",
          "native picker and preview require their own acceptance runs",
        ],
      },
      null,
      2,
    ),
  );
  process.stdout.write(
    "Passed live private JPEG retention, isolation, replay and removal.\n",
  );
}
main()
  .catch((e) => {
    process.stderr.write(
      `Receipt acceptance failed at ${stage}: ${e?.code ?? e?.name ?? "unknown"} ${String(e?.message ?? "").slice(0, 240)}\n`,
    );
    process.exitCode = 1;
  })
  .finally(async () => {
    await Promise.allSettled(sessions.map((close) => close()));
  });
