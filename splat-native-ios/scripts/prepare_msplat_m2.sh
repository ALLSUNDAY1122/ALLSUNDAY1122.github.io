#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$APP_ROOT/.generated/msplat-m2}"
REMOTE="https://github.com/Voxelio-app/msplat.git"
REVISION="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
PATCHER="$SCRIPT_DIR/apply_msplat_m2_patch.py"
TESTER="$SCRIPT_DIR/test_m2_msplat_memory_patch.py"

patch_hash="$(shasum -a 256 "$PATCHER" | awk '{print $1}')"
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

actual_revision="$(git -C "$OUT" rev-parse HEAD)"
if [[ "$actual_revision" != "$REVISION" ]]; then
  echo "M2 msplat revision mismatch: expected $REVISION, got $actual_revision" >&2
  exit 1
fi

python3 "$PATCHER" "$OUT"
git -C "$OUT" diff --check

changed="$(git -C "$OUT" diff --name-only | LC_ALL=C sort)"
expected=$'Sources/MsplatCore/internal/include/metal_tensor.hpp\nSources/MsplatCore/internal/include/model.hpp\nSources/MsplatCore/src/model.cpp'
if [[ "$changed" != "$expected" ]]; then
  echo "M2 patch touched an unexpected file set:" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi

python3 "$TESTER" "$OUT"
printf '%s\n' "$expected_marker" > "$marker"
echo "PASS: prepared M2-patched msplat $REVISION at $OUT"
