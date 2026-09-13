#!/usr/bin/env python3
"""Read-only App Store Connect v2 in-app-purchase metadata probe.

This intentionally exposes only fixed GET relationships for one numeric IAP id.
Credentials remain in GitHub Actions secrets and are never emitted.
"""

import argparse
import json
import os
import re
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

IAP_ID_RE = re.compile(r"^[0-9]{8,20}$")


def probe(token: str, label: str, path: str) -> dict:
    try:
        status, payload = api_get(token, path)
        return {"label": label, "path": path, "ok": True, "status": status, "response": payload}
    except Exception as exc:
        return {"label": label, "path": path, "ok": False, "error": str(exc)[:8000]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iap-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    if not IAP_ID_RE.fullmatch(args.iap_id):
        raise SystemExit("Invalid IAP id")

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing App Store Connect credential metadata")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        base = f"/v2/inAppPurchases/{args.iap_id}"
        requests = [
            ("iap-detail", base),
            ("iap-localizations", base + "/inAppPurchaseLocalizations"),
            ("iap-price-schedule", base + "/iapPriceSchedule"),
            ("iap-review-screenshot", base + "/appStoreReviewScreenshot"),
            ("iap-availability", base + "/inAppPurchaseAvailability"),
        ]
        results = [probe(token, label, path) for label, path in requests]
        payload = {
            "ok": any(item["ok"] for item in results),
            "iap_id": args.iap_id,
            "results": results,
        }
        Path(args.output).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        if not payload["ok"]:
            raise SystemExit("All IAP metadata probes failed")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
