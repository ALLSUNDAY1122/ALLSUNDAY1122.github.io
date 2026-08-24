#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${1:?usage: test_m2_composition_adapter.sh <clean-msplat-root>}"
REVISION="d620d9c58d270e7de9e34a9d8a85dcf938a5070d"
ADAPTER="$SCRIPT_DIR/apply_msplat_m2_to_existing.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/msplat-m2-compose.XXXXXX")"
COMPOSE="$TMP/compose"
CONFLICT="$TMP/conflict"

cleanup() {
  git -C "$SOURCE_ROOT" worktree remove --force "$COMPOSE" >/dev/null 2>&1 || true
  git -C "$SOURCE_ROOT" worktree remove --force "$CONFLICT" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

actual_revision="$(git -C "$SOURCE_ROOT" rev-parse HEAD)"
[[ "$actual_revision" == "$REVISION" ]] || {
  echo "M2 composition test source revision mismatch: expected $REVISION, got $actual_revision" >&2
  exit 1
}

# Simulate the real M1 dirty-file set using both staged-only and unstaged edits.
git -C "$SOURCE_ROOT" worktree add --quiet --detach "$COMPOSE" "$REVISION"
printf '\n// M2 composition test: staged foreign input header\n' >> "$COMPOSE/Sources/MsplatCore/internal/include/input_data.hpp"
printf '\n// M2 composition test: unstaged foreign input implementation\n' >> "$COMPOSE/Sources/MsplatCore/src/input_data.cpp"
printf '\n// M2 composition test: staged foreign API implementation\n' >> "$COMPOSE/Sources/MsplatCore/src/msplat_api.mm"
git -C "$COMPOSE" add \
  Sources/MsplatCore/internal/include/input_data.hpp \
  Sources/MsplatCore/src/msplat_api.mm

bash "$ADAPTER" "$COMPOSE"

expected=$'Sources/MsplatCore/internal/include/input_data.hpp\nSources/MsplatCore/internal/include/metal_tensor.hpp\nSources/MsplatCore/internal/include/model.hpp\nSources/MsplatCore/src/input_data.cpp\nSources/MsplatCore/src/model.cpp\nSources/MsplatCore/src/msplat_api.mm'
actual="$({
  git -C "$COMPOSE" diff --name-only
  git -C "$COMPOSE" diff --cached --name-only
  git -C "$COMPOSE" ls-files --others --exclude-standard
} | sed '/^$/d' | LC_ALL=C sort -u)"
[[ "$actual" == "$expected" ]] || {
  echo "M2 composition test combined dirty set mismatch:" >&2
  printf '%s\n' "$actual" >&2
  exit 1
}

grep -Fq 'staged foreign input header' "$COMPOSE/Sources/MsplatCore/internal/include/input_data.hpp"
grep -Fq 'unstaged foreign input implementation' "$COMPOSE/Sources/MsplatCore/src/input_data.cpp"
grep -Fq 'staged foreign API implementation' "$COMPOSE/Sources/MsplatCore/src/msplat_api.mm"
staged="$(git -C "$COMPOSE" diff --cached --name-only | LC_ALL=C sort)"
expected_staged=$'Sources/MsplatCore/internal/include/input_data.hpp\nSources/MsplatCore/src/msplat_api.mm'
[[ "$staged" == "$expected_staged" ]] || {
  echo "M2 composition test did not preserve staged foreign files:" >&2
  printf '%s\n' "$staged" >&2
  exit 1
}

git -C "$SOURCE_ROOT" worktree remove --force "$COMPOSE" >/dev/null

# A staged-only edit to an M2-owned file must be rejected before patching.
git -C "$SOURCE_ROOT" worktree add --quiet --detach "$CONFLICT" "$REVISION"
printf '\n// M2 composition test: staged owned-file conflict\n' >> "$CONFLICT/Sources/MsplatCore/internal/include/model.hpp"
git -C "$CONFLICT" add Sources/MsplatCore/internal/include/model.hpp
if bash "$ADAPTER" "$CONFLICT" >"$TMP/conflict.log" 2>&1; then
  echo "M2 composition adapter accepted a staged-only edit to an owned file" >&2
  exit 1
fi
grep -Fq 'M2 compose target already modifies M2-owned file: Sources/MsplatCore/internal/include/model.hpp' "$TMP/conflict.log"

echo "PASS: M2 composition adapter preserves real M1-shaped staged/unstaged changes and rejects staged owned-file conflicts"
