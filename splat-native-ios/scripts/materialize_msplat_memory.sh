#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
REMOTE="https://github.com/Voxelio-app/msplat.git"
DEST="$ROOT/Packages/MsplatMemory"
PATCHER="$ROOT/scripts/patch_msplat_memory.py"

if [[ -d "$DEST/.git" ]] && [[ "$(git -C "$DEST" rev-parse HEAD 2>/dev/null || true)" == "$PIN" ]]; then
  git -C "$DEST" reset --hard "$PIN" >/dev/null
  git -C "$DEST" clean -ffd >/dev/null
else
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --filter=blob:none "$REMOTE" "$DEST"
  git -C "$DEST" checkout --detach "$PIN"
fi

actual="$(git -C "$DEST" rev-parse HEAD)"
[[ "$actual" == "$PIN" ]] || { echo "unexpected msplat revision: $actual" >&2; exit 1; }
python3 "$PATCHER" "$DEST"
python3 "$ROOT/scripts/test_msplat_memory_patch.py" "$DEST"
printf '%s\n' "$PIN" > "$DEST/.scaniverse-m1-revision"

echo "MSPLAT_M1_MATERIALIZED revision=$PIN"
