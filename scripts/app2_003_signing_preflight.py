#!/usr/bin/env python3
"""Read-only Apple signing inventory for APP2-003 夜の書架.

No certificate/profile mutations are allowed here. Credential material is supplied
only through environment variables and is never written to output.
"""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import load_private_key, make_token

ASC_BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "io.github.allsunday1122.yorunoshoka"
COMMAND = Path("automation/chatgpt-dispatcher/app-development-2/runtime/APP2-003-signing-preflight-command.json")
OUTPUT = Path("app2-003-signing-preflight-result.json")


def call(token: str, path: str):
    req = urllib.request.Request(
        ASC_BASE + path,
        method="GET",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw[:700]}
        return exc.code, parsed


def items(payload):
    data = payload.get("data") if isinstance(payload, dict) else None
    return data if isinstance(data, list) else []


def attrs(resource):
    value = resource.get("attributes") if isinstance(resource, dict) else None
    return value if isinstance(value, dict) else {}


def main() -> int:
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    if not request_id.startswith("app2-003-signing-preflight-") or command.get("action") != "inspect":
        raise RuntimeError("invalid APP2-003 signing preflight command")

    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    if not issuer_id or not key_id:
        raise RuntimeError("ASC credential identifiers unavailable")

    result = {
        "request_id": request_id,
        "action": "inspect",
        "bundle_id": BUNDLE_ID,
        "ok": False,
        "completed_at": None,
    }
    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        query = urllib.parse.urlencode({"filter[identifier]": BUNDLE_ID, "limit": "20"})
        status, bundle_payload = call(token, f"/v1/bundleIds?{query}")
        if status != 200:
            raise RuntimeError(f"bundle lookup failed: HTTP {status}")
        bundles = items(bundle_payload)
        if len(bundles) != 1:
            raise RuntimeError(f"expected one bundle resource, found {len(bundles)}")
        bundle_resource_id = str(bundles[0].get("id"))
        result["bundle_resource_id"] = bundle_resource_id

        status, cert_payload = call(token, "/v1/certificates?limit=200")
        if status != 200:
            raise RuntimeError(f"certificate inventory failed: HTTP {status}")
        certs = items(cert_payload)

        status, profile_payload = call(token, "/v1/profiles?limit=200")
        if status != 200:
            raise RuntimeError(f"profile inventory failed: HTTP {status}")
        profiles = items(profile_payload)

        profile_summaries = []
        cert_users: dict[str, list[dict]] = {}
        target_profiles = []
        for profile in profiles:
            pid = str(profile.get("id"))
            pa = attrs(profile)
            bs, bp = call(token, f"/v1/profiles/{pid}/bundleId")
            bundle_res = bp.get("data") if bs == 200 and isinstance(bp, dict) else None
            profile_bundle_resource_id = str(bundle_res.get("id")) if isinstance(bundle_res, dict) and bundle_res.get("id") else None
            profile_bundle_identifier = attrs(bundle_res).get("identifier") if isinstance(bundle_res, dict) else None

            cs, cp = call(token, f"/v1/profiles/{pid}/relationships/certificates?limit=50")
            cert_ids = [str(x.get("id")) for x in items(cp) if x.get("id")] if cs == 200 else []
            summary = {
                "id": pid,
                "name": pa.get("name"),
                "profile_type": pa.get("profileType"),
                "state": pa.get("profileState"),
                "expiration": pa.get("expirationDate"),
                "bundle_resource_id": profile_bundle_resource_id,
                "bundle_identifier": profile_bundle_identifier,
                "certificate_ids": cert_ids,
            }
            profile_summaries.append(summary)
            if profile_bundle_resource_id == bundle_resource_id and pa.get("profileType") == "IOS_APP_STORE":
                target_profiles.append(summary)
            for cid in cert_ids:
                cert_users.setdefault(cid, []).append({
                    "profile_id": pid,
                    "profile_name": pa.get("name"),
                    "profile_state": pa.get("profileState"),
                    "profile_type": pa.get("profileType"),
                    "bundle_identifier": profile_bundle_identifier,
                })

        distribution = []
        now = datetime.now(timezone.utc)
        for cert in certs:
            ca = attrs(cert)
            ctype = ca.get("certificateType")
            if ctype not in {"DISTRIBUTION", "IOS_DISTRIBUTION"}:
                continue
            cid = str(cert.get("id"))
            expiration = ca.get("expirationDate")
            active = ca.get("activated") is not False
            not_expired = True
            if expiration:
                try:
                    not_expired = datetime.fromisoformat(str(expiration).replace("Z", "+00:00")) > now
                except ValueError:
                    pass
            distribution.append({
                "id": cid,
                "type": ctype,
                "active": active,
                "not_expired": not_expired,
                "expiration": expiration,
                "profile_users": cert_users.get(cid, []),
            })

        active_distribution = [c for c in distribution if c["active"] and c["not_expired"]]
        result.update({
            "certificate_count_total": len(certs),
            "distribution_certificates": distribution,
            "active_distribution_count": len(active_distribution),
            "profile_count_total": len(profiles),
            "target_app_store_profiles": target_profiles,
            "target_active_app_store_profiles": [p for p in target_profiles if p.get("state") == "ACTIVE"],
            "ok": True,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        })
        return 0
    except Exception as exc:
        result["error"] = str(exc)
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        return 1
    finally:
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if cleanup:
            cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
