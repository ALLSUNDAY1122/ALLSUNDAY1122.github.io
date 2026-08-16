#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node scripts/test_scanlab_public_bbox.mjs
node scripts/test_scanlab_public_cursor.mjs

grep -q 'parseScanLabBoundingBox(url.searchParams)' supabase/functions/scanlab-public/index.ts
! grep -q 'Number(url.searchParams.get("minLat"))' supabase/functions/scanlab-public/index.ts
! grep -q '"Cache-Control": "public' supabase/functions/scanlab-public/index.ts
grep -q '"Cache-Control": "private, no-store"' supabase/functions/scanlab-public/index.ts
grep -q '"Vary": "Authorization"' supabase/functions/scanlab-public/index.ts

grep -q 'parseScanLabFeedCursor(url.searchParams.get("cursor"))' supabase/functions/scanlab-public/index.ts
grep -q 'order("id", { ascending: false })' supabase/functions/scanlab-public/index.ts
grep -q 'nextCursor' supabase/functions/scanlab-public/index.ts
grep -q 'page.nextCursor == cursor' SplatNative/ScanLabDiscoverStore.swift
grep -q 'さらに読み込む' SplatNative/ScanLabPagedDiscoverView.swift
grep -q 'ScanLabPagedDiscoverView()' SplatNative/ScanLabDiscoverShellView.swift
grep -q 'ScanLabDiscoverShellView()' SplatNative/SplatNativeApp.swift

echo 'PASS: D2 Discover/feed bbox + cache isolation + cursor browse regression gate'
