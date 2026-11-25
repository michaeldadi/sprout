/** Operates only on the named isolated staging restoration, never live data. */
import {Account,Client,Query,TablesDB,Users} from "node-appwrite";
import {readFile,writeFile} from "node:fs/promises";
import assert from "node:assert/strict";
import {privacyHash} from "../services/domain/privacy";
import {rowId} from "../services/integrations/appwrite-store";
const project="6af0f72200383d2f1084",endpoint="https://nyc.cloud.appwrite.io/v1",database="sprout-recovery-20261109";
let stage="configuration";
async function main(){
 const dir=process.env.SPROUT_DEPLOYMENT_REPORT_DIR,key=process.env.SPROUT_TEST_SERVICE_KEY;assert.ok(dir&&key);assert.equal(process.env.APPWRITE_FUNCTION_PROJECT_ID,project);
 const client=new Client().setEndpoint(endpoint).setProject(project).setKey(key),tables=new TablesDB(client),users=new Users(client);
 const identity=JSON.parse(await readFile(`${dir}/privacy-test-identity.json`,"utf8"));
 const others=JSON.parse(await readFile(`${dir}/test-identities.json`,"utf8"));
 stage="restored evidence";
 const restored=await tables.getRow({databaseId:database,tableId:"transactions",rowId:rowId(identity.id,"transactions","privacy-proof")});assert.equal(restored.owner,identity.id);
 assert.equal((await users.get({userId:identity.id})).status,false);
 const publicClient=new Client().setEndpoint(endpoint).setProject(project);
 await assert.rejects(new TablesDB(publicClient).getRow({databaseId:database,tableId:"transactions",rowId:restored.$id}),(e:any)=>[401,403,404].includes(e.code));
 await assert.rejects(new Account(publicClient).create({userId:identity.id,email:identity.email,password:identity.password}),(e:any)=>e.code===409);
 stage="quarantine";
 const page=await tables.listTables({databaseId:database,queries:[Query.limit(100)]});assert.ok(page.tables.length>20);
 for(const table of page.tables)await tables.updateTable({databaseId:database,tableId:table.$id,name:table.name,enabled:false,rowSecurity:true,permissions:[]});
 const counts=async(owner:string)=>Promise.all(page.tables.filter(t=>t.$id!=="marketing_waitlist_v1"&&t.$id!=="marketing_inquiries_v1").map(async table=>{
  const column=table.$id==="manual_transactions_v1"?"owner_id":"owner";
  return [table.$id,(await tables.listRows({databaseId:database,tableId:table.$id,queries:[Query.equal(column,owner),Query.limit(1)]})).total] as const;
 }));
 const before=await Promise.all(others.map((u:any)=>counts(u.id)));
 stage="deletion ledger filtering";
 const deleted=await tables.listRows({databaseId:"sprout-privacy",tableId:"deletion_ledger",queries:[Query.limit(100)]});assert.ok(deleted.rows.some(r=>r.owner_hash===privacyHash(`${project}:${identity.id}`)));
 assert.ok(deleted.rows.length<100,"The recovery validator must paginate a larger deletion ledger");
 for(const record of deleted.rows){
  const owner=String(record.owner_id);assert.equal(record.owner_hash,privacyHash(`${project}:${owner}`));
  for(const table of page.tables.filter(t=>!t.$id.startsWith("marketing_"))){const column=table.$id==="manual_transactions_v1"?"owner_id":"owner";
   for(;;){const rows=await tables.listRows({databaseId:database,tableId:table.$id,queries:[Query.equal(column,owner),Query.limit(100)]});if(!rows.rows.length)break;for(const row of rows.rows){assert.equal(row[column],owner);await tables.deleteRow({databaseId:database,tableId:table.$id,rowId:row.$id})}}
  }
 }
 assert.ok((await counts(identity.id)).every(([,n])=>n===0));assert.deepEqual(await Promise.all(others.map((u:any)=>counts(u.id))),before);
 const isolated=await tables.listTables({databaseId:database,queries:[Query.limit(100)]});assert.ok(isolated.tables.every(t=>!t.enabled&&t.$permissions.length===0&&t.rowSecurity));
 await assert.rejects(tables.getRow({databaseId:"6af0f7c600244c241e44",tableId:"transactions",rowId:restored.$id}),(e:any)=>e.code===404);
 const report={project,database,checkedAt:new Date().toISOString(),status:"passed",tests:["restored snapshot contains the pre-erasure synthetic fact","disabled Auth reservation survives financial restoration","account ID reuse rejected","anonymous restored-row access denied","all restored tables quarantined","independent deletion ledger filters restored rows","unrelated synthetic accounts preserved","live source database remains erased"],promotion:"Restored database remains disabled and is not connected to either app."};
 await writeFile(`${dir}/live-restore-results.json`,JSON.stringify(report,null,2));process.stdout.write("Passed isolated restoration, deletion-ledger filtering and unchanged-source verification.\n");
}
main().catch((e:any)=>{process.stderr.write(`Restore proof failed at ${stage} (${e.code??e.name}, ${e.type??"assertion"}).\n`);process.exitCode=1});
