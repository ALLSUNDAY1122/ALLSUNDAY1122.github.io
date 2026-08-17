#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "SplatNative"
view = (SOURCE_ROOT / "PublishScanView.swift").read_text(encoding="utf-8")
policy = (SOURCE_ROOT / "ScanLabGeotagPolicy.swift").read_text(encoding="utf-8")
migration = (ROOT / "supabase" / "migrations" / "20260817214845_scanlab_d2_geotag_privacy_boundary_v19.sql").read_text(encoding="utf-8")
all_swift = "\n".join(path.read_text(encoding="utf-8") for path in sorted(SOURCE_ROOT.rglob("*.swift")))

checks = {
    "UI uses trusted publish package": "backend.publishTrustedPackage(" in view,
    "app has no legacy publish callsites": re.search(r"\.publish\s*\(\s*resultURL\s*:", all_swift) is None,
    "public copy states location is optional": "位置情報を付けなくてもDiscoverへ公開できます" in view,
    "visibility copy matches optional Map behavior": "位置情報を明示的に付与した場合だけMapにも表示されます" in view,
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
