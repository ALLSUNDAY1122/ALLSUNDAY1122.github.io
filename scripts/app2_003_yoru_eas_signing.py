#!/usr/bin/env python3
"""Safely inspect/transfer Yoru no Shoka iOS signing material from EAS to Codemagic.

Secrets are read only from GitHub Actions environment variables or Expo GraphQL,
kept in memory / an ephemeral tempfile, and never written to Git or result JSON.
The transfer is allowed only when EAS records identify the exact Apple certificate
and provisioning profile already verified for Yoru no Shoka.
"""
from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

COMMAND = Path("automation/app2-003-yoru-eas-signing-command.json")
OUTPUT = Path("app2-003-yoru-eas-signing-result.json")
EXPO_GRAPHQL = "https://api.expo.dev/graphql"
CM_BASE = "https://codemagic.io"

EXPECTED = {
    "project_full_name": "@allsunday1122/yoru-no-shoka",
    "eas_project_id": "f1a46391-1511-49ef-bfc6-846e4df70735",
    "bundle_id": "io.github.allsunday1122.yorunoshoka",
    "apple_certificate_id": "B4WRC3G6V4",
    "apple_profile_id": "6598LFYDY3",
    "codemagic_app_id": "6a8af6e5a5c86907b00c2efd",
    "codemagic_group_name": "app2_003_yoru_signing",
}
REQUEST_RE = re.compile(r"^app2-003-yoru-eas-signing-[A-Za-z0-9._-]{1,80}$")

QUERY = r"""
query YoruIosCredentials($projectFullName: String!) {
  app {
    byFullName(fullName: $projectFullName) {
      id
      iosAppCredentials {
        id
        appleAppIdentifier {
          id
          bundleIdentifier
        }
        iosAppBuildCredentialsList {
          id
          iosDistributionType
          distributionCertificate {
            id
            certificateP12
            certificatePassword
            serialNumber
            developerPortalIdentifier
            validityNotBefore
            validityNotAfter
          }
          provisioningProfile {
            id
            developerPortalIdentifier
            expiration
            status
            provisioningProfile
          }
        }
      }
    }
  }
}
"""


def http_json(url: str, method: str, headers: dict[str, str], payload: dict | None = None):
    body = None if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        # Do not persist arbitrary remote error bodies because they may contain sensitive values.
        return exc.code, {"error": "remote_request_failed"}


def expo_query(token: str) -> dict:
    status, payload = http_json(
        EXPO_GRAPHQL,
        "POST",
        {"Authorization": f"Bearer {token}", "Content-Type": "application/json", "Accept": "application/json"},
        {"query": QUERY, "variables": {"projectFullName": EXPECTED["project_full_name"]}},
    )
    if status != 200:
        raise RuntimeError(f"Expo GraphQL HTTP {status}")
    errors = payload.get("errors") if isinstance(payload, dict) else None
    if errors:
        safe_messages = [str(x.get("message", "GraphQL error"))[:180] for x in errors if isinstance(x, dict)]
        raise RuntimeError("Expo GraphQL error: " + "; ".join(safe_messages[:3]))
    return payload


def resolve_target(payload: dict) -> dict:
    app = (((payload.get("data") or {}).get("app") or {}).get("byFullName") or {})
    if not isinstance(app, dict) or not app.get("id"):
        raise RuntimeError("EAS project could not be resolved by full name")
    if str(app.get("id")) != EXPECTED["eas_project_id"]:
        raise RuntimeError("EAS project id mismatch")

    candidates: list[dict] = []
    for credentials in app.get("iosAppCredentials") or []:
        if not isinstance(credentials, dict):
            continue
        identifier = credentials.get("appleAppIdentifier") or {}
        if identifier.get("bundleIdentifier") != EXPECTED["bundle_id"]:
            continue
        for build_credentials in credentials.get("iosAppBuildCredentialsList") or []:
            if isinstance(build_credentials, dict):
                candidates.append(build_credentials)

    matching = []
    for item in candidates:
        cert = item.get("distributionCertificate") or {}
        profile = item.get("provisioningProfile") or {}
        if (
            cert.get("developerPortalIdentifier") == EXPECTED["apple_certificate_id"]
            and profile.get("developerPortalIdentifier") == EXPECTED["apple_profile_id"]
        ):
            matching.append(item)
    if len(matching) != 1:
        raise RuntimeError(f"Expected exactly one EAS credential record matching Apple certificate/profile; found {len(matching)}")
    target = matching[0]
    cert = target.get("distributionCertificate") or {}
    profile = target.get("provisioningProfile") or {}
    if not cert.get("certificateP12") or not cert.get("certificatePassword"):
        raise RuntimeError("Matching EAS certificate does not contain recoverable P12/password")
    if not profile.get("provisioningProfile"):
        raise RuntimeError("Matching EAS provisioning profile content is unavailable")
    return target


