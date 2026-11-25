/** Synthetic staging-only integration proof. Never uses production identities. */
import { Account, Client, Functions, TablesDB, ExecutionMethod } from "node-appwrite";
import { randomBytes, randomUUID } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { AppwriteStore, rowId } from "../services/integrations/appwrite-store";
let stage = "setup";
const closeSessions: Array<() => Promise<unknown>> = [];

async function main() {
  const dir = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  const key = process.env.SPROUT_TEST_SERVICE_KEY;
  const project = "6af0f72200383d2f1084";
  const endpoint = "https://nyc.cloud.appwrite.io/v1";
  if (!dir || !key || process.env.APPWRITE_FUNCTION_PROJECT_ID !== project) throw new Error("Staging test configuration required");
  const credentialsPath = `${dir}/test-identities.json`;
  let identities: any[];
  try { identities = JSON.parse(await readFile(credentialsPath, "utf8")); }
  catch {
    identities = [];
    for (const name of ["Sprout QA Alice", "Sprout QA Bob"]) {
      const id = randomUUID();
      const email = `sprout-qa-${id}@example.invalid`;
      const password = randomBytes(24).toString("base64url") + "aA1!";
      const account = new Account(new Client().setEndpoint(endpoint).setProject(project));
      await account.create({ userId: id, email, password, name });
      identities.push({ id, email, password, name });
      await writeFile(credentialsPath, JSON.stringify(identities), { mode: 0o600 });
    }
  }
  assert.equal(identities.length, 2);
  const clients = [];
  for (const identity of identities) {
    stage = "public email session";
    // Public login returns an HttpOnly session cookie. Server SDK session.secret
    // is intentionally empty without privileged session scopes; do not mint a
    // privileged session for a client-authentication test.
    const login = await fetch(`${endpoint}/account/sessions/email`, {method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json"},body:JSON.stringify({email:identity.email,password:identity.password})});
    if (login.status !== 201) { const error:any=await login.json(); throw {code:login.status,type:error.type}; }
    const cookies = login.headers.getSetCookie().map(value=>value.split(";")[0]).join("; ");
    closeSessions.push(()=>fetch(`${endpoint}/account/sessions/current`,{method:"DELETE",headers:{"x-appwrite-project":project,cookie:cookies},signal:AbortSignal.timeout(5000)}));
    const jwtResponse = await fetch(`${endpoint}/account/jwts`,{method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json",cookie:cookies},body:"{}"});
    stage = "public session JWT";
    if (jwtResponse.status !== 201) { const error:any=await jwtResponse.json(); throw {code:jwtResponse.status,type:error.type}; }
    const jwt = (await jwtResponse.json() as any).jwt;
    const client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
    stage = "JWT identity";
    const user = await new Account(client).get(); assert.equal(user.$id, identity.id);
    clients.push(client);
  }
  const report: any = { project, checkedAt: new Date().toISOString(), tests: [] };
  const checked = (name: string) => { report.tests.push(name); process.stdout.write(`Passed: ${name}\n`); };
  const invoke = async (client: Client, owner: string, path: string, body?: any) => {
    const response = await new Functions(client).createExecution({functionId:"sprout-api", async:false, xpath:path, method:body ? ExecutionMethod.POST : ExecutionMethod.GET, body:body ? JSON.stringify({...body,_account:owner}) : undefined, headers:{"x-sprout-account":owner}});
    return {status:response.responseStatusCode, body:JSON.parse(response.responseBody)};
  };
  stage = "function bootstrap";
  const bootstrap = await invoke(clients[0], identities[0].id, "/v1/bootstrap");
  if(bootstrap.status !== 200) throw {code:bootstrap.status,type:bootstrap.body?.error?.code ?? "unknown_function_error"};
  assert.equal(bootstrap.status, 200); assert.equal(bootstrap.body.accountId, identities[0].id); assert.equal(typeof bootstrap.body.cursor, "string"); checked("authenticated function bootstrap and account echo");
  const mismatch = await invoke(clients[1], identities[0].id, "/v1/bootstrap");
  assert.equal(mismatch.status,409); assert.equal(mismatch.body.error.code,"ACCOUNT_CHANGED"); checked("function rejects mismatched account marker");
  const gated = await invoke(clients[0], identities[0].id, "/v1/commands", {mutationId:randomUUID(),command:{type:"transaction.delete",id:"missing",expectedVersion:1}});
  assert.equal(gated.body.error.code,process.env.SPROUT_EXPECT_WRITES === "true" ? "VERSION_CONFLICT" : "CONSISTENCY_GATE"); checked(process.env.SPROUT_EXPECT_WRITES === "true" ? "financial writes enabled with expected-version validation" : "live financial write gate remains closed");
  const store = new AppwriteStore(identities[0].id, key);
  const suffix = randomUUID();
  const simultaneous = await Promise.all([1,2].map(()=>store.mutate(`same-${suffix}`,"same",tx=>tx.put("profiles",`same-${suffix}`,{proof:true},0))));
  assert.deepEqual(simultaneous[0],simultaneous[1]);assert.equal((await store.get("profiles",`same-${suffix}`))?.version,1);checked("simultaneous retries replay the same committed receipt");
  const seed = await store.mutate(`seed-${suffix}`, "seed", tx => tx.put("profiles", `proof-${suffix}`, { proof:true }, 0));
  assert.equal(seed.version,1);
  const revision = await store.revision();
  await store.mutate(`no-op-${suffix}`,"empty",async()=>null);
  assert.equal(await store.revision(),revision);
  assert.equal(await store.mutate(`no-op-${suffix}`,"empty",async()=>{throw new Error("No-op replay executed");}),null); checked("no-op receipts preserve the logical revision");
  const duplicate = await store.mutate(`seed-${suffix}`, "seed", async () => { throw new Error("receipt replay executed operation"); });
  assert.deepEqual(duplicate,seed); assert.equal(await store.revision(),revision); checked("atomic mutation receipt replays without another revision");
  const concurrent = await Promise.allSettled([1,2].map(i => store.mutate(`race-${suffix}-${i}`,String(i),tx => tx.put("profiles",`proof-${suffix}`,{winner:i},1))));
  assert.equal(concurrent.filter(x=>x.status==="fulfilled").length,1);
  assert.equal(concurrent.filter(x=>x.status==="rejected" && x.reason.code==="VERSION_CONFLICT").length,1);
  assert.equal((await store.get("profiles",`proof-${suffix}`))?.version,2); checked("concurrent expected-version writes have exactly one winner");
  for (const i of [0,1,2]) await store.mutate(`distinct-${suffix}-${i}`,String(i),tx=>tx.put("insight_feedback",`proof-${suffix}-${i}`,{feedback:"dismissed"},0));
  const events = await store.changes(revision-1,100,await store.revision());
  assert.deepEqual(events.map(e=>e.sequence),Array.from({length:events.length},(_,i)=>revision+i)); checked("cursor sequence has no gaps after rollback and retries");
  const aliceRows = new TablesDB(clients[0]); const bobRows = new TablesDB(clients[1]);
  const input = {databaseId:process.env.SPROUT_DATABASE_ID!,tableId:"profiles",rowId:rowId(identities[0].id,"profiles",`proof-${suffix}`)};
  assert.equal((await aliceRows.getRow(input)).owner,identities[0].id);
  await assert.rejects(bobRows.getRow(input), (e:any)=>[401,403,404].includes(e.code));
  await assert.rejects(aliceRows.updateRow<any>({...input,data:{payload:"{}"}}),(e:any)=>[401,403,404].includes(e.code)); checked("row ownership denies guessed IDs and direct client writes");
  const increment = await invoke(clients[0],identities[0].id,`/v1/sync?cursor=${bootstrap.body.cursor}`);
  assert.equal(increment.status,200); assert.equal(increment.body.throughRevision,await store.revision()); assert.equal(increment.body.hasMore,false); checked("live signed cursor reads the committed change log");
  await writeFile(`${dir}/${process.env.SPROUT_EXPECT_WRITES === "true" ? "live-revalidated-consistency-results" : "live-consistency-results"}.json`,JSON.stringify(report,null,2));
}
main().catch((error:any)=>{process.stderr.write(`Live consistency proof failed at ${stage} (${error?.code ?? error?.name ?? "unknown"}, ${error?.type ?? "assertion"}).\n`);process.exitCode=1;}).finally(async()=>{await Promise.allSettled(closeSessions.map(close=>close()));});
