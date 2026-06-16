import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const siteDir = join(dirname(fileURLToPath(import.meta.url)), "..");
const basePath = (process.env.NEXT_PUBLIC_BASE_PATH || "").replace(/\/+$/, "");
const prefix = basePath ? `${basePath}/` : "/";

const STATIC_PAGES = ["admin.html", "manage.html", "dev.html"];

function patchHtml(html) {
  let out = html;
  out = out.replace(/href="\/assets\//g, 'href="assets/');
  out = out.replace(/src="\/assets\//g, 'src="assets/');
  if (basePath) {
    out = out.replace(/href="\/(?!\/)/g, `href="${prefix}`);
  }
  return out;
}

function writeFolderIndex(outDir, pageName) {
  const src = join(outDir, pageName);
  if (!existsSync(src)) return;
  const folder = join(outDir, pageName.replace(/\.html$/, ""));
  mkdirSync(folder, { recursive: true });
  const html = readFileSync(src, "utf8");
  writeFileSync(join(folder, "index.html"), html);
}

function patchPublicDir() {
  for (const page of STATIC_PAGES) {
    const path = join(siteDir, "public", page);
    if (!existsSync(path)) continue;
    writeFileSync(path, patchHtml(readFileSync(path, "utf8")));
  }
}

function patchOutDir() {
  const outDir = join(siteDir, "out");
  if (!existsSync(outDir)) return;
  for (const page of STATIC_PAGES) {
    const path = join(outDir, page);
    if (!existsSync(path)) continue;
    const patched = patchHtml(readFileSync(path, "utf8"));
    writeFileSync(path, patched);
    writeFolderIndex(outDir, page);
  }
}

patchPublicDir();
patchOutDir();

if (basePath) {
  console.log(`patch-static-html: basePath=${basePath}`);
} else {
  console.log("patch-static-html: relative assets + clean URL folders");
}
