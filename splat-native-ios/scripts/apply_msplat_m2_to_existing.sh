#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:?usage: apply_msplat_m2_to_existing.sh <msplat-root>}"
REVISION="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
PATCHER="$SCRIPT_DIR/apply_msplat_m2_patch_v3.py"
TESTER="$SCRIPT_DIR/test_m2_msplat_memory_patch.py"

[[ -d "$ROOT/.git" || -f "$ROOT/.git" ]] || { echo "M2 compose target is not a git checkout: $ROOT" >&2; exit 1; }
actual_revision="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$actual_revision" == "$REVISION" ]] || {
  echo "M2 compose revision mismatch: expected $REVISION, got $actual_revision" >&2
  exit 1
}

dirty_files() {
  {
    git -C "$ROOT" diff --name-only
    git -C "$ROOT" diff --cached --name-only
    git -C "$ROOT" ls-files --others --exclude-standard
  } | sed '/^$/d' | LC_ALL=C sort -u
}

expected=$'Sources/MsplatCore/internal/include/metal_tensor.hpp\nSources/MsplatCore/internal/include/model.hpp\nSources/MsplatCore/src/model.cpp'
before="$(dirty_files)"

# Fail closed if another lane already touched M2-owned trainer files in either
# the working tree or index. Prior dirty changes in disjoint files (for example
# M1 Camera/Dataset files) are allowed and must survive byte-for-byte.
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if printf '%s\n' "$before" | grep -Fxq "$path"; then
    echo "M2 compose target already modifies M2-owned file: $path" >&2
    exit 1
  fi
done <<< "$expected"

python3 "$PATCHER" "$ROOT"
git -C "$ROOT" diff --check
git -C "$ROOT" diff --cached --check

after="$(dirty_files)"
missing_prior="$(comm -23 <(printf '%s\n' "$before" | sed '/^$/d') <(printf '%s\n' "$after" | sed '/^$/d'))"
if [[ -n "$missing_prior" ]]; then
  echo "M2 compose unexpectedly removed pre-existing changes:" >&2
  printf '%s\n' "$missing_prior" >&2
  exit 1
fi

added="$(comm -13 <(printf '%s\n' "$before" | sed '/^$/d') <(printf '%s\n' "$after" | sed '/^$/d'))"
if [[ "$added" != "$expected" ]]; then
  echo "M2 compose added an unexpected file set:" >&2
  printf '%s\n' "$added" >&2
  exit 1
fi

python3 "$TESTER" "$ROOT"
echo "PASS: applied M2 trainer-memory patch non-destructively to existing msplat tree"
