/** Explicit, compatible-code staging rollback drill. No schema or financial writes.
 * Requires the metadata key and the recorded source hash of an older deployment. */
import { Account, Client, Functions, ExecutionMethod } from "node-appwrite";
import { createHash } from "node:crypto";
import { readFile, writeFile, stat, unlink } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import assert from "node:assert/strict";
import path from "node:path";

const project = "6af0f72200383d2f1084", endpoint = "https://nyc.cloud.appwrite.io/v1";
const close: Array<() => Promise<unknown>> = [];
let stage = "configuration";
const sha = (value: string | Uint8Array) => createHash("sha256").update(value).digest("hex");
const financial = (v: any) => sha(JSON.stringify({profile: v.profile, transactions: v.transactions, budgets: v.budgets, goals: v.goals, receipts: v.receipts}));
async function main() {
  const directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR, key = process.env.APPWRITE_API_KEY;
  assert.ok(directory && path.isAbsolute(directory) && ((await stat(directory)).mode & 0o077) === 0 && key);
  assert.equal(process.env.APPWRITE_PROJECT_ID, project);
  assert.equal(process.env.APPWRITE_ENDPOINT, endpoint);
  const target = process.env.SPROUT_ROLLBACK_TARGET, targetHash = process.env.SPROUT_ROLLBACK_TARGET_SHA256;
  assert.match(target ?? "", /^[a-zA-Z0-9._-]{1,36}$/);
  assert.match(targetHash ?? "", /^[a-f0-9]{64}$/);
  const manifest = JSON.parse(await readFile(`${directory}/deployments.json`, "utf8"));
  assert.equal(manifest.project, project);
  const current = manifest.functions.find((f: any) => f.functionId === "sprout-api");
  assert.ok(current?.deploymentId && current.deploymentId !== target);
  const functions = new Functions(new Client().setEndpoint(endpoint).setProject(project).setKey(key));
  assert.equal((await functions.get({functionId: "sprout-api"})).deploymentId, current.deploymentId);
  assert.equal((await functions.getDeployment({functionId: "sprout-api", deploymentId: target!})).status, "ready");
  assert.equal((await functions.getDeployment({functionId: "sprout-api", deploymentId: current.deploymentId})).status, "ready");
  const archive = path.join(directory, "rollback-target-source.tar.gz");
  stage = "verify immutable source before activation";
  try {
    const bytes = new Uint8Array(await functions.getDeploymentDownload({functionId: "sprout-api", deploymentId: target!}));
    assert.ok(bytes.byteLength < 25_000_000);
    await writeFile(archive, bytes, {mode: 0o600});
    const code = execFileSync("tar", ["-xOzf", archive, "main.js"], {maxBuffer: 16_000_000});
    assert.equal(sha(code), targetHash, "Rollback target differs from reviewed immutable source");
  } finally { await unlink(archive).catch(() => undefined); }
  const identities = JSON.parse(await readFile(`${directory}/test-identities.json`, "utf8"));
  const users = [];
  for (const identity of identities.slice(0, 2)) {
    assert.match(identity.email, /@example\.invalid$/);
    const response = await fetch(`${endpoint}/account/sessions/email`, {method: "POST", headers: {"x-appwrite-project": project, "content-type": "application/json"}, body: JSON.stringify({email: identity.email, password: identity.password}), signal: AbortSignal.timeout(15000)});
    assert.equal(response.status, 201);
    const cookie = response.headers.getSetCookie().map(v => v.split(";")[0]).join("; ");
    close.push(() => fetch(`${endpoint}/account/sessions/current`, {method: "DELETE", headers: {"x-appwrite-project": project, cookie}, signal: AbortSignal.timeout(5000)}));
    const jwtResponse = await fetch(`${endpoint}/account/jwts`, {method: "POST", headers: {"x-appwrite-project": project, "content-type": "application/json", cookie}, body: "{}", signal: AbortSignal.timeout(15000)});
    assert.equal(jwtResponse.status, 201);
    const jwt = (await jwtResponse.json() as any).jwt, client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
    assert.equal((await new Account(client).get()).$id, identity.id);
    const read = async () => {
      const execution = await new Functions(client).createExecution({functionId: "sprout-api", async: false, xpath: "/v1/bootstrap", method: ExecutionMethod.GET, headers: {"x-sprout-account": identity.id}});
      assert.equal(execution.responseStatusCode, 200);
      const value = JSON.parse(execution.responseBody); assert.equal(value.accountId, identity.id); assert.equal(value.projectionVersion, 3);
      return financial(value);
    };
    users.push({read, before: await read()});
  }
  assert.equal(users.length, 2);
  const plan = {project, functionId: "sprout-api", currentDeployment: current.deploymentId, currentSha256: current.sha256, rollbackDeployment: target, rollbackSha256: targetHash, financialWrites: 0, checkedAt: new Date().toISOString()};
  await writeFile(`${directory}/rollback-preview.json`, JSON.stringify(plan, null, 2), {mode: 0o600});
  // Verify the expected active version again at action time. Appwrite has no
  // compare-and-swap activation API; concurrent deployers must remain quiescent.
  assert.equal((await functions.get({functionId: "sprout-api"})).deploymentId, current.deploymentId);
  const started = performance.now(); let activated = false;
  try {
    stage = "activate and validate compatible rollback";
    activated = true; // A lost activation response must still enter restoration.
    await functions.updateFunctionDeployment({functionId: "sprout-api", deploymentId: target!});
    assert.equal((await functions.get({functionId: "sprout-api"})).deploymentId, target);
    for (const user of users) assert.equal(await user.read(), user.before);
  } finally {
    if (activated) {
      stage = "restore original active deployment";
      const active = (await functions.get({functionId: "sprout-api"})).deploymentId;
      assert.ok(active === target || active === current.deploymentId, "A concurrent deployment changed the function; do not overwrite it");
      if (active !== current.deploymentId) await functions.updateFunctionDeployment({functionId: "sprout-api", deploymentId: current.deploymentId});
      assert.equal((await functions.get({functionId: "sprout-api"})).deploymentId, current.deploymentId);
    }
  }
  stage = "verify restored financial readback";
  for (const user of users) assert.equal(await user.read(), user.before);
  const result = {...plan, status: "passed", restoredCurrent: true, elapsedMs: Math.round(performance.now() - started), scope: "Compatible API code rollback only; no schema, worker, bank-history or production rollback proof", checks: ["reviewed target source SHA-256", "fresh expected-active guard", "older immutable deployment serves isolated accounts", "financial state unchanged before/during/after", "original active deployment restored and read back"]};
  await writeFile(`${directory}/live-api-rollback.json`, JSON.stringify(result, null, 2));
  process.stdout.write(JSON.stringify(result) + "\n");
}
main().catch((error: any) => {process.stderr.write(`Staging rollback drill failed at ${stage} (${error.code ?? error.name}); inspect active deployment before further work.\n`); process.exitCode = 1;})
  .finally(async () => {await Promise.allSettled(close.map(f => f()));});
