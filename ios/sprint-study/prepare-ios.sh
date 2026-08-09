#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_SRC="$REPO_ROOT/sprint-study/app-v1.3.0-design.html"
WEB_DST="$SCRIPT_DIR/SprintStudy/Web"

test -f "$WEB_SRC"
rm -rf "$WEB_DST"
mkdir -p "$WEB_DST"
cp "$WEB_SRC" "$WEB_DST/index.html"
echo "Prepared Sprint Study Web assets from app-v1.3.0-design.html"
