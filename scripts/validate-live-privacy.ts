/** Destructive only to a newly created synthetic staging identity. */
import { Account, Client, Permission, Query, Role, Storage, Users, Functions, ExecutionMethod } from "node-appwrite";
import { InputFile } from "node-appwrite/file";
import { randomBytes, randomUUID } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { AppwriteStore } from "../services/integrations/appwrite-store";
import { PrivacyLedger } from "../services/integrations/privacy-ledger";
import { eraseFirstParty } from "../services/integrations/privacy-erasure";
import { privacyHash } from "../services/domain/privacy";
import { kinds } from "../services/contracts";
import { schedule } from "../services/domain/jobs";
const endpoint="https://nyc.cloud.appwrite.io/v1",project="6af0f72200383d2f1084";
let stage="configuration";
async function main(){
 const directory=process.env.SPROUT_DEPLOYMENT_REPORT_DIR,key=process.env.SPROUT_TEST_SERVICE_KEY;
 assert.ok(directory && key);assert.equal(process.env.APPWRITE_FUNCTION_PROJECT_ID,project);
 const client=new Client().setEndpoint(endpoint).setProject(project).setKey(key);
 const users=new Users(client),storage=new Storage(client),ledger=new PrivacyLedger(key);
 let identity:any;
 const mode=process.argv[2];
 const path=`${directory}/${mode==="blocked" ? "privacy-blocked-identity" : "privacy-test-identity"}.json`;
 try{identity=JSON.parse(await readFile(path,"utf8"))}catch{
  assert.ok(mode==="seed" || mode==="blocked");const id=randomUUID();identity={id,email:`sprout-erasure-${id}@example.invalid`,password:"aA1!"+randomBytes(24).toString("base64url"),receipt:randomBytes(32).toString("base64url")};
  await writeFile(path,JSON.stringify(identity),{mode:0o600});
 }
 assert.ok(identity.email.startsWith("sprout-erasure-") && identity.email.endsWith("@example.invalid"));
 const store=new AppwriteStore(identity.id,key,true);
 const countRows=async(owner:string)=>{
  const counts:Record<string,number>={};for(const table of [...kinds,"provider_credentials","webhook_receipts","sync_heads","sync_events","mutation_receipts"]){const page=await store.tables.listRows({databaseId:store.database,tableId:table,queries:[Query.equal("owner",owner),Query.limit(1)]});counts[table]=page.total;}return counts;
 };
 if(mode==="blocked"){
  stage="synthetic deferred cleanup setup";
  assert.equal(await ledger.get(identity.id),null);
  const others=JSON.parse(await readFile(`${directory}/test-identities.json`,"utf8"));
  const before=await Promise.all(others.map((v:any)=>countRows(v.id)));
  try{await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identity.id,email:identity.email,password:identity.password,name:"Sprout Deferred Cleanup QA"})}catch(e:any){if(e.code!==409)throw e}
  const session=await fetch(`${endpoint}/account/sessions/email`,{method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json"},body:JSON.stringify({email:identity.email,password:identity.password})});assert.equal(session.status,201);
  const cookie=session.headers.getSetCookie().map(v=>v.split(";")[0]).join("; ");
  assert.ok((await users.listSessions({userId:identity.id})).total>=1);
  const acceptedAt=new Date().toISOString();
  await store.mutate("blocked-proof-setup","seed",async tx=>{
   await tx.put("transactions","deferred-proof",{id:"deferred-proof",amount:{minor:-99,currency:"USD"},date:"2026-11-09",merchant:"Synthetic cleanup proof",category:"Other",type:"expense",source:"manual",accountId:"cash",description:"",pending:false,excluded:false},0);
   await tx.put("connections","synthetic-dependency",{provider:"synthetic-proof",itemId:"synthetic-proof-"+identity.id,status:"cleanup_required"},0);
   await tx.put("privacy_jobs","current",{type:"delete",status:"queued",acceptedAt},0);
   return {seeded:true};
  });
  await ledger.accept(identity.id,privacyHash(identity.receipt),acceptedAt);
  const recover=async()=>{const r=await new Functions(client).createExecution({functionId:"sprout-privacy",async:false,method:ExecutionMethod.POST,body:JSON.stringify({owner:identity.id,recovery:true})});assert.equal(r.responseStatusCode,200);return JSON.parse(r.responseBody)};
  stage="cloud blocked cleanup";
  assert.equal((await recover()).status,"needs_attention");
  const pending=await ledger.get(identity.id);assert.equal(pending?.steps.accessRevoked,true);assert.equal(pending?.steps.financialRecordsRemoved,false);
  assert.equal((await users.get({userId:identity.id})).status,false);assert.equal((await users.listSessions({userId:identity.id})).total,0);
  assert.ok(await store.get("transactions","deferred-proof"));
  const access=await fetch(`${endpoint}/account`,{headers:{"x-appwrite-project":project,cookie}});assert.ok([401,403].includes(access.status));
  const normal=new AppwriteStore(identity.id,key);
  await assert.rejects(normal.assertWritable(),(e:any)=>e.code==="ACCOUNT_DELETING");
  stage="scoped operator recovery after synthetic dependency removal";
  await store.mutate("blocked-proof-clear","clear",async tx=>{await tx.remove("connections","synthetic-dependency",1);return{removed:true}});
  assert.equal((await recover()).status,"active_data_removed");
  assert.ok(Object.values(await countRows(identity.id)).every(n=>n===0));
  assert.deepEqual(await Promise.all(others.map((v:any)=>countRows(v.id))),before);
  await writeFile(`${directory}/live-blocked-privacy-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["cloud worker revokes access despite an external cleanup dependency","all existing sessions revoked and cookie access rejected","needed records retained while cleanup requires attention","new application work rejected","removing only the synthetic dependency allows private recovery to finish","unrelated synthetic accounts unchanged"],scope:"Simulated dependency; no external provider contacted"},null,2));
  process.stdout.write("Passed cloud deferred-cleanup access revocation and scoped recovery.\n");return;
 }
 if(process.argv[2]==="native"){
  stage="native erasure independent readback";
  const identities=JSON.parse(await readFile(`${directory}/native-privacy-identities.json`,"utf8"));
  for(const identity of identities){
   const progress=await ledger.get(identity.id);assert.equal(progress?.status,"active_data_removed");assert.ok(Object.values(progress!.steps).every(Boolean));
   assert.ok(Object.values(await countRows(identity.id)).every(n=>n===0));
   const account=await users.get({userId:identity.id});assert.equal(account.status,false);assert.equal(account.name,"");assert.equal(account.phone,"");assert.ok(account.email.startsWith("deleted-"));
   assert.equal((await users.listSessions({userId:identity.id})).total,0);
  }
  await writeFile(`${directory}/live-native-privacy-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["both native approvals reached active-data removal","financial and sync tables contain no rows for either identity","both identities anonymized and disabled","all sessions revoked","receipt status survives financial erasure"],scope:"First-party active data; disabled anonymous Auth reservations and privacy ledger retained"},null,2));
  process.stdout.write("Passed independent erasure readback for both native identities.\n");return;
 }
 if(process.argv[2]==="seed"){
  stage="synthetic identity";
  try{await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identity.id,email:identity.email,password:identity.password,name:"Sprout Erasure QA"})}catch(error:any){if(error.code!==409)throw error}
  assert.equal(await ledger.get(identity.id),null);
  await store.mutate("privacy-proof-transaction","seed",tx=>tx.put("transactions","privacy-proof",{id:"privacy-proof",amount:{minor:-123,currency:"USD"},date:"2026-11-09",merchant:"Synthetic erasure proof",category:"Other",type:"expense",source:"manual",accountId:"cash",description:"",pending:false,excluded:false},0));
  const fileId=privacyHash(`privacy-proof:${identity.id}`).slice(0,36);
  try{await storage.createFile({bucketId:"sprout-private",fileId,file:InputFile.fromPlainText('{"synthetic":true}',"privacy-proof.json"),permissions:[Permission.read(Role.user(identity.id))]})}catch(error:any){if(error.code!==409)throw error}
  await writeFile(`${directory}/privacy-seeded.json`,JSON.stringify({project,status:"seeded",checkedAt:new Date().toISOString(),fileId,counts:await countRows(identity.id)}));
  process.stdout.write("Seeded a dedicated synthetic identity and private attachment for erasure and backup recovery proof.\n");return;
 }
 assert.equal(process.argv[2],"erase");stage="before-state isolation";
 const otherIdentities=JSON.parse(await readFile(`${directory}/test-identities.json`,"utf8"));
 const before=await Promise.all(otherIdentities.map((v:any)=>countRows(v.id)));
 const acceptedAt=new Date().toISOString();const receiptHash=privacyHash(identity.receipt);
 if(!await ledger.get(identity.id)){
  await store.mutate("privacy-proof-accept","delete",async tx=>{
   await tx.put("privacy_jobs","current",{type:"delete",status:"queued",acceptedAt});
   return schedule(tx,"privacy.delete","privacy-proof",{receiptHash,acceptedAt});
  });
  await ledger.accept(identity.id,receiptHash,acceptedAt);
 }
 stage="first-party erasure";
 const result=await eraseFirstParty(store,key,undefined,undefined,(error:any)=>process.stdout.write(`Privacy effect diagnostic: ${error.code ?? error.name}, ${error.type ?? "application"}\n`));
 if(result.status!=="active_data_removed")process.stdout.write(JSON.stringify(await ledger.get(identity.id))+"\n");
 assert.equal(result.status,"active_data_removed");
 stage="independent readback";
 const counts=await countRows(identity.id);assert.ok(Object.values(counts).every(n=>n===0));
 const fileId=privacyHash(`privacy-proof:${identity.id}`).slice(0,36);
 await assert.rejects(storage.getFile({bucketId:"sprout-private",fileId}),(e:any)=>e.code===404);
 const account=await users.get({userId:identity.id});assert.equal(account.status,false);assert.equal(account.name,"");assert.equal(account.phone,"");assert.ok(account.email.startsWith("deleted-") && account.email.endsWith("@example.invalid"));
 assert.deepEqual(account.prefs,{sproutDeleted:true});assert.equal((await users.listSessions({userId:identity.id})).total,0);
 await assert.rejects(new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identity.id,email:identity.email,password:identity.password}),(e:any)=>e.code===409);
 await assert.rejects(store.mutate("late-writer","blocked",tx=>tx.put("transactions","late",{},0)),(e:any)=>e.code==="ACCOUNT_DELETING");assert.ok(Object.values(await countRows(identity.id)).every(n=>n===0));
 assert.deepEqual(await Promise.all(otherIdentities.map((v:any)=>countRows(v.id))),before);
 assert.equal((await ledger.status(receiptHash)).status,"active_data_removed");
 await assert.rejects(ledger.status(privacyHash(randomBytes(32).toString("base64url"))),(e:any)=>e.code==="NOT_FOUND");
 const report={project,checkedAt:new Date().toISOString(),status:"passed",scope:"First-party active data; minimal disabled Auth ID and privacy ledger retained",tests:["canonical and sync records removed","private attachment removed","identity anonymized and access revoked","old Auth ID cannot be registered again","late writer rejected without recreating a sync head","unrelated synthetic accounts unchanged","private receipt progress survives financial erasure"]};
 await writeFile(`${directory}/live-privacy-results.json`,JSON.stringify(report,null,2));process.stdout.write("Passed first-party erasure, non-resurrection and unrelated-account readback.\n");
}
main().catch((error:any)=>{const columns=["provider_reference","owner","entity_id","version","updated_at","deleted","payload","state","due_at","lease_until"].filter(c=>String(error.message??"").includes(c)); if(columns.length)process.stderr.write(`Schema diagnostic fields: ${columns.join(",")}\n`);process.stderr.write(`Privacy proof failed at ${stage} (${error.code ?? error.name}, ${error.type ?? "assertion"}).\n`);process.exitCode=1});
