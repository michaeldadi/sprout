/** Bounded staging-only read benchmark. Never seeds or changes financial facts. */
import { Account, Client, ExecutionMethod, Functions } from "node-appwrite";
import { readFile, stat, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";

const endpoint = "https://nyc.cloud.appwrite.io/v1";
const project = "6af0f72200383d2f1084";
const close: Array<() => Promise<unknown>> = [];
const hash = (v: any) => createHash("sha256").update(JSON.stringify({
  profile: v.profile, transactions: v.transactions, budgets: v.budgets,
  goals: v.goals, receipts: v.receipts,
})).digest("hex");
const percentile = (values: number[], p: number) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)];
};
async function main() {
  const directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  assert.ok(directory && ((await stat(directory)).mode & 0o077) === 0);
  const identities = JSON.parse(await readFile(`${directory}/test-identities.json`, "utf8"));
  assert.ok(identities.length >= 2);
  const users = [];
  for (const identity of identities.slice(0, 2)) {
    assert.match(identity.email, /@example\.invalid$/);
    const session = await fetch(`${endpoint}/account/sessions/email`, {
      method: "POST", headers: {"x-appwrite-project": project, "content-type": "application/json"},
      body: JSON.stringify({email: identity.email, password: identity.password}), signal: AbortSignal.timeout(15000),
    });
    assert.equal(session.status, 201);
    const cookie = session.headers.getSetCookie().map(v => v.split(";")[0]).join("; ");
    close.push(() => fetch(`${endpoint}/account/sessions/current`, {
      method: "DELETE", headers: {"x-appwrite-project": project, cookie}, signal: AbortSignal.timeout(5000),
    }));
    const response = await fetch(`${endpoint}/account/jwts`, {
      method: "POST", headers: {"x-appwrite-project": project, "content-type": "application/json", cookie},
      body: "{}", signal: AbortSignal.timeout(15000),
    });
    assert.equal(response.status, 201);
    const jwt = (await response.json() as any).jwt;
    const client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
    assert.equal((await new Account(client).get()).$id, identity.id);
    const request = async (path: string) => {
      const start = performance.now();
      const execution = await new Functions(client).createExecution({
        functionId: "sprout-api", async: false, xpath: path, method: ExecutionMethod.GET,
        headers: {"x-sprout-account": identity.id},
      });
      const elapsedMs = Math.round(performance.now() - start);
      assert.equal(execution.responseStatusCode, 200);
      return {value: JSON.parse(execution.responseBody), elapsedMs, serverMs: Math.round(execution.duration * 1000)};
    };
    const baseline = await request("/v1/bootstrap");
    assert.equal(baseline.value.accountId, identity.id);
    users.push({identity, request, baseline: baseline.value, hash: hash(baseline.value)});
  }
  const samples: Array<{route: string; elapsedMs: number; serverMs: number}> = [];
  const tasks = Array.from({length: 40}, (_, index) => index);
  const started = performance.now();
  await Promise.all(Array.from({length: 4}, async () => {
    for (;;) {
      const index = tasks.shift(); if (index === undefined) break;
      const user = users[index % users.length];
      const result = await user.request("/v1/bootstrap");
      assert.equal(result.value.accountId, user.identity.id);
      assert.equal(hash(result.value), user.hash, "Read load must preserve isolated financial state");
      samples.push({route: "bootstrap", elapsedMs: result.elapsedMs, serverMs: result.serverMs});
    }
  }));
  for (const user of users) {
    const result = await user.request("/v1/bootstrap");
    assert.equal(hash(result.value), user.hash);
  }
  const serverP95Ms = percentile(samples.map(s => s.serverMs), .95);
  const report = {
    project, checkedAt: new Date().toISOString(), status: "passed", financialWrites: 0,
    scope: "40 warm bootstrap reads, 4 concurrent requests, 2 existing synthetic staging accounts. This is not a 100-user or bank-history-scale certification.",
    samples: samples.length, concurrency: 4, elapsedMs: Math.round(performance.now() - started),
    server: {p50Ms: percentile(samples.map(s => s.serverMs), .5), p95Ms: serverP95Ms, maxMs: Math.max(...samples.map(s => s.serverMs))},
    client: {p50Ms: percentile(samples.map(s => s.elapsedMs), .5), p95Ms: percentile(samples.map(s => s.elapsedMs), .95), maxMs: Math.max(...samples.map(s => s.elapsedMs))},
    target: {serverP95BelowMs: 2000, met: serverP95Ms < 2000},
    checks: ["all responses successful", "each response belongs to the expected account", "all financial facts and preferences unchanged"],
  };
  await writeFile(`${directory}/live-read-performance.json`, JSON.stringify(report, null, 2));
  process.stdout.write(JSON.stringify(report) + "\n");
}
main().catch((error: any) => { process.stderr.write(`Bounded read validation failed (${error.code ?? error.name}).\n`); process.exitCode = 1; })
  .finally(async () => { await Promise.allSettled(close.map(f => f())); });
