import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const siteDir = join(dirname(fileURLToPath(import.meta.url)), "..");
const dest = join(siteDir, "data/site.snapshot.json");

function resolveSiteConfig() {
  const candidates = [
    process.env.ALLERAL_SITE_CONFIG,
    join(siteDir, "..", "..", "cfg", "site.json"),
    join(siteDir, "cfg", "site.json"),
    join(siteDir, "site.json"),
  ].filter(Boolean);

  for (const path of candidates) {
    if (existsSync(path)) {
      return path;
    }
  }
  return null;
}

mkdirSync(dirname(dest), { recursive: true });

const src = resolveSiteConfig();
if (!src) {
  if (existsSync(dest)) {
    console.log(`prebuild-site: cfg/site.json not found — keeping ${dest}`);
    process.exit(0);
  }
  throw new Error(
    "cfg/site.json not found (checked ALLERAL_SITE_CONFIG, ../../cfg/site.json, ./cfg/site.json)"
  );
}

copyFileSync(src, dest);

const snapshot = JSON.parse(readFileSync(dest, "utf8"));
writeFileSync(
  join(siteDir, "data/site.meta.json"),
  JSON.stringify({ bakedAt: new Date().toISOString(), version: snapshot.version ?? 1 }, null, 2)
);

const apiBase = process.env.NEXT_PUBLIC_ALLERAL_API;
const configJsPath = join(siteDir, "public/assets/config.js");
if (existsSync(configJsPath)) {
  let configJs = readFileSync(configJsPath, "utf8");
  const injected =
    apiBase !== undefined
      ? String(apiBase).replace(/\/$/, "")
      : (snapshot.links?.relay || snapshot.links?.website?.replace(/\/$/, "") || "");
  configJs = configJs.replace("__ALLERAL_API__", injected);
  writeFileSync(configJsPath, configJs);
}

console.log(`prebuild-site: baked ${src} → ${dest}`);

const patch = join(siteDir, "scripts/patch-static-html.mjs");
if (existsSync(patch)) {
  spawnSync(process.execPath, [patch], { stdio: "inherit", cwd: siteDir, env: process.env });
}
