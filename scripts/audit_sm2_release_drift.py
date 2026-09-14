#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CHECKLIST = ROOT / "ios/health-manager-2/RELEASE_CHECKLIST.md"
BASELINE = "f29557c61f7898707f513dc1c1385baa6a6c87c2"  # historical Build 16 source
PRODUCT_PREFIXES = (
    "apps/sanitary-manager-2/",
    "ios/health-manager-2/",
    "codemagic.yaml",
)

text = CHECKLIST.read_text(encoding="utf-8")

# Release CI providers may use a shallow checkout. The drift gate must compare
# against the recorded baseline rather than fail merely because that commit is
# not present locally. Fetch exactly the pinned baseline when needed; never
# widen the comparison to an arbitrary available ancestor.
present = subprocess.run(
    ["git", "cat-file", "-e", f"{BASELINE}^{{commit}}"],
    cwd=ROOT,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
).returncode == 0
if not present:
    fetch = subprocess.run(
        ["git", "fetch", "--no-tags", "--depth=1", "origin", BASELINE],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if fetch.returncode != 0:
        print("FAIL: HM2 release drift guard cannot materialize pinned baseline")
        print((fetch.stderr or fetch.stdout).strip()[:1200])
        raise SystemExit(1)

proc = subprocess.run(
    ["git", "diff", "--name-only", f"{BASELINE}..HEAD"],
    cwd=ROOT,
    check=True,
    capture_output=True,
    text=True,
)
changed = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
product_changes = [
    path for path in changed
    if any(path == p or path.startswith(p) for p in PRODUCT_PREFIXES)
]

errors = []
if product_changes:
    stale_claims = (
        "Build 16生成commit `f29557c61f7898707f513dc1c1385baa6a6c87c2` 以降、第二種の問題バンク・UI・approved AppIcon sourceに変更なし",
        "したがって300問/アイコン/Build 16のPASSを失効させる製品差分なし",
    )
    for claim in stale_claims:
        if claim in text:
            errors.append(f"stale release assertion remains: {claim}")
    required = (
        "Build 16を現行Release GateのPASS根拠として使用しない",
        "current HEADを含む新Build生成",
        "新Build `VALID / APP_STORE_ELIGIBLE / expired=false` read-back",
    )
    for marker in required:
        if marker not in text:
            errors.append(f"release invalidation marker missing: {marker}")

if errors:
    print("FAIL: HM2 release drift guard")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

if product_changes:
    print(f"PASS: Build 16 is explicitly invalidated; {len(product_changes)} product-impact paths changed since baseline")
else:
    print("PASS: no product-impact drift from recorded release baseline")
