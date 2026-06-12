import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const siteRoot = path.resolve(path.join(__dirname, ".."));
const outDir = path.join(siteRoot, "out");

function resolveBackendRoot() {
  if (process.env.BACKEND_ROOT) {
    return path.resolve(process.env.BACKEND_ROOT);
  }

  let dir = siteRoot;
  for (let depth = 0; depth < 8; depth += 1) {
    const candidate = path.join(dir, "backend");
    if (fs.existsSync(path.join(candidate, "telemetry_relay.py"))) {
      return candidate;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  return path.resolve(siteRoot, "..", "..", "backend");
}

function isIsolatedBuild() {
  if (process.env.SKIP_BACKEND_SYNC === "1") return true;
  if (process.env.CI === "true" || process.env.CI === "1") return true;
  if (process.env.DOCKER_BUILD === "1") return true;
  if (process.env.RAILWAY === "true") return true;
  if (fs.existsSync("/.dockerenv")) return true;
  return false;
}

function emptyDir(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir)) {
    const target = path.join(dir, entry);
    try {
      fs.rmSync(target, { recursive: true, force: true, maxRetries: 2, retryDelay: 50 });
    } catch (err) {
      if (err && (err.code === "EPERM" || err.code === "EBUSY" || err.code === "EACCES")) {
        console.warn(`postbuild: could not remove ${target} (${err.code}), will overwrite on copy`);
      } else {
        throw err;
      }
    }
  }
}

function syncDir(src, dest) {
  if (!fs.existsSync(src)) {
    console.warn(`postbuild: missing export directory ${src}`);
    return false;
  }

  fs.mkdirSync(dest, { recursive: true });
  fs.cpSync(src, dest, { recursive: true, force: true });
  return true;
}

const backendRoot = resolveBackendRoot();
const backendSiteDir = path.join(backendRoot, "site");

if (!fs.existsSync(outDir)) {
  console.warn("postbuild: no out/ directory — run next build first");
  process.exit(0);
}

if (!fs.existsSync(backendRoot) || !fs.existsSync(path.join(backendRoot, "telemetry_relay.py"))) {
  if (isIsolatedBuild()) {
    console.log(
      `postbuild: isolated build — static export stays in ${outDir} (Docker/CI copies out/ directly; no repo backend at ${backendRoot})`
    );
    process.exit(0);
  }

  console.warn(
    `postbuild: backend not found at ${backendRoot}. Set BACKEND_ROOT or run from the full repo checkout.`
  );
  process.exit(0);
}

emptyDir(backendSiteDir);

if (syncDir(outDir, backendSiteDir)) {
  console.log(`postbuild: synced ${outDir} → ${backendSiteDir}`);
}
