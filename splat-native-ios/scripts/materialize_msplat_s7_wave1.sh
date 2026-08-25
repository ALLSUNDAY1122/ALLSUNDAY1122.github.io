#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
DEST="$ROOT/Packages/MsplatMemory"

# Canonical Msplat materialization is ordered and fail-closed:
# M1 camera/image residency -> M2 tensor/trainer lifetime -> S10 bounded backing
# and Metal transient lifecycle. S10 never resets the tree or bypasses M1/M2.
bash "$ROOT/scripts/materialize_msplat_memory.sh"
bash "$ROOT/scripts/apply_msplat_m2_to_existing.sh" "$DEST"
python3 "$ROOT/scripts/apply_msplat_s10_patch.py" "$DEST"

expected=$'.scaniverse-m1-revision\nSources/MsplatCore/internal/include/input_data.hpp\nSources/MsplatCore/internal/include/metal_tensor.hpp\nSources/MsplatCore/internal/include/model.hpp\nSources/MsplatCore/metal/bindings.h\nSources/MsplatCore/metal/msplat_metal.mm\nSources/MsplatCore/src/input_data.cpp\nSources/MsplatCore/src/model.cpp\nSources/MsplatCore/src/msplat_api.mm'
actual="$({
  git -C "$DEST" diff --name-only
  git -C "$DEST" diff --cached --name-only
  git -C "$DEST" ls-files --others --exclude-standard
} | sed '/^$/d' | LC_ALL=C sort -u)"

if [[ "$actual" != "$expected" ]]; then
  echo "S10 composed Msplat dirty inventory mismatch:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

grep -Fxq "$PIN" "$DEST/.scaniverse-m1-revision"
python3 "$ROOT/scripts/test_msplat_memory_patch.py" "$DEST"
python3 "$ROOT/scripts/test_m2_msplat_memory_patch.py" "$DEST"
python3 "$ROOT/scripts/test_s10_bounded_memory_patch.py" "$DEST"
git -C "$DEST" diff --check
git -C "$DEST" diff --cached --check
python3 "$ROOT/scripts/test_s7_wave1_integration_contracts.py"

echo "MSPLAT_S10_COMPOSED revision=$PIN source_files=8 dirty_paths=9"
