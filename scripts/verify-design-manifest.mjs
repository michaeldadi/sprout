import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(
  fs.readFileSync(path.join(root, "design/aidesigner-manifest.json"), "utf8"),
);
const frames = manifest.frames.filter((frame) => frame.role === "baseline");
if (frames.length !== 24 || new Set(frames.map((f) => f.id)).size !== 24)
  throw new Error("The selected baseline must contain 24 unique frames.");
for (const platform of ["ios", "android"]) {
  const selected = frames.filter((frame) => frame.platform === platform);
  if (
    selected.length !== 12 ||
    new Set(selected.map((f) => f.screen)).size !== 12
  )
    throw new Error(`Incomplete ${platform} screen mapping.`);
  for (const frame of selected) {
    if (
      !frame.nativeSource ||
      !frame.nativeRoute ||
      !fs.existsSync(path.join(root, frame.nativeSource))
    )
      throw new Error(`Missing native mapping for ${frame.id}.`);
    const source = fs.readFileSync(path.join(root, frame.nativeSource), "utf8");
    if (
      !frame.nativeSymbol ||
      !new RegExp(`\\b(?:struct|fun)\\s+${frame.nativeSymbol}\\b`).test(source)
    )
      throw new Error(`Missing native view symbol for ${frame.id}.`);
    if (
      !frame.nativeEvidence?.file ||
      !fs.existsSync(path.join(root, frame.nativeEvidence.file))
    )
      throw new Error(`Missing fixture evidence for ${frame.id}.`);
    const evidenceHash = crypto
      .createHash("sha256")
      .update(fs.readFileSync(path.join(root, frame.nativeEvidence.file)))
      .digest("hex");
    if (evidenceHash !== frame.nativeEvidence.sha256)
      throw new Error(
        `Native evidence changed without a manifest update: ${frame.id}.`,
      );
  }
}
const index = process.argv.indexOf("--source");
if (index >= 0) {
  const source = process.argv[index + 1];
  if (!source)
    throw new Error("Supply the existing AIDesigner project folder.");
  for (const frame of manifest.frames) {
    const hash = crypto
      .createHash("sha256")
      .update(fs.readFileSync(path.join(source, frame.sourceFile)))
      .digest("hex");
    if (hash !== frame.sha256)
      throw new Error(
        `Design delta needs review: ${frame.id} (${frame.sourceFile})`,
      );
  }
}
process.stdout.write(
  "Selected design frame mappings verified" +
    (index >= 0 ? " against local source hashes" : "") +
    ".\n",
);
