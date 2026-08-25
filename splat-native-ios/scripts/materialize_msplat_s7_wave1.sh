#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
DEST="$ROOT/Packages/MsplatMemory"

# S7 Wave 1 has one canonical Msplat materialization. M1 owns the reset/checkout
# and Dataset/Camera patch. M2 is then added non-destructively to that exact tree.
bash "$ROOT/scripts/materialize_msplat_memory.sh"
bash "$ROOT/scripts/apply_msplat_m2_to_existing.sh" "$DEST"

expected=$'.scaniverse-m1-revision\nSources/MsplatCore/internal/include/input_data.hpp\nSources/MsplatCore/internal/include/metal_tensor.hpp\nSources/MsplatCore/internal/include/model.hpp\nSources/MsplatCore/src/input_data.cpp\nSources/MsplatCore/src/model.cpp\nSources/MsplatCore/src/msplat_api.mm'
actual="$({
  git -C "$DEST" diff --name-only
  git -C "$DEST" diff --cached --name-only
  git -C "$DEST" ls-files --others --exclude-standard
} | sed '/^$/d' | LC_ALL=C sort -u)"

if [[ "$actual" != "$expected" ]]; then
  echo "S7 combined Msplat dirty inventory mismatch:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

grep -Fxq "$PIN" "$DEST/.scaniverse-m1-revision"
python3 "$ROOT/scripts/test_msplat_memory_patch.py" "$DEST"
python3 "$ROOT/scripts/test_m2_msplat_memory_patch.py" "$DEST"
git -C "$DEST" diff --check
git -C "$DEST" diff --cached --check
python3 "$ROOT/scripts/test_s7_wave1_integration_contracts.py"

echo "MSPLAT_S7_WAVE1_COMPOSED revision=$PIN source_files=6 dirty_paths=7"
