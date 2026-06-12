import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const siteRoot = path.join(__dirname, "..");
const outDir = path.join(siteRoot, "out");
const backendDir = path.join(siteRoot, "..", "..", "backend", "site");

function copyDir(src: string, dest: string) {
  if (!fs.existsSync(src)) {
    console.warn(`Skip sync — missing ${src}`);
    return;
  }
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(from, to);
    else fs.copyFileSync(from, to);
  }
}

if (fs.existsSync(outDir)) {
  copyDir(outDir, backendDir);
  console.log(`Synced ${outDir} → ${backendDir}`);
} else {
  console.warn("No out/ directory — run next build first");
}
