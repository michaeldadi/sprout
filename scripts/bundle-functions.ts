import { backendSources } from "./backend-artifacts";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { build } from "esbuild";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

async function main() {
  const sources = await backendSources();
  const artifacts: Record<string, string> = {};
  for (const name of [
    "api",
    "webhooks",
    "worker",
    "ai",
    "dispatcher",
    "privacy", "privacy-status",
  ]) {
    const out = path.resolve("bundles", name);
    await mkdir(out, { recursive: true });
    await build({
      entryPoints: [path.resolve("functions", `${name}.ts`)],
      outfile: path.join(out, "main.js"),
      bundle: true,
      platform: "node",
      target: "node22",
      format: "cjs",
      // Both require() and import().default must expose a callable Appwrite handler.
      footer: { js: "module.exports = module.exports.default;" },
      sourcemap: false,
      legalComments: "none",
    });
    await writeFile(
      path.join(out, "package.json"),
      JSON.stringify({
        name: `sprout-${name}`,
        private: true,
        main: "main.js",
        type: "commonjs",
      }) + "\n",
    );
    artifacts[name] = createHash("sha256").update(await readFile(path.join(out,"main.js"))).digest("hex");
    const handler = createRequire(__filename)(path.join(out, "main.js"));
    const imported = await import(
      pathToFileURL(path.join(out, "main.js")).href
    );
    if (typeof handler !== "function" || typeof imported.default !== "function")
      throw new Error(`Non-callable function bundle: ${name}`);
    // A developer may have service credentials in their environment. A build
    // smoke check must never dispatch real jobs or contact an Appwrite project.
    const project = process.env.APPWRITE_FUNCTION_PROJECT_ID;
    delete process.env.APPWRITE_FUNCTION_PROJECT_ID;
    let response;
    try {
      response = await handler({
        req: { path: "/", method: "GET", headers: {}, bodyText: "{}" },
        res: { json: (body: unknown, status = 200) => ({ body, status }) },
      });
    } finally {
      if (project === undefined)
        delete process.env.APPWRITE_FUNCTION_PROJECT_ID;
      else process.env.APPWRITE_FUNCTION_PROJECT_ID = project;
    }
    const expectedStatus =
      name === "api"
        ? 401
        : name === "dispatcher"
          ? 503
          : name === "webhooks"
            ? 405
            : name === "privacy-status" ? 404 : 400;
    if (response?.status !== expectedStatus)
      throw new Error(`Unexpected unauthenticated bundle response: ${name}`);
  }
  if(JSON.stringify(sources)!==JSON.stringify(await backendSources()))throw new Error("Backend inputs changed during bundling; rebuild before deploying.");
  await writeFile(path.resolve("bundles","manifest.json"),JSON.stringify({schemaVersion:1,sources,artifacts},null,2)+"\n");
}
main().catch((error) => {
  process.stderr.write(
    `Function bundle failed: ${error instanceof Error ? error.message : "unknown build error"}\n`,
  );
  process.exitCode = 1;
});
