// Dev server: serves web/ (or another folder) with no caching.
//   node tools/serve.mjs [port] [folder]      default 5173, web/
// Open http://localhost:5173/ (add ?dev to skip the menu).
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(process.argv[3] || path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "web"));
const port = Number(process.argv[2] || process.env.PORT || 5173);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css", ".json": "application/json",
  ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".glb": "model/gltf-binary", ".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav", ".webmanifest": "application/manifest+json" };

export function serve(p = port, dir = root) {
  const server = http.createServer((req, res) => {
    let rel = decodeURIComponent(new URL(req.url, "http://x").pathname);
    if (rel.endsWith("/")) rel += "index.html";
    const file = path.normalize(path.join(dir, rel));
    if (!file.startsWith(dir + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404).end("Not found");
      return;
    }
    res.writeHead(200, { "Content-Type": TYPES[path.extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(p, "127.0.0.1", () => resolve(server)));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await serve();
  console.log(`Dragon Ball dev server: http://localhost:${port}/  (serving ${root})`);
}
