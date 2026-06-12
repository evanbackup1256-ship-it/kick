import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const siteRoot = path.join(__dirname, "..");
const outDir = path.join(siteRoot, "out");
const backendRoot = path.join(siteRoot, "..", "..", "backend");
const backendDir = path.join(backendRoot, "site");

function shouldSkipSync() {
  if (process.env.SKIP_BACKEND_SYNC === "1") {
    console.warn("Skip sync — SKIP_BACKEND_SYNC=1");
    return true;
  }
  if (!fs.existsSync(backendRoot)) {
    console.warn(`Skip sync — backend tree missing at ${backendRoot} (Docker/CI isolated build)`);
    return true;
  }
  return false;
}

function emptyDir(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir)) {
    fs.rmSync(path.join(dir, entry), { recursive: true, force: true });
  }
}

function copyDir(src, dest) {
  if (!fs.existsSync(src)) {
    console.warn(`Skip sync — missing ${src}`);
    return false;
  }

  try {
    fs.mkdirSync(dest, { recursive: true });
  } catch (err) {
    if (err && (err.code === "EACCES" || err.code === "EPERM")) {
      console.warn(`Skip sync — cannot create ${dest}: ${err.message}`);
      return false;
    }
    throw err;
  }

  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      if (!copyDir(from, to)) return false;
    } else {
      fs.copyFileSync(from, to);
    }
  }
  return true;
}

if (shouldSkipSync()) {
  process.exit(0);
}

if (!fs.existsSync(outDir)) {
  console.warn("No out/ directory — run next build first");
  process.exit(0);
}

emptyDir(backendDir);

if (copyDir(outDir, backendDir)) {
  console.log(`Synced ${outDir} → ${backendDir}`);
}