def cm_call(token: str, method: str, path: str, payload: dict | None = None):
    return http_json(
        CM_BASE + path,
        method,
        {"x-auth-token": token, "Content-Type": "application/json", "Accept": "application/json"},
        payload,
    )


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


def group_id_for(payload, group_name: str) -> str | None:
    for group in list_items(payload):
        if not isinstance(group, dict):
            continue
        if (group.get("name") or group.get("group_name")) == group_name:
            value = group.get("id") or group.get("_id")
            return str(value) if value else None
    return None


def extract_private_key(certificate_p12_b64: str, password: str) -> str:
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(prefix="yoru-dist-", suffix=".p12", delete=False) as f:
            tmp_path = f.name
            f.write(base64.b64decode(certificate_p12_b64, validate=True))
        os.chmod(tmp_path, 0o600)
        env = os.environ.copy()
        env["YORU_P12_PASSWORD"] = password
        proc = subprocess.run(
            ["openssl", "pkcs12", "-in", tmp_path, "-nocerts", "-nodes", "-passin", "env:YORU_P12_PASSWORD"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=env,
        )
        if proc.returncode != 0 or "PRIVATE KEY" not in proc.stdout:
            raise RuntimeError("EAS P12 private-key extraction failed")
        return proc.stdout
    finally:
        if tmp_path:
            try:
                Path(tmp_path).unlink(missing_ok=True)
            except Exception:
                pass


def store_private_key(cm_token: str, private_key: str) -> dict:
    app_id = EXPECTED["codemagic_app_id"]
    group_name = EXPECTED["codemagic_group_name"]
    status, groups = cm_call(cm_token, "GET", f"/api/v3/apps/{app_id}/variable-groups")
    if status != 200:
        raise RuntimeError(f"Codemagic variable-group inventory failed: HTTP {status}")
    group_id = group_id_for(groups, group_name)
    if group_id:
        status, variables = cm_call(cm_token, "GET", f"/api/v3/variable-groups/{group_id}/variables")
        if status != 200:
            raise RuntimeError(f"Codemagic variable inventory failed: HTTP {status}")
        names = sorted(str(v.get("name")) for v in list_items(variables) if isinstance(v, dict) and v.get("name"))
        if "CERTIFICATE_PRIVATE_KEY" in names:
            return {"group_id": group_id, "created": False, "already_present": True, "variable_names": names}
        # Existing same-name group without the expected secret is safe to complete.
    else:
        status, created = cm_call(cm_token, "POST", f"/api/v3/apps/{app_id}/variable-groups", {"name": group_name})
        if status != 201:
            raise RuntimeError(f"Codemagic variable-group creation failed: HTTP {status}")
        data = created.get("data") if isinstance(created, dict) else None
        if isinstance(data, dict):
            value = data.get("id") or data.get("_id")
            group_id = str(value) if value else None
        if not group_id:
            status, groups = cm_call(cm_token, "GET", f"/api/v3/apps/{app_id}/variable-groups")
            if status == 200:
                group_id = group_id_for(groups, group_name)
        if not group_id:
            raise RuntimeError("Codemagic variable-group id could not be resolved")

    status, _ = cm_call(
        cm_token,
        "POST",
        f"/api/v3/variable-groups/{group_id}/variables",
        {"secure": True, "variables": [{"name": "CERTIFICATE_PRIVATE_KEY", "value": private_key}]},
    )
    if status != 201:
        raise RuntimeError(f"Codemagic secure private-key insertion failed: HTTP {status}")
    status, variables = cm_call(cm_token, "GET", f"/api/v3/variable-groups/{group_id}/variables")
    if status != 200:
        raise RuntimeError(f"Codemagic secret read-back failed: HTTP {status}")
    names = sorted(str(v.get("name")) for v in list_items(variables) if isinstance(v, dict) and v.get("name"))
    if "CERTIFICATE_PRIVATE_KEY" not in names:
        raise RuntimeError("Codemagic secure variable name missing after insertion")
    return {"group_id": group_id, "created": True, "already_present": False, "variable_names": names}


def main() -> int:
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    action = command.get("action")
    if not REQUEST_RE.fullmatch(request_id):
        raise RuntimeError("Invalid request_id")
    if action not in {"inspect", "transfer"}:
        raise RuntimeError("action must be inspect or transfer")
    for key, expected in EXPECTED.items():
        if str(command.get(key)) != expected:
            raise RuntimeError(f"Command target mismatch: {key}")

    expo_token = os.environ.get("EXPO_TOKEN", "").strip()
    if not expo_token:
        raise RuntimeError("EXPO_TOKEN is unavailable")

    payload = expo_query(expo_token)
    target = resolve_target(payload)
    cert = target.get("distributionCertificate") or {}
    profile = target.get("provisioningProfile") or {}
    result = {
        "request_id": request_id,
        "action": action,
        "ok": True,
        "eas_project_id": EXPECTED["eas_project_id"],
        "project_full_name": EXPECTED["project_full_name"],
        "bundle_id": EXPECTED["bundle_id"],
        "ios_distribution_type": target.get("iosDistributionType"),
        "apple_certificate_id": cert.get("developerPortalIdentifier"),
        "apple_profile_id": profile.get("developerPortalIdentifier"),
        "certificate_serial_number": cert.get("serialNumber"),
        "certificate_validity_not_before": cert.get("validityNotBefore"),
        "certificate_validity_not_after": cert.get("validityNotAfter"),
        "profile_expiration": profile.get("expiration"),
        "profile_status": profile.get("status"),
        "eas_has_certificate_p12": bool(cert.get("certificateP12")),
        "eas_has_certificate_password": bool(cert.get("certificatePassword")),
        "eas_has_provisioning_profile": bool(profile.get("provisioningProfile")),
        "codemagic_app_id": EXPECTED["codemagic_app_id"],
        "codemagic_group_name": EXPECTED["codemagic_group_name"],
        "private_key_transferred": False,
    }

    if action == "transfer":
        cm_token = os.environ.get("CM_API_TOKEN", "").strip()
        if not cm_token:
            raise RuntimeError("CM_API_TOKEN is unavailable")
        private_key = extract_private_key(cert["certificateP12"], cert["certificatePassword"])
        cm_result = store_private_key(cm_token, private_key)
        # Drop private-key string as soon as possible; it is never serialized.
        private_key = ""
        result.update(
            {
                "private_key_transferred": True,
                "codemagic_group_id": cm_result["group_id"],
                "codemagic_group_created": cm_result["created"],
                "codemagic_secret_already_present": cm_result["already_present"],
                "codemagic_variable_names": cm_result["variable_names"],
            }
        )

    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PASS: Yoru EAS signing identity verified" + (" and transferred" if action == "transfer" else ""))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        # Persist only a bounded error message; no raw remote payloads or secrets.
        try:
            request_id = "unknown"
            action = None
            if COMMAND.exists():
                command = json.loads(COMMAND.read_text(encoding="utf-8"))
                request_id = str(command.get("request_id", "unknown"))
                action = command.get("action")
            OUTPUT.write_text(
                json.dumps({"request_id": request_id, "action": action, "ok": False, "error": str(exc)[:500]}, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        except Exception:
            pass
        print(f"FAIL: {type(exc).__name__}: {str(exc)[:300]}")
        raise
