#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DST="$SCRIPT_DIR/Web"

rm -rf "$WEB_DST"
mkdir -p "$WEB_DST"

for file in index.html question_bank_180.payload.json; do
  test -f "$WEB_SRC/$file"
  cp "$WEB_SRC/$file" "$WEB_DST/$file"
done

# The native app is fully offline for learning. Only the audited payload is bundled.
test "$(wc -c < "$WEB_DST/question_bank_180.payload.json" | tr -d ' ')" = "234369"

echo "Prepared FP3ManabiSprint audited web bundle."
