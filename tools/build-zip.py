"""Build a CurseForge upload zip by hand.

CI does this on a tag push (see .github/workflows/release.yml); this is for
uploading a build manually, or for checking what a release will contain.

A WoW addon zip must hold the addon folder at its root, so that extracting it
into Interface/AddOns produces Interface/AddOns/LootCheck/LootCheck.toc. The
addon lives at the repository root here, so everything development-only is
skipped: the exclusions below mirror the "ignore" list in .pkgmeta.

    python tools/build-zip.py
"""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
PACKAGE = "LootCheck"

# Keep in step with .pkgmeta
EXCLUDED_DIRS = {"tests", "tools", ".github", ".git", "dist", "__pycache__", ".venv", "venv"}
EXCLUDED_FILES = {
    ".pkgmeta", ".gitignore", ".gitattributes",
    "shadow_resist.py", "srcheck_gui.pyw", "wcl_credentials.json",
}

toc_path = os.path.join(ROOT, PACKAGE + ".toc")
if not os.path.isfile(toc_path):
    sys.exit("no %s.toc at %s" % (PACKAGE, ROOT))

toc = open(toc_path, encoding="utf-8").read()


def header(name, default=None):
    match = re.search(r"^## %s:\s*(.+)$" % name, toc, re.M)
    if match:
        return match.group(1).strip()
    if default is not None:
        return default
    sys.exit("%s.toc has no '## %s:' line" % (PACKAGE, name))


version = header("Version")
interface = header("Interface")
project = header("X-Curse-Project-ID", "not set")

os.makedirs(DIST, exist_ok=True)
out = os.path.join(DIST, "%s-%s.zip" % (PACKAGE, version))

count = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDED_DIRS)
        for name in sorted(files):
            if name in EXCLUDED_FILES or name.endswith((".pyc", ".zip")):
                continue
            full = os.path.join(folder, name)
            # Everything goes under a single LootCheck/ folder in the zip
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            archive.write(full, "%s/%s" % (PACKAGE, rel))
            count += 1

print("built %s" % out)
print("  version    %s" % version)
print("  interface  %s" % interface)
print("  project    %s" % project)
print("  %d files, %.1f KB" % (count, os.path.getsize(out) / 1024.0))

with zipfile.ZipFile(out) as archive:
    names = archive.namelist()
roots = sorted({n.split("/")[0] for n in names})
tocs = [n for n in names if n.endswith(".toc")]
print()
print("  zip root   %s" % roots)
print("  toc at     %s" % tocs)
if roots != [PACKAGE] or tocs != ["%s/%s.toc" % (PACKAGE, PACKAGE)]:
    sys.exit("unexpected zip layout: CurseForge needs %s/%s.toc" % (PACKAGE, PACKAGE))
print("  layout OK")
