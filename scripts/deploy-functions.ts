/** Local artifact upload fallback: the connector cannot upload local bundles.
 * Supply APPWRITE_API_KEY from the secret manager, never as a CLI argument. */
import { backendSources } from "./backend-artifacts";
import { Client, Functions } from "node-appwrite";
import { InputFile } from "node-appwrite/file";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

async function main() {
  const project = process.env.APPWRITE_PROJECT_ID;
  const endpoint = process.env.APPWRITE_ENDPOINT;
  if (project !== "6af0f72200383d2f1084" || endpoint !== "https://nyc.cloud.appwrite.io/v1" || !process.env.APPWRITE_API_KEY)
    throw new Error("This deployment command requires the verified staging project and a service credential.");
  const directory = process.env.SPROUT_DEPLOYMENT_REPORT_DIR;
  if (!directory || !path.isAbsolute(directory)) throw new Error("Set an absolute private deployment report directory.");
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const artifactManifest = JSON.parse(await readFile(path.resolve("bundles","manifest.json"),"utf8"));
  if(artifactManifest.schemaVersion!==1 || JSON.stringify(artifactManifest.sources)!==JSON.stringify(await backendSources()))throw new Error("Backend sources changed after bundling. Run validation and bundle again.");
  const functions = new Functions(new Client().setEndpoint(endpoint).setProject(project).setKey(process.env.APPWRITE_API_KEY));
  const allowed = ["api", "webhooks", "worker", "ai", "dispatcher", "privacy", "privacy-status"];
  const selected = process.env.SPROUT_DEPLOY_FUNCTIONS?.split(",") ?? allowed;
  if (!selected.length || selected.some(name=>!allowed.includes(name)) || new Set(selected).size !== selected.length) throw new Error("Choose known function boundaries");
  let previous: any = {functions:[]};
  try { previous = JSON.parse(await readFile(path.join(directory,"deployments.json"),"utf8")); } catch { /* Initial deployment. */ }
  const report: any = { project, endpoint, backendSourceHash:createHash("sha256").update(JSON.stringify(artifactManifest.sources)).digest("hex"), sourceCommit: execFileSync("git", ["rev-parse", "HEAD"], {encoding:"utf8"}).trim(), workingTree: "uncommitted", startedAt: new Date().toISOString(), functions: previous.functions.filter((entry:any)=>!selected.includes(entry.functionId.replace("sprout-",""))) };
  for (const name of selected) {
    const bundle = path.resolve("bundles", name);
    const archive = path.join(directory, `sprout-${name}.tar.gz`);
    execFileSync("tar", ["-czf", archive, "-C", bundle, "main.js", "package.json"]);
    const hash = createHash("sha256").update(await readFile(path.join(bundle, "main.js"))).digest("hex");
    if(hash!==artifactManifest.artifacts[name])throw new Error("Function bundle changed after manifest generation.");
    const deployment = await functions.createDeployment({ functionId: `sprout-${name}`, code: InputFile.fromPath(archive, `sprout-${name}.tar.gz`), activate: true, entrypoint: "main.js", commands: "" });
    const entry = { functionId: `sprout-${name}`, deploymentId: deployment.$id, sha256: hash, status: deployment.status };
    report.functions.push(entry);
    await writeFile(path.join(directory, "deployments.json"), JSON.stringify(report, null, 2));
    process.stdout.write(`Uploaded ${entry.functionId}: ${entry.deploymentId}\n`);
    for (let attempt = 0; attempt < 90; attempt++) {
      const status = await functions.getDeployment({ functionId: entry.functionId, deploymentId: entry.deploymentId });
      entry.status = status.status;
      await writeFile(path.join(directory, "deployments.json"), JSON.stringify(report, null, 2));
      if (status.status === "ready") break;
      if (["failed", "canceled"].includes(status.status)) throw new Error(`Deployment ${entry.functionId} ${status.status}; inspect its build logs.`);
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
    if (entry.status !== "ready") throw new Error(`Deployment ${entry.functionId} did not finish within the observation window.`);
    const current = await functions.get({ functionId: entry.functionId });
    if (current.deploymentId !== entry.deploymentId) throw new Error(`Deployment ${entry.functionId} is ready but not active.`);
    process.stdout.write(`Verified active ${entry.functionId}\n`);
  }
  report.completedAt = new Date().toISOString();
  await writeFile(path.join(directory, "deployments.json"), JSON.stringify(report, null, 2));
}
main().catch(() => { process.stderr.write("Staging deployment failed. Inspect the private deployment report and Appwrite build status; credentials were not logged.\n"); process.exitCode = 1; });
