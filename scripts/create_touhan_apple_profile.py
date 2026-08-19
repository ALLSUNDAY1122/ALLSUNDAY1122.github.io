#!/usr/bin/env python3
"""Create/read-back the Touhan App Store provisioning profile without exposing secrets."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

COMMAND = Path("automation/app2-010-touhan-apple-profile-command.json")
OUTPUT = Path("asc-profile-result.json")
EXPECTED_APP_ID = "6802119268"
EXPECTED_BUNDLE_ID = "com.allsunday1122.tourokuhanbaisha"
EXPECTED_BUNDLE_RESOURCE_ID = "M3U25P6GK3"
EXPECTED_CERTIFICATE_ID = "MLDDAKTU69"
EXPECTED_PROFILE_NAME = "tourokuhanbaisha_appstore"
EXPECTED_PROFILE_TYPE = "IOS_APP_STORE"


def one(response: object, label: str) -> dict:
    if not isinstance(response, dict) or not isinstance(response.get("data"), dict):
        raise RuntimeError(f"{label} response has no single data resource")
    return response["data"]


def list_data(response: object) -> list[dict]:
    if not isinstance(response, dict):
        return []
    data = response.get("data")
    return [x for x in data if isinstance(x, dict)] if isinstance(data, list) else []


def attrs(resource: dict) -> dict:
    value = resource.get("attributes")
    return value if isinstance(value, dict) else {}


def main() -> int:
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    if not request_id.startswith("app2-010-touhan-profile-"):
        raise RuntimeError("Unexpected request_id")
    expected = {
        "app_id": EXPECTED_APP_ID,
        "bundle_id": EXPECTED_BUNDLE_ID,
        "bundle_resource_id": EXPECTED_BUNDLE_RESOURCE_ID,
        "certificate_id": EXPECTED_CERTIFICATE_ID,
        "profile_name": EXPECTED_PROFILE_NAME,
        "profile_type": EXPECTED_PROFILE_TYPE,
    }
    for key, value in expected.items():
        if str(command.get(key)) != value:
            raise RuntimeError(f"Command mismatch for {key}")

    import os
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise RuntimeError("Missing App Store Connect credential identifiers")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)

        _, app_response = api_get(token, f"/v1/apps/{EXPECTED_APP_ID}")
        app = one(app_response, "app")
        if attrs(app).get("bundleId") != EXPECTED_BUNDLE_ID:
            raise RuntimeError("App preflight bundle mismatch")

        _, bundle_response = api_get(token, f"/v1/bundleIds/{EXPECTED_BUNDLE_RESOURCE_ID}")
        bundle = one(bundle_response, "bundle")
        if attrs(bundle).get("identifier") != EXPECTED_BUNDLE_ID:
            raise RuntimeError("Bundle resource identifier mismatch")

        _, cert_response = api_get(token, f"/v1/certificates/{EXPECTED_CERTIFICATE_ID}")
        cert = one(cert_response, "certificate")
        cert_attrs = attrs(cert)
        if cert_attrs.get("activated") is False:
            raise RuntimeError("Selected distribution certificate is inactive")
        if cert_attrs.get("certificateType") not in {"DISTRIBUTION", "IOS_DISTRIBUTION"}:
            raise RuntimeError(f"Unexpected certificate type: {cert_attrs.get('certificateType')!r}")

        _, profiles_response = api_get(
            token,
            f"/v1/profiles?filter[name]={EXPECTED_PROFILE_NAME}&include=bundleId,certificates&limit=20",
        )
        profile = None
        changed = False
        for candidate in list_data(profiles_response):
            candidate_attrs = attrs(candidate)
            if candidate_attrs.get("name") == EXPECTED_PROFILE_NAME:
                if candidate_attrs.get("profileType") != EXPECTED_PROFILE_TYPE:
                    raise RuntimeError("Existing profile name has unexpected profile type")
                profile = candidate
                break

        if profile is None:
            payload = {
                "data": {
                    "type": "profiles",
                    "attributes": {
                        "name": EXPECTED_PROFILE_NAME,
                        "profileType": EXPECTED_PROFILE_TYPE,
                    },
                    "relationships": {
                        "bundleId": {
                            "data": {"type": "bundleIds", "id": EXPECTED_BUNDLE_RESOURCE_ID}
                        },
                        "certificates": {
                            "data": [{"type": "certificates", "id": EXPECTED_CERTIFICATE_ID}]
                        },
                    },
                }
            }
            status, create_response = api_request(token, "/v1/profiles", method="POST", payload=payload)
            if status != 201:
                raise RuntimeError(f"Unexpected profile creation status: {status}")
            profile = one(create_response, "created profile")
            changed = True

        profile_id = str(profile.get("id"))
        _, readback_response = api_get(token, f"/v1/profiles/{profile_id}")
        readback = one(readback_response, "profile read-back")
        readback_attrs = attrs(readback)
        if readback_attrs.get("name") != EXPECTED_PROFILE_NAME:
            raise RuntimeError("Profile read-back name mismatch")
        if readback_attrs.get("profileType") != EXPECTED_PROFILE_TYPE:
            raise RuntimeError("Profile read-back type mismatch")
        if readback_attrs.get("profileState") != "ACTIVE":
            raise RuntimeError(f"Profile is not ACTIVE: {readback_attrs.get('profileState')!r}")

        _, rb_bundle_response = api_get(token, f"/v1/profiles/{profile_id}/bundleId")
        rb_bundle = one(rb_bundle_response, "profile bundle read-back")
        if str(rb_bundle.get("id")) != EXPECTED_BUNDLE_RESOURCE_ID:
            raise RuntimeError("Profile bundle relationship mismatch")

        _, rb_certs_response = api_get(token, f"/v1/profiles/{profile_id}/certificates")
        rb_cert_ids = {str(x.get("id")) for x in list_data(rb_certs_response)}
        if EXPECTED_CERTIFICATE_ID not in rb_cert_ids:
            raise RuntimeError("Profile certificate relationship mismatch")

        result = {
            "request_id": request_id,
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "ok": True,
            "changed": changed,
            "app_id": EXPECTED_APP_ID,
            "bundle_id": EXPECTED_BUNDLE_ID,
            "bundle_resource_id": EXPECTED_BUNDLE_RESOURCE_ID,
            "certificate_id": EXPECTED_CERTIFICATE_ID,
            "certificate_name": cert_attrs.get("name"),
            "certificate_type": cert_attrs.get("certificateType"),
            "certificate_expiration": cert_attrs.get("expirationDate"),
            "profile_id": profile_id,
            "profile_name": readback_attrs.get("name"),
            "profile_type": readback_attrs.get("profileType"),
            "profile_state": readback_attrs.get("profileState"),
            "profile_expiration": readback_attrs.get("expirationDate"),
            "relationship_bundle_id": str(rb_bundle.get("id")),
            "relationship_certificate_ids": sorted(rb_cert_ids),
        }
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: profile_id={profile_id} changed={changed} state={readback_attrs.get('profileState')}")
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
