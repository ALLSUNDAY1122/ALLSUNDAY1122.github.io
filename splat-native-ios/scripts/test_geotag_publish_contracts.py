#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
view = (ROOT / "SplatNative" / "PublishScanView.swift").read_text(encoding="utf-8")
policy = (ROOT / "SplatNative" / "ScanLabGeotagPolicy.swift").read_text(encoding="utf-8")
migration = (ROOT / "supabase" / "migrations" / "20260817214845_scanlab_d2_geotag_privacy_boundary_v19.sql").read_text(encoding="utf-8")

checks = {
    "UI uses trusted publish package": "backend.publishTrustedPackage(" in view,
    "UI does not call legacy publish": re.search(r"backend\.publish\s*\(", view) is None,
    "public copy states location is optional": "位置情報を付けなくてもDiscoverへ公開できます" in view,
    "public action supports Discover without location": 'selectedLocation == nil ? "Discoverへ公開" : "Map・Discoverへ公開"' in view,
    "policy strips non-public location": "guard visibility == .public, let location else { return nil }" in policy,
    "policy allows public without geotag": "guard let location else { return true }" in policy,
    "DB enforces public-only location": "scanlab_location_public_only" in migration,
    "DB enforces coordinate pair integrity": "scanlab_geotag_pair_integrity" in migration,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {name}")

if failed:
    raise SystemExit("geotag publish contract regression: " + ", ".join(failed))
