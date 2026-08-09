#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATED_DIR="$SCRIPT_DIR/Generated"

cd "$REPO_ROOT"
node tools/otsu4-build-content-v2.mjs
mkdir -p "$GENERATED_DIR"
cp kikenbutsu-otsu4-sprint/questions.generated.json "$GENERATED_DIR/questions.generated.json"

python3 - "$GENERATED_DIR/questions.generated.json" <<'PY'
import json,sys
p=sys.argv[1]
data=json.load(open(p,encoding='utf-8'))
assert data['contentVersion']=='otsu4-2026-08-product-v2'
assert len(data['questions'])==360
print('prepared native questions:',len(data['questions']))
PY
