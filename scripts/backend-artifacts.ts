import {createHash} from "node:crypto";
import {readFile,readdir} from "node:fs/promises";
import path from "node:path";
const root=path.resolve(__dirname,"..");
export async function backendSources(){
 const entries:Record<string,string>={};
 async function visit(relative:string){
  for(const entry of (await readdir(path.join(root,relative),{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name))){
   const name=`${relative}/${entry.name}`;if(entry.isDirectory())await visit(name);else if(/\.(ts|json)$/.test(entry.name))entries[name]=createHash("sha256").update(await readFile(path.join(root,name))).digest("hex");
  }
 }
 for(const name of ["services/contracts","services/domain","services/functions","services/integrations","services/tests","design/fixtures"])await visit(name);
 for(const name of ["yarn.lock","services/package.json","services/tsconfig.ai.json","services/vitest.config.ts","scripts/package.json","scripts/bundle-functions.ts","scripts/backend-artifacts.ts"])entries[name]=createHash("sha256").update(await readFile(path.join(root,name))).digest("hex");
 return Object.fromEntries(Object.entries(entries).sort(([a],[b])=>a.localeCompare(b)));
}
