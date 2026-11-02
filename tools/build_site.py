#!/usr/bin/env python3
"""Builds dist/site/: the game bundled into one game.js (three.js included) + index.html, style.css,
icons and assets. The desktop and mobile apps package this folder.
Needs esbuild: set ESBUILD=/path/to/esbuild or have it on PATH."""
import os, re, shutil, subprocess

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
web = os.path.join(root, "web")
out = os.path.join(root, "dist", "site")
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)
esbuild = os.environ.get("ESBUILD", "esbuild")

subprocess.run([esbuild, os.path.join(web, "src", "main.js"), "--bundle", "--format=esm", "--minify", "--target=es2020",
                "--legal-comments=none", "--alias:three=" + os.path.join(web, "vendor", "three", "three.module.min.js"),
                "--outfile=" + os.path.join(out, "game.js")], check=True)
for d in ["icons", "assets"]:
    if os.path.isdir(os.path.join(web, d)):
        shutil.copytree(os.path.join(web, d), os.path.join(out, d))
shutil.copy(os.path.join(web, "style.css"), os.path.join(out, "style.css"))

html = open(os.path.join(web, "index.html"), encoding="utf-8").read()
html = re.sub(r'\s*<!-- dev only:.*?</script>', "", html, flags=re.S)
html = html.replace('<script type="module" src="src/main.js"></script>', '<script type="module" src="game.js"></script>')
assert "importmap" not in html and "game.js" in html, "index.html markers changed; update build_site.py"
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(html)
print("Built", out)
