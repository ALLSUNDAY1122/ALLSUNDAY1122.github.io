#!/usr/bin/env python3
"""APP2-003: bridge the existing EAS iOS signing identity into Codemagic safely.

Secret-handling invariants:
- EAS token, Codemagic token, P12, password and private key exist only in the
  ephemeral GitHub Actions process/filesystem.
- No secret value is printed or written to Git/evidence output.
- The bridge refuses any EAS certificate whose Apple developer-portal id does
  not exactly match the already-approved certificate B4WRC3G6V4.
- No Apple certificate/profile is created, rotated or revoked.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

EXPO_GRAPHQL = "https://api.expo.dev/graphql"
CM_BASE = "https://codemagic.io"
COMMAND = Path("automation/app2-003-eas-signing-command.json")
RESULT_DIR = Path("automation/codemagic-results")

EXPECTED = {
    "account_name": "allsunday1122",
    "project_name": "yoru-no-shoka",
    "project_full_name": "@allsunday1122/yoru-no-shoka",
    "bundle_id": "io.github.allsunday1122.yorunoshoka",
    "eas_project_id": "f1a46391-1511-49ef-bfc6-846e4df70735",
    "apple_certificate_id": "B4WRC3G6V4",
    "apple_profile_id": "6598LFYDY3",
    "codemagic_app_id": "6a8af6e5a5c86907b00c2efd",
    "codemagic_group_name": "app2_003_yoru_signing",
}


def expo_query(token: str, query: str, variables: dict) -> dict:
    body = json.dumps({"query": query, "variables": variables}, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(
        EXPO_GRAPHQL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"Expo GraphQL HTTP {exc.code}: {raw[:700]}") from exc
    errors = payload.get("errors") or []
    if errors:
        safe = [{"message": e.get("message"), "extensions": e.get("extensions")} for e in errors if isinstance(e, dict)]
        raise RuntimeError(f"Expo GraphQL returned errors: {safe[:3]}")
    data = payload.get("data")
    if not isinstance(data, dict):
        raise RuntimeError("Expo GraphQL returned no data object")
    return data


def cm_call(token: str, method: str, path: str, payload=None) -> tuple[int, object]:
    body = None if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
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
            parsed = {"raw": raw[:500]}
        return exc.code, parsed


def items(payload) -> list[dict]:
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]
    if isinstance(payload, dict):
        for key in ("data", "variable_groups", "groups", "variables"):
            value = payload.get(key)
            if isinstance(value, list):
                return [x for x in value if isinstance(x, dict)]
            if isinstance(value, dict):
                for nested in ("data", "items", "groups", "variables"):
                    inner = value.get(nested)
                    if isinstance(inner, list):
                        return [x for x in inner if isinstance(x, dict)]
    return []


def run_openssl(args: list[str], *, env: dict | None = None) -> subprocess.CompletedProcess:
    completed = subprocess.run(
        ["openssl", *args],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return completed


def extract_and_verify_private_key(certificate_p12_b64: str, password: str, tmpdir: Path) -> tuple[str, str]:
    try:
        p12 = base64.b64decode(certificate_p12_b64, validate=True)
    except Exception as exc:
        raise RuntimeError("EAS distribution certificate P12 is not valid base64") from exc
    if len(p12) < 500:
        raise RuntimeError("EAS distribution certificate P12 is unexpectedly small")

    p12_path = tmpdir / "dist-cert.p12"
    cert_path = tmpdir / "cert.pem"
    key_raw_path = tmpdir / "key-raw.pem"
    key_path = tmpdir / "private-key.pem"
    p12_path.write_bytes(p12)
    os.chmod(p12_path, 0o600)

    child_env = os.environ.copy()
    child_env["APP2_003_P12_PASSWORD"] = password
    common = ["-in", str(p12_path), "-passin", "env:APP2_003_P12_PASSWORD"]

    def pkcs12(extra: list[str], output: Path) -> None:
        for legacy in (False, True):
            args = ["pkcs12"] + (["-legacy"] if legacy else []) + common + extra + ["-out", str(output)]
            result = run_openssl(args, env=child_env)
            if result.returncode == 0:
                os.chmod(output, 0o600)
                return
        raise RuntimeError("OpenSSL could not read the EAS distribution certificate P12")

    pkcs12(["-clcerts", "-nokeys"], cert_path)
    pkcs12(["-nocerts", "-nodes"], key_raw_path)

    normalized = run_openssl(["pkey", "-in", str(key_raw_path), "-out", str(key_path)])
    if normalized.returncode != 0:
        raise RuntimeError("OpenSSL could not normalize the EAS private key")
    os.chmod(key_path, 0o600)
    checked = run_openssl(["pkey", "-in", str(key_path), "-check", "-noout"])
    if checked.returncode != 0:
        raise RuntimeError("Extracted EAS private key failed OpenSSL validation")

    key_pub = run_openssl(["pkey", "-in", str(key_path), "-pubout"])
    cert_pub = run_openssl(["x509", "-in", str(cert_path), "-pubkey", "-noout"])
    if key_pub.returncode != 0 or cert_pub.returncode != 0:
        raise RuntimeError("Could not derive public keys for signing-key verification")
    if hashlib.sha256(key_pub.stdout).digest() != hashlib.sha256(cert_pub.stdout).digest():
        raise RuntimeError("EAS private key does not match the EAS distribution certificate")

    private_key_text = key_path.read_text(encoding="utf-8")
    if "PRIVATE KEY" not in private_key_text:
        raise RuntimeError("Normalized EAS private key is not PEM")

    serial = run_openssl(["x509", "-in", str(cert_path), "-noout", "-serial"])
    serial_text = serial.stdout.decode("utf-8", "replace").strip().removeprefix("serial=") if serial.returncode == 0 else ""
    return private_key_text, serial_text


def main() -> int:
    cmd = json.loads(COMMAND.read_text(encoding="utf-8"))
    request_id = str(cmd.get("request_id", ""))
    mode = str(cmd.get("mode", ""))
    if not re.fullmatch(r"app2-003-eas-signing-[A-Za-z0-9._-]{1,70}", request_id):
        raise RuntimeError("invalid request_id")
    if mode not in {"probe", "install"}:
        raise RuntimeError("mode must be probe or install")
    for key, expected in EXPECTED.items():
        supplied = cmd.get(key, expected)
        if str(supplied) != expected:
            raise RuntimeError(f"command mismatch: {key}")

    expo_token = os.environ.get("EXPO_TOKEN", "").strip()
    cm_token = os.environ.get("CM_API_TOKEN", "").strip()
    if not expo_token or not cm_token:
        raise RuntimeError("required GitHub Actions credentials are unavailable")

    result = {
        "request_id": request_id,
        "mode": mode,
        "ok": False,
        "bundle_id": EXPECTED["bundle_id"],
        "eas_project_id": EXPECTED["eas_project_id"],
        "expected_apple_certificate_id": EXPECTED["apple_certificate_id"],
        "expected_apple_profile_id": EXPECTED["apple_profile_id"],
        "codemagic_app_id": EXPECTED["codemagic_app_id"],
        "codemagic_group_name": EXPECTED["codemagic_group_name"],
        "secret_values_persisted_to_git": False,
        "apple_certificate_created": False,
        "apple_certificate_revoked": False,
        "apple_profile_created": False,
    }
    created_group_id = None
    tmpdir = Path(tempfile.mkdtemp(prefix="app2-003-eas-signing-"))
    os.chmod(tmpdir, 0o700)
    try:
        identifier_query = """
        query AppleAppIdentifierByBundleIdQuery($accountName: String!, $bundleIdentifier: String!) {
          account {
            byName(accountName: $accountName) {
              id
              appleAppIdentifiers(bundleIdentifier: $bundleIdentifier) { id }
            }
          }
        }
        """
        identifier_data = expo_query(
            expo_token,
            identifier_query,
            {"accountName": EXPECTED["account_name"], "bundleIdentifier": EXPECTED["bundle_id"]},
        )
        account = ((identifier_data.get("account") or {}).get("byName") or {})
        identifiers = account.get("appleAppIdentifiers") or []
        if len(identifiers) != 1 or not identifiers[0].get("id"):
            raise RuntimeError(f"EAS Apple App Identifier did not resolve uniquely: count={len(identifiers)}")
        apple_app_identifier_id = str(identifiers[0]["id"])
        result["eas_apple_app_identifier_resolved"] = True

        credentials_query = """
        query App2YoruCredentials($projectFullName: String!, $appleAppIdentifierId: String!) {
          app {
            byFullName(fullName: $projectFullName) {
              id
              slug
              ownerAccount { name }
              iosAppCredentials(filter: { appleAppIdentifierId: $appleAppIdentifierId }) {
                id
                iosAppBuildCredentialsList(filter: { iosDistributionType: APP_STORE }) {
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
                  }
                }
              }
            }
          }
        }
        """
        credential_data = expo_query(
            expo_token,
            credentials_query,
            {"projectFullName": EXPECTED["project_full_name"], "appleAppIdentifierId": apple_app_identifier_id},
        )
        app = ((credential_data.get("app") or {}).get("byFullName") or {})
        if str(app.get("slug")) != EXPECTED["project_name"]:
            raise RuntimeError("EAS project slug mismatch")
        owner_name = str(((app.get("ownerAccount") or {}).get("name")) or "")
        if owner_name != EXPECTED["account_name"]:
            raise RuntimeError("EAS project owner mismatch")

        builds: list[dict] = []
        for ios_creds in app.get("iosAppCredentials") or []:
            builds.extend(x for x in (ios_creds.get("iosAppBuildCredentialsList") or []) if isinstance(x, dict))
        if len(builds) != 1:
            raise RuntimeError(f"EAS App Store signing credential did not resolve uniquely: count={len(builds)}")
        build_creds = builds[0]
        dist = build_creds.get("distributionCertificate") or {}
        profile = build_creds.get("provisioningProfile") or {}
        developer_cert_id = str(dist.get("developerPortalIdentifier") or "")
        if developer_cert_id != EXPECTED["apple_certificate_id"]:
            raise RuntimeError(
                f"EAS certificate mismatch; expected {EXPECTED['apple_certificate_id']} but got {developer_cert_id or '[missing]'}"
            )
        certificate_p12 = str(dist.get("certificateP12") or "")
        certificate_password = str(dist.get("certificatePassword") or "")
        if not certificate_p12:
            raise RuntimeError("EAS certificate P12 payload is unavailable")
        # Empty PKCS#12 passwords are legal; presence is represented by the GraphQL field itself.
        if "certificatePassword" not in dist:
            raise RuntimeError("EAS certificate password field is unavailable")

        private_key_text, parsed_serial = extract_and_verify_private_key(certificate_p12, certificate_password, tmpdir)
        result.update(
            {
                "eas_project_resolved": True,
                "eas_distribution_type": build_creds.get("iosDistributionType"),
                "eas_distribution_certificate_record_id": dist.get("id"),
                "eas_developer_portal_certificate_id": developer_cert_id,
                "eas_certificate_serial_number": dist.get("serialNumber"),
                "eas_certificate_validity_not_before": dist.get("validityNotBefore"),
                "eas_certificate_validity_not_after": dist.get("validityNotAfter"),
                "eas_provisioning_profile_record_id": profile.get("id"),
                "eas_provisioning_profile_developer_portal_id": profile.get("developerPortalIdentifier"),
                "p12_payload_present": True,
                "private_key_extracted": True,
                "private_key_matches_certificate": True,
                "certificate_serial_parsed": bool(parsed_serial),
            }
        )

        group_status, groups_payload = cm_call(cm_token, "GET", f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups")
        if group_status != 200:
            raise RuntimeError(f"Codemagic variable-group inventory failed HTTP {group_status}")
        group = next(
            (
                g
                for g in items(groups_payload)
                if (g.get("name") or g.get("group_name")) == EXPECTED["codemagic_group_name"]
            ),
            None,
        )
        group_id = str((group or {}).get("id") or (group or {}).get("_id") or "") or None
        result["codemagic_group_exists_before"] = bool(group_id)

        existing_names: list[str] = []
        if group_id:
            vars_status, vars_payload = cm_call(cm_token, "GET", f"/api/v3/variable-groups/{group_id}/variables")
            if vars_status != 200:
                raise RuntimeError(f"Codemagic variable inventory failed HTTP {vars_status}")
            existing_names = sorted(str(v.get("name")) for v in items(vars_payload) if v.get("name"))
        result["codemagic_variable_names_before"] = existing_names

        if mode == "probe":
            result["ok"] = True
            result["ready_to_install"] = not group_id or "CERTIFICATE_PRIVATE_KEY" not in existing_names
        else:
            if group_id and "CERTIFICATE_PRIVATE_KEY" in existing_names:
                raise RuntimeError("target Codemagic group already contains CERTIFICATE_PRIVATE_KEY; refusing blind overwrite")
            if not group_id:
                create_status, create_payload = cm_call(
                    cm_token,
                    "POST",
                    f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups",
                    {"name": EXPECTED["codemagic_group_name"]},
                )
                if create_status not in {200, 201}:
                    raise RuntimeError(f"Codemagic signing group creation failed HTTP {create_status}")
                candidates = [create_payload]
                if isinstance(create_payload, dict):
                    candidates += [create_payload.get("data"), create_payload.get("variable_group")]
                for candidate in candidates:
                    if isinstance(candidate, dict):
                        maybe = candidate.get("id") or candidate.get("_id")
                        if maybe:
                            group_id = str(maybe)
                            break
                if not group_id:
                    ls, lp = cm_call(cm_token, "GET", f"/api/v3/apps/{EXPECTED['codemagic_app_id']}/variable-groups")
                    if ls == 200:
                        found = next(
                            (g for g in items(lp) if (g.get("name") or g.get("group_name")) == EXPECTED["codemagic_group_name"]),
                            None,
                        )
                        group_id = str((found or {}).get("id") or (found or {}).get("_id") or "") or None
                if not group_id:
                    raise RuntimeError("Codemagic signing group id could not be resolved after creation")
                created_group_id = group_id

            secret_status, _ = cm_call(
                cm_token,
                "POST",
                f"/api/v3/variable-groups/{group_id}/variables",
                {"secure": True, "variables": [{"name": "CERTIFICATE_PRIVATE_KEY", "value": private_key_text}]},
            )
            if secret_status not in {200, 201}:
                raise RuntimeError(f"Codemagic private-key secure variable insertion failed HTTP {secret_status}")
            read_status, read_payload = cm_call(cm_token, "GET", f"/api/v3/variable-groups/{group_id}/variables")
            if read_status != 200:
                raise RuntimeError(f"Codemagic private-key readback failed HTTP {read_status}")
            variables = items(read_payload)
            names = sorted(str(v.get("name")) for v in variables if v.get("name"))
            if "CERTIFICATE_PRIVATE_KEY" not in names:
                raise RuntimeError("Codemagic private-key variable name missing after insertion")
            result.update(
                {
                    "codemagic_group_id": group_id,
                    "codemagic_group_created": bool(created_group_id),
                    "codemagic_secret_insert_http_status": secret_status,
                    "codemagic_variable_names_after": names,
                    "private_key_stored_as_secure_variable": True,
                    "ready_for_codemagic_workflow_attachment": True,
                    "ok": True,
                }
            )
    except Exception:
        if mode == "install" and created_group_id:
            # Roll back only the group created by this invocation. Never delete a pre-existing group.
            try:
                cm_call(cm_token, "DELETE", f"/api/v3/variable-groups/{created_group_id}")
            except Exception:
                pass
        raise
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
        RESULT_DIR.mkdir(parents=True, exist_ok=True)
        out = RESULT_DIR / f"{request_id}.json"
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        Path("/tmp/app2-003-eas-signing-result-path.txt").write_text(str(out), encoding="utf-8")
        Path("/tmp/app2-003-eas-signing-result-copy.json").write_text(out.read_text(encoding="utf-8"), encoding="utf-8")

    print(f"PASS: APP2-003 EAS signing bridge {mode}; certificate id verified; secrets not logged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
