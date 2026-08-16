#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node scripts/test_scanlab_public_bbox.mjs

grep -q 'parseScanLabBoundingBox(url.searchParams)' supabase/functions/scanlab-public/index.ts
! grep -q 'Number(url.searchParams.get("minLat"))' supabase/functions/scanlab-public/index.ts
! grep -q '"Cache-Control": "public' supabase/functions/scanlab-public/index.ts
grep -q '"Cache-Control": "private, no-store"' supabase/functions/scanlab-public/index.ts
grep -q '"Vary": "Authorization"' supabase/functions/scanlab-public/index.ts

echo 'PASS: D2 Discover/feed bbox + personalized-cache regression gate'
