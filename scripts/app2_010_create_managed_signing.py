#!/usr/bin/env python3
"""Provision an APP2-010 signing identity without exposing signing secrets.

Safety rules:
- Never touches the shared MLDDAKTU69 certificate.
- Revokes 27TTVLZ65A only when it is used solely by the old AI Handover profile
  and the replacement AI Handover profile on MLDDAKTU69 is ACTIVE.
- Stores the newly generated RSA private key directly as a secure Codemagic
  app variable; the private key is never written to Git or the result JSON.
- Keeps App Store review submission out of scope.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import load_private_key, make_token

ASC_BASE = "https://api.appstoreconnect.apple.com"
CM_BASE = "https://codemagic.io"
COMMAND = Path("automation/app2-010-managed-signing-command.json")
OUTPUT = Path("app2-010-managed-signing-result.json")

EXPECTED = {
    "app_store_connect_app_id": "6802119268",
    "bundle_id": "com.allsunday1122.tourokuhanbaisha",
    "bundle_resource_id": "M3U25P6GK3",
    "codemagic_app_id": "6a769d81a1add9d06020b524",
    "codemagic_group_name": "app2_010_touhan_signing",
    "canonical_profile_name": "tourokuhanbaisha_appstore",
    "current_touhan_profile_id": "NW45QQKK8G",
    "old_ai_certificate_id": "27TTVLZ65A",
    "old_ai_profile_id": "S6KQM8G9K9",
    "shared_certificate_id": "MLDDAKTU69",
    "protected_ai_profile_id": "4Z25F68APA",
}
TEMP_PROFILE_NAME = "tourokuhanbaisha_appstore_cmkey_temp"


def response_data(payload):
    return payload.get("data") if isinstance(payload, dict) else None


def attrs(resource):
    value = resource.get("attributes") if isinstance(resource, dict) else None
    return value if isinstance(value, dict) else {}


def list_items(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("data", "variable_groups", "groups", "variables"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
            if isinstance(value, dict):
                for nested in ("data", "items", "groups", "variables"):
                    nested_value = value.get(nested)
                    if isinstance(nested_value, list):
                        return nested_value
    return []


def asc_call(token: str, method: str, path: str, payload=None):
    body = None if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(ASC_BASE + path, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw[:1000]}
        return exc.code, parsed


def cm_call(token: str, method: str, path: str, payload=None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        CM_BASE + path,
        data=body,
        method=method,
        headers={"x-auth-token": token, "Accept": "application/json", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw[:700]}
        return exc.code, parsed


def single(payload, label: str):
    data = response_data(payload)
    if not isinstance(data, dict):
        raise RuntimeError(f"{label}: expected a single resource")
    return data


def profile_cert_ids(token: str, profile_id: str) -> set[str]:
    status, payload = asc_call(token, "GET", f"/v1/profiles/{profile_id}/relationships/certificates?limit=200")
    if status != 200:
        raise RuntimeError(f"profile certificate read failed for {profile_id}: HTTP {status}")
    return {str(item.get("id")) for item in list_items(payload) if isinstance(item, dict) and item.get("id")}


def create_profile(token: str, name: str, bundle_resource_id: str, certificate_id: str):
    payload = {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    }
    status, response = asc_call(token, "POST", "/v1/profiles", payload)
    if status != 201:
        raise RuntimeError(f"profile create failed ({name}): HTTP {status}; {str(response)[:700]}")
    return single(response, f"profile {name}")


def verify_profile(token: str, profile_id: str, expected_name: str, expected_bundle_id: str, expected_certificate_id: str):
    status, response = asc_call(token, "GET", f"/v1/profiles/{profile_id}")
    if status != 200:
        raise RuntimeError(f"profile read-back failed: HTTP {status}")
    profile = single(response, "profile read-back")
    pa = attrs(profile)
    if pa.get("name") != expected_name or pa.get("profileType") != "IOS_APP_STORE" or pa.get("profileState") != "ACTIVE":
        raise RuntimeError(f"profile read-back mismatch: {profile_id}")
    status, bundle_response = asc_call(token, "GET", f"/v1/profiles/{profile_id}/bundleId")
    if status != 200 or str(single(bundle_response, "profile bundle").get("id")) != expected_bundle_id:
        raise RuntimeError("profile bundle relationship mismatch")
    if expected_certificate_id not in profile_cert_ids(token, profile_id):
        raise RuntimeError("profile certificate relationship mismatch")
    return pa


def cm_group_id(payload, target_name: str):
    for group in list_items(payload):
        if not isinstance(group, dict):
            continue
        name = group.get("name") or group.get("group_name")
        if name == target_name:
            return str(group.get("id") or group.get("_id") or "") or None
    return None


def main() -> int:
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    if not re.fullmatch(r"app2-010-managed-signing-[A-Za-z0-9._-]{1,60}", request_id):
        raise RuntimeError("unexpected request_id")
    for key, expected in EXPECTED.items():
        if str(command.get(key)) != expected:
            raise RuntimeError(f"command mismatch: {key}")

    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    asc_key_id = os.environ.get("ASC_KEY_ID", "").strip()
    cm_token = os.environ.get("CM_API_TOKEN", "").strip()
    if not issuer_id or not asc_key_id or not cm_token:
        raise RuntimeError("required credential identifiers are unavailable")

    result = {
        "request_id": request_id,
        "completed_at": None,
        "ok": False,
        "bundle_id": EXPECTED["bundle_id"],
        "codemagic_group_name": EXPECTED["codemagic_group_name"],
        "shared_certificate_untouched": EXPECTED["shared_certificate_id"],
        "old_certificate_id": EXPECTED["old_ai_certificate_id"],
    }
    asc_key_path, asc_cleanup = load_private_key()
    signing_key_path = None
    csr_path = None
    new_certificate_id = None
    new_group_id = None
    secret_stored = False
    temp_profile_id = None
    canonical_profile_id = None
    try:
        token = make_token(issuer_id, asc_key_id, asc_key_path)

        # Canonical bundle and protected AI Handover profile must be intact before any revocation.
        status, bundle_response = asc_call(token, "GET", f"/v1/bundleIds/{EXPECTED['bundle_resource_id']}")
        if status != 200 or attrs(single(bundle_response, "Touhan bundle")).get("identifier") != EXPECTED["bundle_id"]:
            raise RuntimeError("Touhan bundle preflight mismatch")
        verify_profile(
            token,
            EXPECTED["protected_ai_profile_id"],
            "AI_Handover_Log_AppStore_MLD",
            "B7R8MY8GK8",
            EXPECTED["shared_certificate_id"],
        )

        # Audit every provisioning profile live. The revocation candidate must be isolated to old AI Handover.
        status, profiles_response = asc_call(token, "GET", "/v1/profiles?limit=200")
        if status != 200:
            raise RuntimeError(f"profile inventory failed: HTTP {status}")
        profiles = list_items(profiles_response)
        old_cert_users = []
        for profile in profiles:
            pid = str(profile.get("id"))
            if EXPECTED["old_ai_certificate_id"] in profile_cert_ids(token, pid):
                old_cert_users.append(pid)
        result["preflight_profile_count"] = len(profiles)
        result["old_certificate_profile_users"] = sorted(old_cert_users)
        if set(old_cert_users) != {EXPECTED["old_ai_profile_id"]}:
            raise RuntimeError(f"revocation blocked; unexpected profiles use old certificate: {old_cert_users}")

        # Ensure the target Codemagic secret group is absent before starting a new managed identity.
        cm_status, cm_groups = cm_call(cm_token, "GET", f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups")
        if cm_status != 200:
            raise RuntimeError(f"Codemagic group inventory failed: HTTP {cm_status}")
        existing_group = cm_group_id(cm_groups, EXPECTED["codemagic_group_name"])
        if existing_group:
            raise RuntimeError(f"managed signing group already exists: {existing_group}; refusing duplicate rotation")

        # Generate the private key and CSR in the ephemeral GitHub Actions filesystem only.
        tmpdir = Path(tempfile.mkdtemp(prefix="app2-010-signing-"))
        signing_key_path = tmpdir / "distribution_private_key.pem"
        csr_path = tmpdir / "distribution.csr"
        os.chmod(tmpdir, 0o700)
        subprocess.run(["openssl", "genrsa", "-traditional", "-out", str(signing_key_path), "2048"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        os.chmod(signing_key_path, 0o600)
        subprocess.run(
            ["openssl", "req", "-new", "-key", str(signing_key_path), "-out", str(csr_path), "-subj", "/CN=APP2-010 Touhan Codemagic/O=ALLSUNDAY1122/C=JP"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        csr_content = csr_path.read_text(encoding="utf-8")
        private_key_text = signing_key_path.read_text(encoding="utf-8")
        if "PRIVATE KEY" not in private_key_text or "CERTIFICATE REQUEST" not in csr_content:
            raise RuntimeError("generated signing material failed local validation")

        # Free exactly one distribution-certificate slot after the dependency audit above.
        revoke_status, revoke_response = asc_call(token, "DELETE", f"/v1/certificates/{EXPECTED['old_ai_certificate_id']}")
        if revoke_status != 204:
            raise RuntimeError(f"old certificate revocation failed: HTTP {revoke_status}; {str(revoke_response)[:500]}")
        result["old_certificate_revoked"] = True

        # Create a new Apple Distribution certificate whose private key is under this workflow's control.
        cert_payload = {
            "data": {
                "type": "certificates",
                "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_content},
            }
        }
        cert_status, cert_response = asc_call(token, "POST", "/v1/certificates", cert_payload)
        if cert_status != 201:
            raise RuntimeError(f"new distribution certificate create failed: HTTP {cert_status}; {str(cert_response)[:700]}")
        cert = single(cert_response, "new distribution certificate")
        new_certificate_id = str(cert.get("id"))
        ca = attrs(cert)
        if not new_certificate_id or ca.get("certificateType") != "DISTRIBUTION" or ca.get("activated") is False:
            raise RuntimeError("new distribution certificate read-back mismatch")
        result["new_certificate_id"] = new_certificate_id
        result["new_certificate_expiration"] = ca.get("expirationDate")

        # Persist the private key directly into Codemagic encrypted app variables before profile replacement.
        create_group_status, create_group_response = cm_call(
            cm_token,
            "POST",
            f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups",
            {"name": EXPECTED["codemagic_group_name"]},
        )
        if create_group_status != 201:
            raise RuntimeError(f"Codemagic managed group create failed: HTTP {create_group_status}")
        data = response_data(create_group_response)
        if isinstance(data, dict):
            new_group_id = str(data.get("id") or data.get("_id") or "") or None
        if not new_group_id:
            check_status, check_groups = cm_call(cm_token, "GET", f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups")
            if check_status == 200:
                new_group_id = cm_group_id(check_groups, EXPECTED["codemagic_group_name"])
        if not new_group_id:
            raise RuntimeError("Codemagic managed group id could not be resolved")
        result["codemagic_group_id"] = new_group_id

        secret_status, _ = cm_call(
            cm_token,
            "POST",
            f"/api/v3/variable-groups/{new_group_id}/variables",
            {"secure": True, "variables": [{"name": "CERTIFICATE_PRIVATE_KEY", "value": private_key_text}]},
        )
        if secret_status != 201:
            raise RuntimeError(f"Codemagic private-key secret insert failed: HTTP {secret_status}")
        secret_stored = True
        result["private_key_stored_as_secure_variable"] = True
        vars_status, vars_response = cm_call(cm_token, "GET", f"/api/v3/variable-groups/{new_group_id}/variables")
        if vars_status != 200:
            raise RuntimeError(f"Codemagic secret read-back failed: HTTP {vars_status}")
        variable_names = sorted(str(v.get("name")) for v in list_items(vars_response) if isinstance(v, dict) and v.get("name"))
        if "CERTIFICATE_PRIVATE_KEY" not in variable_names:
            raise RuntimeError("Codemagic secret name missing after write")
        result["codemagic_variable_names"] = variable_names

        # Build a temporary ACTIVE Touhan profile first, then atomically replace the canonical profile name.
        temp = create_profile(token, TEMP_PROFILE_NAME, EXPECTED["bundle_resource_id"], new_certificate_id)
        temp_profile_id = str(temp.get("id"))
        verify_profile(token, temp_profile_id, TEMP_PROFILE_NAME, EXPECTED["bundle_resource_id"], new_certificate_id)
        result["temporary_profile_id"] = temp_profile_id

        delete_old_status, delete_old_response = asc_call(token, "DELETE", f"/v1/profiles/{EXPECTED['current_touhan_profile_id']}")
        if delete_old_status != 204:
            raise RuntimeError(f"old Touhan profile deletion failed: HTTP {delete_old_status}; {str(delete_old_response)[:500]}")
        result["old_touhan_profile_deleted"] = EXPECTED["current_touhan_profile_id"]

        canonical = create_profile(token, EXPECTED["canonical_profile_name"], EXPECTED["bundle_resource_id"], new_certificate_id)
        canonical_profile_id = str(canonical.get("id"))
        canonical_attrs = verify_profile(
            token,
            canonical_profile_id,
            EXPECTED["canonical_profile_name"],
            EXPECTED["bundle_resource_id"],
            new_certificate_id,
        )
        result["canonical_profile_id"] = canonical_profile_id
        result["canonical_profile_state"] = canonical_attrs.get("profileState")
        result["canonical_profile_expiration"] = canonical_attrs.get("expirationDate")

        delete_temp_status, _ = asc_call(token, "DELETE", f"/v1/profiles/{temp_profile_id}")
        result["temporary_profile_deleted"] = delete_temp_status == 204
        if delete_temp_status != 204:
            raise RuntimeError(f"temporary Touhan profile cleanup failed: HTTP {delete_temp_status}")
        temp_profile_id = None

        # Final non-secret read-backs.
        cert_read_status, cert_read_response = asc_call(token, "GET", f"/v1/certificates/{new_certificate_id}")
        if cert_read_status != 200 or attrs(single(cert_read_response, "final certificate")).get("activated") is False:
            raise RuntimeError("new certificate is not active at final read-back")
        result["ok"] = True
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        return 0
    except Exception as exc:
        result["error"] = str(exc)
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        # If the new private key was never safely stored, revoke any new certificate and remove a partial group.
        if new_certificate_id and not secret_stored:
            try:
                token = make_token(issuer_id, asc_key_id, asc_key_path)
                cleanup_status, _ = asc_call(token, "DELETE", f"/v1/certificates/{new_certificate_id}")
                result["orphan_new_certificate_cleanup_http_status"] = cleanup_status
            except Exception:
                result["orphan_new_certificate_cleanup_http_status"] = "cleanup_failed"
        if new_group_id and not secret_stored:
            try:
                cleanup_group_status, _ = cm_call(cm_token, "DELETE", f"/api/v3/variable-groups/{new_group_id}")
                result["partial_group_cleanup_http_status"] = cleanup_group_status
            except Exception:
                result["partial_group_cleanup_http_status"] = "cleanup_failed"
        return 1
    finally:
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if signing_key_path:
            try:
                signing_key_path.write_text("", encoding="utf-8")
                signing_key_path.unlink(missing_ok=True)
            except Exception:
                pass
        if csr_path:
            try:
                csr_path.unlink(missing_ok=True)
            except Exception:
                pass
        if asc_cleanup:
            asc_cleanup.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
