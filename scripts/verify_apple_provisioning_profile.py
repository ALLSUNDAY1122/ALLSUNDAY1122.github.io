#!/usr/bin/env python3
"""Validate Apple distribution provisioning profile metadata without exposing secrets."""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def iso(value: Any) -> str | None:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat()
    return None


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile-plist", required=True)
    parser.add_argument("--certificate-der", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    profile_path = Path(args.profile_plist)
    cert_path = Path(args.certificate_der)
    output_path = Path(args.output)

    with profile_path.open("rb") as handle:
        profile = plistlib.load(handle)

    cert_der = cert_path.read_bytes()
    cert_sha256 = hashlib.sha256(cert_der).hexdigest()
    now = datetime.now(timezone.utc)

    entitlements = profile.get("Entitlements") or {}
    team_identifiers = profile.get("TeamIdentifier") or []
    team_id = team_identifiers[0] if team_identifiers else None
    app_identifier = entitlements.get("application-identifier")
    expected_app_identifier = f"{args.team_id}.{args.bundle_id}"

    expiration = profile.get("ExpirationDate")
    creation = profile.get("CreationDate")
    profile_certs = profile.get("DeveloperCertificates") or []
    profile_cert_hashes = [
        hashlib.sha256(bytes(item)).hexdigest() for item in profile_certs
    ]

    provisioned_devices = profile.get("ProvisionedDevices")
    provisions_all_devices = bool(profile.get("ProvisionsAllDevices", False))
    get_task_allow = bool(entitlements.get("get-task-allow", False))
    beta_reports_active = bool(entitlements.get("beta-reports-active", False))

    checks = {
        "team_id_matches": team_id == args.team_id,
        "application_identifier_matches": app_identifier == expected_app_identifier,
        "certificate_is_in_profile": cert_sha256 in profile_cert_hashes,
        "not_expired": isinstance(expiration, datetime)
        and (
            expiration.replace(tzinfo=timezone.utc)
            if expiration.tzinfo is None
            else expiration.astimezone(timezone.utc)
        )
        > now,
        "not_development_profile": not get_task_allow,
        "has_no_registered_devices": not provisioned_devices,
        "not_enterprise_profile": not provisions_all_devices,
        "app_store_beta_reports_active": beta_reports_active,
    }

    report = {
        "profile": {
            "name": profile.get("Name"),
            "uuid": profile.get("UUID"),
            "team_name": profile.get("TeamName"),
            "team_id": team_id,
            "creation_date_utc": iso(creation),
            "expiration_date_utc": iso(expiration),
            "application_identifier": app_identifier,
            "bundle_id": args.bundle_id,
            "get_task_allow": get_task_allow,
            "beta_reports_active": beta_reports_active,
            "provisioned_devices_present": bool(provisioned_devices),
            "provisions_all_devices": provisions_all_devices,
            "developer_certificate_count": len(profile_certs),
        },
        "certificate": {
            "sha256_der": cert_sha256,
            "included_in_profile": cert_sha256 in profile_cert_hashes,
        },
        "checks": checks,
        "result": "passed" if all(checks.values()) else "failed",
    }

    output_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        for name in failed:
            print(f"FAILED_CHECK: {name}", file=sys.stderr)
        raise SystemExit(2)

    print("PROFILE_VALIDATION_OK")
    print(f"profile_name={profile.get('Name')}")
    print(f"profile_uuid={profile.get('UUID')}")
    print(f"expiration_utc={iso(expiration)}")
    print(f"application_identifier={app_identifier}")


if __name__ == "__main__":
    main()
