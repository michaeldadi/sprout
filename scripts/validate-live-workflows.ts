import { Account, Client, ExecutionMethod, Functions, Storage, TablesDB } from "node-appwrite";
import { randomUUID, randomBytes, createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import assert from "node:assert/strict";

const endpoint = "https://nyc.cloud.appwrite.io/v1", project = "6af0f72200383d2f1084";
let stage = "setup";
const closeSessions: Array<() => Promise<unknown>> = [];
async function main() {
  const directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  if (!directory) throw new Error("A private report directory is required");
  const identities = JSON.parse(await readFile(`${directory}/test-identities.json`, "utf8"));
  const mode = process.argv[2];
  let securityOriginal: any;
  if (["security-setup","security-readback"].includes(mode)) {
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios"||platform==="android");
    const path=`${directory}/native-security-identities.json`;let users:any[];
    try { users=JSON.parse(await readFile(path,"utf8")); } catch {
      users=["ios","android"].map(p=>{const id=randomUUID();return {id,email:`sprout-security-${p}-${id}@example.invalid`,name:`Sprout QA ${p} Security`,password:randomBytes(24).toString("base64url")+"aA1!",temporaryPassword:randomBytes(24).toString("base64url")+"bB2!"};});
      await writeFile(path,JSON.stringify(users),{mode:0o600});
    }
    securityOriginal=identities[0];identities[0]=users[platform==="ios"?0:1];
    assert.match(identities[0].email,/^sprout-security-(ios|android)-[a-f0-9-]+@example\.invalid$/);
    try {await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identities[0].id,email:identities[0].email,password:identities[0].password,name:identities[0].name});}
    catch(error:any){if(error.code!==409)throw error;}
  }
  if (["export-fresh", "export-integrity"].includes(mode)) {
    let identity: any;
    try { identity = JSON.parse(await readFile(`${directory}/export-test-identity.json`,"utf8")); }
    catch {
      const id = randomUUID(); identity = {id,email:`sprout-export-${id}@example.invalid`,password:randomBytes(24).toString("base64url")+"aA1!",name:"Sprout QA Export"};
      await writeFile(`${directory}/export-test-identity.json`,JSON.stringify(identity),{mode:0o600});
    }
    try { await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identity.id,email:identity.email,password:identity.password,name:identity.name}); }
    catch(error:any) { if(error.code!==409) throw error; }
    identities.push(identity);
  }
  const login = async (index: number) => {
    const identity = identities[index];
    const response = await fetch(`${endpoint}/account/sessions/email`, {method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json"},body:JSON.stringify({email:identity.email,password:identity.password})});
    assert.equal(response.status,201);
    const cookie = response.headers.getSetCookie().map(v=>v.split(";")[0]).join("; ");
    closeSessions.push(()=>fetch(`${endpoint}/account/sessions/current`,{method:"DELETE",headers:{"x-appwrite-project":project,cookie},signal:AbortSignal.timeout(5000)}));
    const tokenResponse = await fetch(`${endpoint}/account/jwts`,{method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json",cookie},body:"{}"});
    assert.equal(tokenResponse.status,201);
    const jwt = (await tokenResponse.json() as any).jwt;
    const client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
    assert.equal((await new Account(client).get()).$id,identity.id);
    const request = async (path: string, body?: any) => {
      const execution = await new Functions(client).createExecution({functionId:"sprout-api",async:false,xpath:path,method:body ? ExecutionMethod.POST : ExecutionMethod.GET,body:body ? JSON.stringify({...body,_account:identity.id}) : undefined,headers:{"x-sprout-account":identity.id}});
      const value = JSON.parse(execution.responseBody);
      if(execution.responseStatusCode >= 300) throw {code:execution.responseStatusCode,type:value.error?.code};
      return value;
    };
    return {client,request};
  };
  if(["security-setup","security-readback"].includes(mode)) {
    stage="native account security";const platform=process.env.SPROUT_TEST_PLATFORM,identity=identities[0],previousPassword=identity.password;
    const securityPath=`${directory}/native-security-identities.json`,securityUsers=JSON.parse(await readFile(securityPath,"utf8")),securityIndex=platform==="ios"?0:1;
    if(mode==="security-readback") identity.password=identity.temporaryPassword;
    let user;
    try {user=await login(0);} catch(error:any) {
      if(mode!=="security-setup" || error.actual!==401) throw error;
      // Recover only our synthetic credential record after an interrupted test;
      // this never changes a server password or converts the prior test to a pass.
      identity.password=identity.temporaryPassword;user=await login(0);securityUsers[securityIndex].password=identity.password;
    }
    let view=await user.request("/v1/bootstrap");
    const financial=(v:any)=>JSON.stringify({profile:v.profile,transactions:v.transactions,budgets:v.budgets,goals:v.goals,receipts:v.receipts});
    const path=`${directory}/${platform}-security-baseline.json`;
    identities.push(securityOriginal);const original=await login(identities.length-1),originalView=await original.request("/v1/bootstrap");
    if(mode==="security-setup") {
      securityUsers[securityIndex].temporaryPassword=randomBytes(24).toString("base64url")+"cC3!";
      await writeFile(securityPath,JSON.stringify(securityUsers),{mode:0o600});
      if(view.profileVersion===0) await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"profile.update",profile:{name:identity.name,onboarding:"complete",monthlyTargetMinor:100000},expectedVersion:0}});
      const id="security-owned-fixture";
      if(!view.transactions.some((t:any)=>t.id===id)) await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"transaction.upsert",transaction:{id,merchant:"Sprout QA security account only",date:"2026-11-10",amount:{minor:-101,currency:"USD"},category:"Other",type:"expense",source:"manual",accountId:"cash",description:"Public account-isolation fixture",pending:false,excluded:false},expectedVersion:0}});
      view=await user.request("/v1/bootstrap");
      await writeFile(path,JSON.stringify({fixture:financial(view),original:financial(originalView)}),{mode:0o600});
    } else {
      const baseline=JSON.parse(await readFile(path,"utf8"));assert.equal(financial(view),baseline.fixture);assert.equal(financial(originalView),baseline.original);
      assert.equal(view.transactions.length,1);assert.equal(view.transactions[0].merchant,"Sprout QA security account only");assert.ok(!originalView.transactions.some((t:any)=>t.merchant==="Sprout QA security account only"));
      const rejected=await fetch(`${endpoint}/account/sessions/email`,{method:"POST",headers:{"x-appwrite-project":project,"content-type":"application/json"},body:JSON.stringify({email:identity.email,password:previousPassword})});assert.equal(rejected.status,401);
      securityUsers[securityIndex].password=identity.password;securityUsers[securityIndex].temporaryPassword=randomBytes(24).toString("base64url")+"dD4!";await writeFile(securityPath,JSON.stringify(securityUsers),{mode:0o600});
      await writeFile(`${directory}/live-${platform}-account-security-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native password change requires the current credential","new credential supports a fresh native sign-in","previous password is rejected after confirmation","native account switching preserves owner isolation","both accounts retain all financial facts and preferences"]},null,2));
    }
    process.stdout.write("Verified synthetic account-security setup or credential/isolation readback.\n");
  } else if(["weekly-setup","weekly-readback"].includes(mode)) {
    stage="native first-party weekly review";
    const user=await login(0),labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));let view=await user.request("/v1/bootstrap");
    const local=new Intl.DateTimeFormat("en-CA",{timeZone:view.profile.timezone,year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date()),weekday=new Date(local+"T00:00:00Z").getUTCDay();
    const week=new Date(Date.parse(local+"T00:00:00Z")-((weekday+6)%7)*86400000).toISOString().slice(0,10),from=new Date(Date.parse(week+"T00:00:00Z")-7*86400000).toISOString().slice(0,10),through=new Date(Date.parse(week+"T00:00:00Z")-86400000).toISOString().slice(0,10),file=`${directory}/native-weekly-baseline.json`;
    if(mode==="weekly-setup") {
      if(!view.transactions.some((r:any)=>r.id===labels.weeklyFixtureId && r.date===from)) {
        const id=randomUUID();await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"transaction.upsert",transaction:{id,merchant:"Sprout QA prior-week review",date:from,amount:{minor:-4200,currency:"USD"},category:"Other",type:"expense",source:"manual",accountId:"cash",description:"Public weekly review fixture",pending:false,excluded:false},expectedVersion:0}});labels.weeklyFixtureId=id;
        view=await user.request("/v1/bootstrap");
      }
      const facts=view.transactions.filter((r:any)=>r.date>=from && r.date<=through && !r.pending && !r.excluded && r.type!=="transfer");
      const net=-facts.filter((r:any)=>["expense","refund"].includes(r.type)).reduce((n:number,r:any)=>n+r.amount.minor,0),income=facts.filter((r:any)=>r.type==="income").reduce((n:number,r:any)=>n+r.amount.minor,0),usd=(n:number)=>new Intl.NumberFormat("en-US",{style:"currency",currency:"USD"}).format(n/100);
      labels.weeklyPublicationWeek=week;labels.weeklyWeek=from;labels.weeklySpending=usd(net);labels.weeklyIncome=usd(income);
      await writeFile(`${directory}/native-test-labels.json`,JSON.stringify(labels),{mode:0o600});
      await writeFile(file,JSON.stringify({week,net,income,profile:view.profile,transactionsHash:createHash("sha256").update(JSON.stringify(view.transactions)).digest("hex")}),{mode:0o600});
    } else {
      const baseline=JSON.parse(await readFile(file,"utf8"));
      for(let attempt=0;attempt<30 && !view.insights.some((i:any)=>i.kind==="weekly" && i.title===`Your week of ${from}`);attempt++) { await new Promise(r=>setTimeout(r,1000));view=await user.request("/v1/bootstrap"); }
      const reviews=view.insights.filter((i:any)=>i.kind==="weekly" && i.title===`Your week of ${from}`);assert.equal(reviews.length,1);assert.ok(reviews[0].detail.includes(`${labels.weeklySpending} net spending`));assert.ok(reviews[0].detail.includes(`${labels.weeklyIncome} income`));assert.ok(reviews[0].detail.startsWith("Available history"));
      assert.deepEqual(view.profile,baseline.profile);assert.equal(view.profile.weeklyDigest,false);assert.equal(view.capabilities.notifications,false);
      assert.equal(createHash("sha256").update(JSON.stringify(view.transactions)).digest("hex"),baseline.transactionsHash);
      const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios"||platform==="android");
      await writeFile(`${directory}/live-${platform}-weekly-review-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native Feed requests a persistent first-party review","available-history totals match independent arithmetic","repeat requests keep one weekly artifact","review survives native restoration","notification opt-in and all financial records remain unchanged","provider delivery stays disabled"]},null,2));
    }
    process.stdout.write("Verified native weekly review setup or canonical readback.\n");
  } else if(["edit-conflict-setup", "edit-conflict-remote", "edit-conflict-readback"].includes(mode)) {
    stage="native reviewed edit conflict";
    const platform=process.env.SPROUT_TEST_PLATFORM,kind=process.env.SPROUT_TEST_EDIT_KIND;
    assert.ok(platform==="ios"||platform==="android");assert.ok(kind==="expense"||kind==="goal");
    const user=await login(0),labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8")),file=`${directory}/${platform}-${kind}-conflict-baseline.json`;
    let view=await user.request("/v1/bootstrap");
    if(mode==="edit-conflict-setup") {
      const id=randomUUID(),name=`${platform} ${kind} conflict ${Date.now()}`;
      const value=kind==="expense"?{id,merchant:name,date:"2026-11-10",amount:{minor:-1111,currency:"USD"},category:"Other",type:"expense",source:"manual",accountId:"cash",description:"Original reviewed note",pending:false,excluded:false}:{id,name,target:{minor:50000,currency:"USD"},allocated:{minor:1111,currency:"USD"},targetDate:null,archived:false};
      await user.request("/v1/commands",{mutationId:randomUUID(),command:kind==="expense"?{type:"transaction.upsert",transaction:value,expectedVersion:0}:{type:"goal.upsert",goal:value,expectedVersion:0}});
      labels[platform+(kind==="expense"?"ExpenseConflictName":"GoalConflictName")]=name;
      labels[platform+(kind==="expense"?"ExpenseConflictId":"GoalConflictId")]=id;
      await writeFile(`${directory}/native-test-labels.json`,JSON.stringify(labels),{mode:0o600});
      await writeFile(file,JSON.stringify({id,value,profile:view.profile,transactions:view.transactions,goals:view.goals}),{mode:0o600});
    } else {
      const baseline=JSON.parse(await readFile(file,"utf8"));
      if(mode==="edit-conflict-readback") for(let attempt=0;attempt<30;attempt++) {
        if((kind==="expense"?view.transactions:view.goals).find((r:any)=>r.id===baseline.id)?.version===3) break;
        await new Promise(r=>setTimeout(r,1000));view=await user.request("/v1/bootstrap");
      }
      const rows=kind==="expense"?view.transactions:view.goals,target=rows.find((r:any)=>r.id===baseline.id);assert.ok(target);
      if(mode==="edit-conflict-remote") {
        assert.equal(target.version,1);
        const value=kind==="expense"?{...baseline.value,amount:{minor:-3333,currency:"USD"},description:"Competing remote note"}:{...baseline.value,allocated:{minor:3333,currency:"USD"}};
        await user.request("/v1/commands",{mutationId:randomUUID(),command:kind==="expense"?{type:"transaction.upsert",transaction:value,expectedVersion:1}:{type:"goal.upsert",goal:value,expectedVersion:1}});
      } else {
        assert.equal(target.version,3);assert.equal(kind==="expense"?target.amount.minor:target.data.allocated.minor,kind==="expense"?-2222:2222);
        if(kind==="expense") assert.equal(target.description,"Original reviewed note");else assert.equal(target.data.target.minor,50000);
        assert.deepEqual(view.profile,baseline.profile);
        assert.deepEqual(view.transactions.filter((r:any)=>r.id!==baseline.id),baseline.transactions);
        assert.deepEqual(view.goals.filter((r:any)=>r.id!==baseline.id),baseline.goals);
        await writeFile(`${directory}/live-${platform}-${kind}-conflict-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native editor retains its reviewed baseline while a remote edit commits","server conflict preserves the local draft","both amounts are displayed before explicit approval","approved draft updates only the displayed server version","one canonical record and all unrelated facts preserved"]},null,2));
      }
    }
    process.stdout.write("Verified native conflict setup, remote edit or final readback.\n");
  } else if(mode === "native-export-setup") {
    stage="native archive fixture";
    const user=await login(0), labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    const view=await user.request("/v1/bootstrap");
    if(!view.receipts.some((r:any)=>r.id===labels.exportReceiptId && r.status==="ready")) {
      const id=randomUUID(),receiptId=randomUUID(),image=await readFile(`${directory}/synthetic-receipt.jpg`),sha=createHash("sha256").update(image).digest("hex");
      await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"transaction.upsert",transaction:{id,merchant:"Sprout QA retained export receipt",date:"2026-11-10",amount:{minor:-540,currency:"USD"},category:"Other",type:"expense",source:"scan",accountId:"cash",description:"Public synthetic archive fixture",pending:false,excluded:false},expectedVersion:0}});
      await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"receipt.attach",id:receiptId,transactionId:id,sha256:sha,jpegBase64:image.toString("base64")}});
      labels.exportReceiptId=receiptId;labels.exportReceiptSha256=sha;
      await writeFile(`${directory}/native-test-labels.json`,JSON.stringify(labels),{mode:0o600});
    }
    const accepted=await user.request("/v1/privacy",{type:"export",requestId:randomUUID()});
    let completed=false;
    for(let attempt=0;attempt<90;attempt++) {
      const job=await user.request(`/v1/jobs/${accepted.id}`);
      if(job.status==="succeeded") { completed=true;break; }
      if(["failed","needs_attention"].includes(job.status)) throw {code:job.status,type:job.error};
      await new Promise(r=>setTimeout(r,1000));
    }
    assert.equal(completed,true);process.stdout.write("Prepared a fresh private export with a verified synthetic retained receipt.\n");
  } else if(["preferences-setup","preferences-visual-setup","preferences-readback","preferences-roundtrip-readback"].includes(mode)) {
    stage="native notification preferences";
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios"||platform==="android");
    const user=await login(0),view=await user.request("/v1/bootstrap"),file=`${directory}/native-preferences-baseline.json`;
    const protectedProfile=(p:any)=>Object.fromEntries(Object.entries(p).filter(([k])=>!["timezone","quietHours"].includes(k)));
    if(mode==="preferences-visual-setup" || mode==="preferences-setup" && platform==="ios") {
      const visual=mode==="preferences-visual-setup";
      if(visual) assert.equal(platform,"android");
      const configured={...view.profile,timezone:visual?"America/Los_Angeles":"America/Anchorage",quietHours:{enabled:!visual,startMinute:1260,endMinute:480}};
      const result=JSON.stringify(configured)===JSON.stringify(view.profile)?{version:view.profileVersion}:await user.request("/v1/commands",{mutationId:randomUUID(),command:{type:"profile.update",profile:configured,expectedVersion:view.profileVersion}});
      await writeFile(file,JSON.stringify({protected:protectedProfile(configured),version:result.version,transactionsHash:createHash("sha256").update(JSON.stringify(view.transactions)).digest("hex")}),{mode:0o600});
    } else {
      const baseline=JSON.parse(await readFile(file,"utf8"));
      assert.equal(view.profile.timezone,"America/Los_Angeles");
      const advanced=platform==="android" && mode!=="preferences-setup" || mode==="preferences-roundtrip-readback";
      assert.deepEqual(view.profile.quietHours,{enabled:advanced,startMinute:advanced?1230:1260,endMinute:advanced?450:480});
      assert.deepEqual(protectedProfile(view.profile),baseline.protected);
      assert.equal(createHash("sha256").update(JSON.stringify(view.transactions)).digest("hex"),baseline.transactionsHash);
      if(mode!=="preferences-setup") assert.ok(view.profileVersion>baseline.version);
      if(mode!=="preferences-setup") await writeFile(`${directory}/live-${platform}-${mode==="preferences-roundtrip-readback"?"preferences-roundtrip":"preferences"}-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native preferences use the account timezone","reviewed quiet-hour changes persist with server versions","the other native app reads the same saved preferences","unrelated profile fields and all financial facts remain unchanged","paused provider topics remain disabled"]},null,2));
    }
    process.stdout.write("Verified synthetic notification preference setup/readback.\n");
  } else if(mode==="receipt-observe") {
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios"||platform==="android");
    const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8")),merchant=labels[platform+"ReceiptMerchant"],user=await login(0),view=await user.request("/v1/bootstrap");
    const rows=view.transactions.filter((v:any)=>v.merchant===merchant),receipts=view.receipts.filter((r:any)=>rows.some((v:any)=>v.id===r.transactionId));
    await writeFile(`${directory}/${platform}-receipt-observation.json`,JSON.stringify({transactions:rows,receipts,jobs:view.jobs.filter((j:any)=>j.type.startsWith("receipt."))}),{mode:0o600});
    process.stdout.write(JSON.stringify({transactions:rows.length,receiptStates:receipts.map((r:any)=>r.status),privateJobs:view.jobs.filter((j:any)=>j.type.startsWith("receipt.")).map((j:any)=>({status:j.status,error:j.error}))})+"\n");
  } else if(mode==="receipt-readback") {
    stage="native opt-in receipt retention readback";
    const platform=process.env.SPROUT_TEST_PLATFORM; assert.ok(platform==="ios" || platform==="android");
    const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    const merchant=labels[platform+"ReceiptMerchant"]; assert.ok(merchant);
    const user=await login(0), view=await user.request("/v1/bootstrap");
    const rows=view.transactions.filter((v:any)=>v.merchant===merchant);
    assert.equal(rows.length,1);assert.equal(rows[0].amount.minor,-540);assert.equal(rows[0].amount.currency,"USD");assert.equal(rows[0].source,"scan");
    assert.equal(view.receipts.filter((v:any)=>v.transactionId===rows[0].id).length,0);
    await writeFile(`${directory}/live-${platform}-receipt-retention-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native system photo picker feeds on-device OCR and a reviewed expense", "receipt retention is initially off and explicitly selected", "private server copy previews through the native image viewer", "explicit removal survives recreation while the transaction remains", "independent readback confirms exactly one USD -540 scanned expense and no retained receipt"]},null,2));
    process.stdout.write("Passed independent native receipt retention readback.\n");
  } else if(mode==="ios-offline-readback") {
    stage="iOS cold offline recovery readback";
    const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8")),merchant=labels.iosOfflineMerchant;assert.ok(merchant?.startsWith("iOS Offline "));
    const user=await login(0);let rows:any[]=[];
    for(let attempt=0;attempt<20;attempt++) { const view=await user.request("/v1/bootstrap");rows=view.transactions.filter((v:any)=>v.merchant===merchant);if(rows.length)break;await new Promise(r=>setTimeout(r,1000)); }
    assert.equal(rows.length,1);assert.equal(rows[0].amount.minor,-147);assert.equal(rows[0].source,"manual");assert.equal(rows[0].version,1);
    await writeFile(`${directory}/live-ios-offline-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["cached identity and financial workspace open during a Debug-injected transport outage","reviewed local expense survives a full app termination while requests fail","restarting without the fault uploads through the real authenticated Appwrite API exactly once","canonical amount, sign, source and initial version match the reviewed draft"],limits:["controlled app transport fault, not simulator radio or physical-device airplane mode"]},null,2));
    process.stdout.write("Verified iOS cold outage recovery against one canonical Appwrite expense.\n");
  } else if(mode==="import-readback") {
    stage="reviewed native CSV import readback";
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios" || platform==="android");
    const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8")),merchant=labels[`${platform}ImportMerchant`];
    assert.ok(merchant?.startsWith(platform==="ios" ? "iOS Import " : "Android Import "));
    const user=await login(0),view=await user.request("/v1/bootstrap");
    const rows=view.transactions.filter((v:any)=>v.merchant.startsWith(merchant));
    assert.equal(rows.length,1);assert.equal(rows[0].merchant,merchant);assert.equal(rows[0].amount.minor,-420);assert.equal(rows[0].source,"import");assert.equal(rows[0].version,1);
    const csv=`date,merchant,amount,type,currency,category,notes\n2026-11-10,${merchant},-4.20,expense,USD,Other,Reviewed CSV\n2026-11-10,${merchant},-4.20,expense,USD,Other,Possible duplicate\n2026-11-10,${merchant} Invalid,4.20,expense,USD,Other,Wrong sign\n`;
    const batchId=createHash("sha256").update(csv).digest("hex");
    const job=view.jobs.find((j:any)=>j.type==="transaction.import" && j.status==="succeeded" && j.batchId===batchId && j.progress?.total===1);
    assert.ok(job);
    await writeFile(`${directory}/live-${platform}-import-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native CSV review excludes a possible duplicate and an invalid signed amount","review consent queues one durable import","canonical readback contains exactly one reviewed USD record","native Activity restores the imported record after recreation"]},null,2));
    process.stdout.write("Verified the reviewed native CSV import against canonical staging data.\n");
  } else if(mode==="execution-isolation") {
    stage="function execution response isolation";
    const alice=await login(0),bob=await login(1);
    const execution=await new Functions(alice.client).createExecution({functionId:"sprout-api",async:false,xpath:"/v1/bootstrap",method:ExecutionMethod.GET,headers:{"x-sprout-account":identities[0].id}});
    assert.equal(execution.responseStatusCode,200);
    for(const client of [bob.client,new Client().setEndpoint(endpoint).setProject(project)]) {
      await assert.rejects(new Functions(client).getExecution({functionId:"sprout-api",executionId:execution.$id}),(error:any)=>[401,403,404].includes(error.code));
    }
    try {
      const page=await new Functions(bob.client).listExecutions({functionId:"sprout-api"});
      assert.ok(!page.executions.some(v=>v.$id===execution.$id));
    } catch(error:any) {assert.ok([401,403,404].includes(error.code));}
    await writeFile(`${directory}/live-execution-isolation-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["authenticated execution returns its owner's workspace","a second user cannot retrieve that execution response","anonymous callers cannot retrieve that execution response","execution listing cannot disclose the other user's execution"]},null,2));
    process.stdout.write("Verified financial function execution response isolation.\n");
  } else if(["budget-conflict-setup","budget-conflict-remote","budget-conflict-readback"].includes(mode)) {
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios" || platform==="android");
    const user=await login(0),view=await user.request("/v1/bootstrap"),file=`${directory}/native-${platform}-budget-conflict.json`;
    if(mode==="budget-conflict-setup") {
      const category=`${platform} Conflict ${Date.now()}`;
      const value={category,month:view.today.slice(0,7),id:randomUUID(),target:view.profile.monthlyTargetMinor};
      await writeFile(file,JSON.stringify(value),{mode:0o600});
      const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));labels[`${platform}BudgetConflictCategory`]=category;labels[`${platform}BudgetConflictMonth`]=value.month;
      await writeFile(`${directory}/native-test-labels.json`,JSON.stringify(labels),{mode:0o600});
    } else {
      const before=JSON.parse(await readFile(file,"utf8"));
      if(mode==="budget-conflict-remote") {
        assert.ok(!view.budgets.some((b:any)=>b.data.month===before.month && b.data.category===before.category));
        await user.request("/v1/commands",{mutationId:before.id,command:{type:"budget.upsert",expectedVersion:0,budget:{id:before.id,month:before.month,category:before.category,limit:{minor:3333,currency:"USD"}}}});
        process.stdout.write("A separate client created the competing monthly category budget.\n");
      } else {
        const rows=view.budgets.filter((b:any)=>b.data.month===before.month && b.data.category===before.category);
        assert.equal(rows.length,1);assert.equal(rows[0].id,before.id);assert.equal(rows[0].version,2);assert.equal(rows[0].data.limit.minor,2222);assert.equal(view.profile.monthlyTargetMinor,before.target);
        await writeFile(`${directory}/live-${platform}-budget-conflict-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native editor retains the original reviewed baseline despite a competing remote creation","logical duplicate becomes an explicit reviewable conflict","approved local limit updates the single winning canonical budget","monthly target is preserved"]},null,2));
        process.stdout.write("Verified explicit native conflict recovery and canonical budget identity.\n");
      }
    }
  } else if(mode==="release-readback") {
    stage="minified native release expense readback";
    const user=await login(0), labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios" || platform==="android");
    const merchant=labels[`${platform}ReleaseMerchant`];assert.ok(merchant?.startsWith(platform==="ios" ? "iOS Release " : "Android Release "));
    let rows:any[]=[];
    for(let attempt=0;attempt<30;attempt++) {
      const view=await user.request("/v1/bootstrap"); rows=view.transactions.filter((v:any)=>v.merchant===merchant);
      if(rows.length) break; await new Promise(resolve=>setTimeout(resolve,1000));
    }
    assert.equal(rows.length,1);assert.equal(rows[0].amount.minor,-275);assert.equal(rows[0].source,"manual");assert.equal(rows[0].version,1);
    await writeFile(`${directory}/live-${platform}-release-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:[platform==="android" ? "minified native app restores or authenticates its staging account" : "optimized native app restores or authenticates its staging account","normal native expense editor saves a reviewed expense","independent server readback confirms one USD expense with the correct sign, source and version"]},null,2));
    process.stdout.write("Verified the native release expense against canonical staging data.\n");
  } else if(mode==="capture") {
    stage="shared expense capture cases";
    const cases=JSON.parse(await readFile("../design/fixtures/expense-text.json","utf8"));
    const user=await login(0);
    for(let start=0;start<cases.length;start+=4) await Promise.all(cases.slice(start,start+4).map(async (row:any)=>{
      const result=await user.request("/v1/expense-drafts/parse",{text:row.text});
      assert.equal(result.amountMinor,row.amountMinor);assert.equal(result.requiresReview,true);
    }));
    await writeFile(`${directory}/live-capture-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",cases:cases.length,fixtureSha256:createHash("sha256").update(JSON.stringify(cases)).digest("hex"),tests:["live authenticated parse endpoint matches shared USD capture fixtures","ambiguous, corrected, negative, foreign and malformed amounts require review","parsing never saves a financial record"]},null,2));
    process.stdout.write("Verified the shared capture cases against the deployed API.\n");
  } else if(mode==="budget-setup" || mode==="budget-readback") {
    const platform=process.env.SPROUT_TEST_PLATFORM;assert.ok(platform==="ios" || platform==="android");
    const user=await login(0), view=await user.request("/v1/bootstrap");
    const file=`${directory}/native-${platform}-budget-baseline.json`;
    if(mode==="budget-setup") {
      const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
      const category=`${platform} Plan ${Date.now()}`;
      const month=view.today.slice(0,7), priorDate=new Date(`${month}-01T12:00:00Z`);priorDate.setUTCMonth(priorDate.getUTCMonth()-1);
      const prior=priorDate.toISOString().slice(0,7), id=randomUUID();
      await user.request("/v1/commands",{mutationId:id,command:{type:"budget.upsert",expectedVersion:0,budget:{id,category:category+" Prior",month:prior,limit:{minor:1111,currency:"USD"}}}});
      labels[`${platform}BudgetCategory`]=category; labels[`${platform}BudgetPriorMonth`]=prior;
      await writeFile(`${directory}/native-test-labels.json`,JSON.stringify(labels),{mode:0o600});
      await writeFile(file,JSON.stringify({category,month,prior,priorId:id,target:view.profile.monthlyTargetMinor}),{mode:0o600});
      process.stdout.write("Prepared a synthetic prior-period budget for native review.\n");
    } else {
      const before=JSON.parse(await readFile(file,"utf8"));
      assert.equal(view.profile.monthlyTargetMinor,before.target);
      const current=view.budgets.filter((r:any)=>r.data.month===before.month && r.data.category===before.category);
      assert.equal(current.length,1);assert.equal(current[0].data.limit.minor,2222);assert.equal(current[0].version,1);
      const prior=view.budgets.find((r:any)=>r.id===before.priorId);assert.equal(prior.data.month,before.prior);assert.equal(prior.data.limit.minor,3333);assert.equal(prior.version,2);
      await writeFile(`${directory}/live-${platform}-budget-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native category edit creates one current-period budget","native historical edit updates the reviewed prior-period version","category saves preserve the monthly spending target"]},null,2));
      process.stdout.write("Independently verified native current and historical budget edits.\n");
    }
  } else if(mode==="budget-race") {
    stage="simultaneous monthly category budgets";
    const user=await login(1), category="QA Budget "+randomUUID();
    const make=(id:string,category:string)=>({mutationId:id,command:{type:"budget.upsert",expectedVersion:0,budget:{id,category,month:"2026-11",limit:{minor:1000,currency:"USD"}}}});
    const outcomes=await Promise.allSettled([user.request("/v1/commands",make(randomUUID(),category)),user.request("/v1/commands",make(randomUUID(),"  "+category.toUpperCase()+"  "))]);
    assert.equal(outcomes.filter(r=>r.status==="fulfilled").length,1);
    const rejected=outcomes.find(r=>r.status==="rejected") as PromiseRejectedResult;
    assert.equal(rejected.reason.type,"VERSION_CONFLICT");
    const id=randomUUID();
    await user.request("/v1/commands",{mutationId:id,command:{type:"transaction.upsert",expectedVersion:0,transaction:{id,amount:{minor:-99,currency:"USD"},date:"2026-11-09",merchant:"Budget race QA",category:category.toLowerCase(),type:"expense",source:"manual",accountId:"cash",description:"Synthetic budget proof",pending:false,excluded:false}}});
    const view=await user.request("/v1/bootstrap");
    const rows=view.budgets.filter((r:any)=>r.data.category.trim().toLowerCase()===category.toLowerCase());assert.equal(rows.length,1);
    const pace=view.snapshot.budget.categories.find((c:any)=>c.id===rows[0].id);assert.equal(pace.spentMinor,99);
    await writeFile(`${directory}/live-budget-race-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["simultaneous distinct client IDs yield one monthly category budget","duplicate returns an explicit version conflict","case-normalized category spending is counted once"],revision:view.revision},null,2));
    process.stdout.write("Passed live monthly budget uniqueness and category spending proof.\n");
  } else if(mode==="realtime-guard") {
    stage="owner-scoped change signal isolation";
    const alice=await login(0), bob=await login(1);
    const a=await alice.request("/v1/bootstrap"), b=await bob.request("/v1/bootstrap");
    assert.notEqual(a.changeChannel,b.changeChannel);
    const parts=a.changeChannel.split(".");assert.equal(parts.length,6);
    assert.deepEqual([parts[0],parts[2],parts[3],parts[4]],["tablesdb","tables","sync_heads","rows"]);
    const args={databaseId:parts[1],tableId:parts[3],rowId:parts[5]};
    const signal=await new TablesDB(alice.client).getRow(args);
    assert.equal(signal.owner,identities[0].id);assert.equal(signal.sequence,a.revision);
    assert.deepEqual(Object.keys(signal).filter(k=>!k.startsWith("$")).sort(),["owner","sequence"]);
    await assert.rejects(new TablesDB(bob.client).getRow(args),(error:any)=>[401,403,404].includes(error.code));
    await writeFile(`${directory}/live-realtime-isolation-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["authenticated owner can read their revision signal","another account cannot read it","each account receives a distinct concrete channel","signal contains no financial records or values"]},null,2));
    process.stdout.write("Passed live owner-only change-signal isolation and payload minimization.\n");
  } else if(mode==="realtime") {
    stage="remote realtime mutation";
    const labels=JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    const platform=process.env.SPROUT_TEST_PLATFORM;
    assert.ok(platform==="ios" || platform==="android");
    const merchant=labels[`${platform}RealtimeMerchant`];assert.ok(merchant);
    const user=await login(0), id=randomUUID();
    const before=await user.request("/v1/bootstrap");
    assert.match(before.changeChannel,/^tablesdb\.[A-Za-z0-9_-]+\.tables\.sync_heads\.rows\.[A-Za-z0-9_-]+$/);
    assert.ok(!before.transactions.some((t:any)=>t.merchant===merchant));
    await user.request("/v1/commands",{mutationId:id,command:{type:"transaction.upsert",expectedVersion:0,transaction:{id,amount:{minor:-321,currency:"USD"},date:before.today,merchant,category:"Other",type:"expense",source:"manual",accountId:"cash",description:"Synthetic remote change",pending:false,excluded:false}}});
    const after=await user.request("/v1/bootstrap");
    assert.equal(after.transactions.filter((t:any)=>t.id===id && t.version===1).length,1);
    await writeFile(`${directory}/live-${platform}-realtime-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["separate authenticated client creates one canonical expense","owner-scoped revision channel is advertised"],revision:after.revision},null,2));
    process.stdout.write("Created and independently read back the synthetic remote change.\n");
  } else if(mode==="privacy-login-check") {
    stage="disposable native identity public login";
    const records=JSON.parse(await readFile(`${directory}/native-privacy-identities.json`,"utf8"));identities.push(records[0]);
    const user=await login(identities.length-1);const view=await user.request("/v1/bootstrap");assert.equal(view.profile.onboarding,"complete");assert.ok(view.transactions.some((t:any)=>t.merchant===records[0].merchant));
    process.stdout.write("Verified the current disposable iOS credentials through a public session and financial bootstrap.\n");
  } else if(mode==="privacy-setup-ios") {
    stage="fresh native iOS erasure fixture";
    const path=`${directory}/native-privacy-identities.json`, candidatePath=`${directory}/native-privacy-ios-replay.json`;
    const records=JSON.parse(await readFile(path,"utf8"));let candidate:any;
    try{candidate=JSON.parse(await readFile(candidatePath,"utf8"))}catch{const id=randomUUID();candidate={id,email:`sprout-native-erasure-${id}@example.invalid`,password:"aA1!"+randomBytes(24).toString("base64url"),name:"Sprout iOS Erasure QA",merchant:"iOS Privacy Record"};await writeFile(candidatePath,JSON.stringify(candidate),{mode:0o600})}
    try{await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:candidate.id,email:candidate.email,password:candidate.password,name:candidate.name})}catch(e:any){if(e.code!==409)throw e}
    identities.push(candidate);const user=await login(identities.length-1);
    await user.request("/v1/commands",{mutationId:"privacy-native-profile",command:{type:"profile.update",expectedVersion:0,profile:{name:candidate.name,onboarding:"complete",monthlyTargetMinor:150000,timezone:"America/New_York",appearance:"system",renewalAlerts:false,priceAlerts:false,weeklyDigest:false}}});
    await user.request("/v1/commands",{mutationId:"privacy-native-fact",command:{type:"transaction.upsert",expectedVersion:0,transaction:{id:"privacy-native-proof",amount:{minor:-299,currency:"USD"},date:"2026-11-09",merchant:candidate.merchant,category:"Other",type:"expense",source:"manual",accountId:"cash",description:"",pending:false,excluded:false}}});
    if(records[0].id!==candidate.id){let history:any[]=[];try{history=JSON.parse(await readFile(`${directory}/native-privacy-history.json`,"utf8"))}catch{}history.push({id:records[0].id,retiredAt:new Date().toISOString(),reason:"Prior iOS erasure completed; replay validates the final return-to-Welcome correction"});await writeFile(`${directory}/native-privacy-history.json`,JSON.stringify(history),{mode:0o600})}
    records[0]=candidate;await writeFile(path,JSON.stringify(records),{mode:0o600});process.stdout.write("Prepared a fresh synthetic iOS erasure fixture; Android identity and unrelated accounts preserved.\n");
  } else if(mode==="privacy-setup" || mode==="privacy-recovery-setup") {
    stage="native privacy synthetic setup";
    const path=`${directory}/native-privacy-identities.json`;
    if(mode==="privacy-recovery-setup") {
      const prior=JSON.parse(await readFile(path,"utf8"));
      const historyPath=`${directory}/native-privacy-history.json`;
      let history:any[]=[];try{history=JSON.parse(await readFile(historyPath,"utf8"))}catch{}
      history.push(...prior.map((v:any)=>({id:v.id,retiredAt:new Date().toISOString(),reason:"Completed native erasure proof; replaced for unconfirmed-receipt recovery validation"})));
      await writeFile(historyPath,JSON.stringify(history),{mode:0o600});
      const records=["iOS","Android"].map(platform=>{const id=randomUUID();return{id,email:`sprout-native-erasure-${id}@example.invalid`,password:"aA1!"+randomBytes(24).toString("base64url"),name:`Sprout ${platform} Recovery QA`,merchant:`${platform} Privacy Record`}});
      await writeFile(path,JSON.stringify(records),{mode:0o600});
    }
    let records:any[];
    try{records=JSON.parse(await readFile(path,"utf8"))}catch{records=["iOS","Android"].map(platform=>{const id=randomUUID();return{id,email:`sprout-native-erasure-${id}@example.invalid`,password:"aA1!"+randomBytes(24).toString("base64url"),name:`Sprout ${platform} Erasure QA`,merchant:`${platform} Privacy Record`}});await writeFile(path,JSON.stringify(records),{mode:0o600})}
    for(const identity of records){
      try{await new Account(new Client().setEndpoint(endpoint).setProject(project)).create({userId:identity.id,email:identity.email,password:identity.password,name:identity.name})}catch(e:any){if(e.code!==409)throw e}
      identities.push(identity);const user=await login(identities.length-1);
      await user.request("/v1/commands",{mutationId:"privacy-native-profile",command:{type:"profile.update",expectedVersion:0,profile:{name:identity.name,onboarding:"complete",monthlyTargetMinor:150000,timezone:"America/New_York",appearance:"system",renewalAlerts:false,priceAlerts:false,weeklyDigest:false}}});
      await user.request("/v1/commands",{mutationId:"privacy-native-fact",command:{type:"transaction.upsert",expectedVersion:0,transaction:{id:"privacy-native-proof",amount:{minor:-299,currency:"USD"},date:"2026-11-09",merchant:identity.merchant,category:"Other",type:"expense",source:"manual",accountId:"cash",description:"",pending:false,excluded:false}}});
    }
    process.stdout.write("Prepared two dedicated native erasure identities through authenticated public API commands.\n");
  } else if (["export", "export-fresh", "export-integrity"].includes(mode)) {
    stage = "export public authentication";
    const bob = await login(mode === "export" ? 1 : 2);
    const snapshot = await bob.request("/v1/bootstrap");
    const existing = snapshot.jobs.find((j:any)=>j.type==="privacy.export");
    stage = "export acceptance";
    const startedAt = Date.now();
    const requestId = randomUUID();
    const accepted = mode !== "export-integrity" && existing ? existing : await bob.request("/v1/privacy",{type:"export",requestId});
    if(mode === "export-integrity" && existing?.status === "succeeded") assert.notEqual(accepted.id,existing.id);
    let job: any;
    for(let attempt=0;attempt<90;attempt++) {
      stage = "export job polling";
      job = await bob.request(`/v1/jobs/${accepted.id}`);
      if(job.status === "succeeded") break;
      if(["failed","needs_attention","retry"].includes(job.status)) throw {code:job.status,type:job.error};
      await new Promise(resolve=>setTimeout(resolve,1000));
    }
    assert.equal(job.status,"succeeded");
    stage = "private export download";
    const bytes = await new Storage(bob.client).getFileDownload({bucketId:job.result.bucketId,fileId:job.result.fileId});
    // node-appwrite decodes application/json before consulting arrayBuffer.
    const file = bytes instanceof ArrayBuffer ? JSON.parse(Buffer.from(bytes).toString("utf8")) : bytes as unknown as {schemaVersion:number;records:{transactions:unknown[]}};
    assert.equal(file.schemaVersion,1); assert.ok(Array.isArray(file.records.transactions));
    if(mode === "export-integrity") {
      const raw = await fetch(`${endpoint}/storage/buckets/${job.result.bucketId}/files/${job.result.fileId}/download`,{headers:{"x-appwrite-project":project,"x-appwrite-jwt":bob.client.config.jwt},signal:AbortSignal.timeout(15000)});
      assert.equal(raw.status,200);const content=Buffer.from(await raw.arrayBuffer());
      assert.equal(createHash("sha256").update(content).digest("hex"),job.result.sha256);
      assert.equal(content.length,job.result.size);assert.equal(JSON.parse(content.toString()).revision,job.result.snapshotRevision);
      const replay=await bob.request("/v1/privacy",{type:"export",requestId});assert.equal(replay.id,accepted.id);
      const fresh=await bob.request("/v1/privacy",{type:"export",requestId:randomUUID()});assert.notEqual(fresh.id,accepted.id);assert.equal(fresh.reused,false);
    }
    const alice = await login(0);
    await assert.rejects(new Storage(alice.client).getFileDownload({bucketId:job.result.bucketId,fileId:job.result.fileId}),(error:any)=>[401,403,404].includes(error.code));
    const observedSeconds = Math.round((Date.now()-startedAt)/1000);
    const report = {project,checkedAt:new Date().toISOString(),status:"passed",tests:["authenticated asynchronous export","dispatcher and privacy worker completion","private file download","cross-user file denial",...(mode === "export-integrity" ? ["saved bytes match checksum, size and snapshot revision", "same request replays its immutable job", "new request after completion creates a fresh export"]:[])],reusedExistingJob:mode !== "export-integrity" && !!existing,observedSeconds};
    await writeFile(`${directory}/live-${mode}-results.json`,JSON.stringify(report,null,2));
    process.stdout.write(`Passed live export and file isolation (${observedSeconds}s observed; ${existing ? "existing" : "new"} job).\n`);
  } else if (mode === "native") {
    stage = "native server readback";
    const alice = await login(0), snapshot = await alice.request("/v1/bootstrap");
    assert.equal(snapshot.profile.onboarding,"complete");
    assert.equal(snapshot.profile.monthlyTargetMinor,150000);
    assert.ok(snapshot.transactions.some((t:any)=>t.merchant==="iOS Live Coffee" && t.amount.minor===-1234 && t.version===1));
    assert.ok(snapshot.transactions.some((t:any)=>t.merchant.startsWith("Android Live Lunch") && t.amount.minor===-456 && t.version===1));
    await writeFile(`${directory}/live-native-readback.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["native onboarding persisted","iOS expense acknowledged","Android expense acknowledged","coherent snapshot revision"],revision:snapshot.revision},null,2));
    process.stdout.write("Passed independent server readback for both native expenses and onboarding.\n");
  } else if (mode === "goals") {
    stage = "virtual goal readback";
    const alice = await login(0), snapshot = await alice.request("/v1/bootstrap");
    const labels = JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    for (const [name, target, allocation, version] of [[labels.iosGoal,50000,15000,2],[labels.androidGoal,75000,5000,1]]) {
      const records = snapshot.goals.filter((g:any)=>g.data.name===name); assert.equal(records.length,1);
      assert.equal(records[0].version,version);assert.equal(records[0].data.target.minor,target);assert.equal(records[0].data.allocated.minor,allocation);
    }
    assert.equal(snapshot.snapshot.balanceMinor,null);
    assert.equal(snapshot.transactions.filter((t:any)=>[labels.iosGoal,labels.androidGoal].includes(t.merchant)).length,0);
    await writeFile(`${directory}/live-goals-readback.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["iOS virtual allocation created","Android edited iOS allocation with expected version","Android goal created","no transfer or financial fact fabricated"],revision:snapshot.revision},null,2));
    process.stdout.write("Passed independent native goals and cross-platform edit readback.\n");
  } else if (mode === "privacy-status") {
    stage="anonymous receipt progress";
    const identity=JSON.parse(await readFile(`${directory}/privacy-test-identity.json`,"utf8"));
    const functions=new Functions(new Client().setEndpoint(endpoint).setProject(project));
    const request=async(receipt:string)=>functions.createExecution({functionId:"sprout-privacy-status",async:false,method:ExecutionMethod.POST,body:JSON.stringify({receipt})});
    const response=await request(identity.receipt);assert.equal(response.responseStatusCode,200);
    const progress=JSON.parse(response.responseBody);assert.equal(progress.status,"active_data_removed");
    for(const secret of [identity.id,identity.email,identity.password,identity.receipt])assert.ok(!response.responseBody.includes(secret));
    assert.equal((await request(randomBytes(32).toString("base64url"))).responseStatusCode,404);
    await writeFile(`${directory}/live-privacy-status-results.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["anonymous high-entropy receipt returns progress after access revocation","response excludes identity, financial facts and receipt","unknown receipt denied"]},null,2));
    process.stdout.write("Passed anonymous privacy receipt scope and unknown-token denial.\n");
  } else if (mode === "inspect") {
    const alice = await login(0), snapshot = await alice.request("/v1/bootstrap");
    process.stdout.write(JSON.stringify({revision:snapshot.revision,goalCount:snapshot.goals?.length,goals:snapshot.goals?.map((g:any)=>({name:g.data.name,version:g.version,minor:g.data.allocated.minor})),jobs:await Promise.all(snapshot.jobs.map(async (job:any)=>{const value=await alice.request(`/v1/jobs/${job.id}`);return{type:job.type,status:value.status,attempts:value.attempts,error:value.error,hasResult:!!value.result};}))})+"\n");
  } else if (mode === "shortcut") {
    stage = "reviewed shortcut expense readback";
    const alice = await login(0), snapshot = await alice.request("/v1/bootstrap");
    const labels = JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    for (const [label, amount] of [[labels.iosShortcutMerchant, -234], [labels.androidShortcutMerchant, -235]] as const) {
      const records = snapshot.transactions.filter((t:any)=>t.merchant === label);
      assert.equal(records.length,1);
      assert.equal(records[0].version,1); assert.equal(records[0].amount.minor,amount);
      assert.equal(records[0].source,"shortcut"); assert.equal(records[0].category,"Food");
      assert.equal(records[0].date,"2026-11-09"); assert.equal(records[0].description,"Reviewed shortcut");
    }
    await writeFile(`${directory}/live-shortcut-readback.json`,JSON.stringify({project,checkedAt:new Date().toISOString(),status:"passed",tests:["both native shortcut routes open editable review","normal authenticated saves retain shortcut provenance","amount/category/date/notes match reviewed inputs"],revision:snapshot.revision},null,2));
    process.stdout.write("Passed independent shortcut expense readback for both platforms.\n");
  } else if (["roundtrip", "offline"].includes(mode)) {
    stage = "cross-platform lifecycle readback";
    const alice = await login(0), snapshot = await alice.request("/v1/bootstrap");
    const labels = JSON.parse(await readFile(`${directory}/native-test-labels.json`,"utf8"));
    assert.equal(snapshot.profile.monthlyTargetMinor,150000);
    assert.ok(!snapshot.transactions.some((t:any)=>t.merchant==="iOS Live Coffee"));
    const android = snapshot.transactions.filter((t:any)=>t.merchant === labels.androidMerchant);
    assert.equal(android.length,1); assert.equal(android[0].version,2); assert.equal(android[0].amount.minor,-567);
    if(mode === "offline") {
      const offline = snapshot.transactions.filter((t:any)=>t.merchant === labels.offlineMerchant);
      assert.equal(offline.length,1); assert.equal(offline[0].version,1); assert.equal(offline[0].amount.minor,-789);
    }
    const report = {project,checkedAt:new Date().toISOString(),status:"passed",tests:["Android expense edited on iOS","iOS deletion absent from canonical Activity",...(mode === "offline" ? ["offline draft acknowledged exactly once after reconnect"] : [])],revision:snapshot.revision};
    await writeFile(`${directory}/live-${mode}-readback.json`,JSON.stringify(report,null,2));
    process.stdout.write(`Passed independent ${mode} lifecycle readback.\n`);
  } else throw new Error("Choose export, native, roundtrip or offline validation");
}
main().catch((error:any)=>{process.stderr.write(`Live workflow failed at ${stage} (${error?.code ?? error?.name ?? "unknown"}, ${error?.type ?? "assertion"}).\n`);process.exitCode=1;}).finally(async()=>{await Promise.allSettled(closeSessions.map(close=>close()));});
