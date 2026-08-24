#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$APP_ROOT/.generated/msplat-m2}"
REMOTE="https://github.com/Voxelio-app/msplat.git"
REVISION="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
BASE_PATCHER="$SCRIPT_DIR/apply_msplat_m2_patch.py"
PATCHER="$SCRIPT_DIR/apply_msplat_m2_patch_v3.py"
ADAPTER="$SCRIPT_DIR/apply_msplat_m2_to_existing.sh"
TESTER="$SCRIPT_DIR/test_m2_msplat_memory_patch.py"

patch_hash="$(cat "$BASE_PATCHER" "$PATCHER" "$ADAPTER" | shasum -a 256 | awk '{print $1}')"
marker="$OUT/.m2-prepared"
expected_marker="$REVISION:$patch_hash"

if [[ -f "$marker" ]] && [[ "$(cat "$marker")" == "$expected_marker" ]]; then
  python3 "$TESTER" "$OUT"
  echo "PASS: cached M2-patched msplat $REVISION"
  exit 0
fi

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
git init -q "$OUT"
git -C "$OUT" remote add origin "$REMOTE"
GIT_LFS_SKIP_SMUDGE=1 git -C "$OUT" fetch -q --depth 1 origin "$REVISION"
git -C "$OUT" checkout -q --detach FETCH_HEAD

# Use the same non-destructive adapter that HQ can invoke after a disjoint M1
# patch. On this standalone clean tree it also verifies the exact M2 file set.
bash "$ADAPTER" "$OUT"
printf '%s\n' "$expected_marker" > "$marker"
echo "PASS: prepared M2-patched msplat $REVISION at $OUT"
