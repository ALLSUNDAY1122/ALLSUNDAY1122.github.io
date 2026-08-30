#!/usr/bin/env python3
"""Create App Store availability for an app that has no availability resource.

This is intentionally create-only. It verifies the app id/bundle id pair, validates
territory ids against App Store Connect, creates the v2 appAvailabilities resource,
and reads the result back before reporting success.
"""

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
RESOURCE_ID_RE = re.compile(r"^[A-Za-z0-9-]{8,100}$")
BUNDLE_ID_RE = re.compile(r"^[A-Za-z0-9.-]{3,200}$")
TERRITORY_RE = re.compile(r"^[A-Z]{3}$")


def load_command(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Command must be a JSON object.")

    request_id = raw.get("request_id")
    app_id = raw.get("expected_app_id")
    bundle_id = raw.get("expected_bundle_id")
    territories = raw.get("territories")
    available_in_new = raw.get("available_in_new_territories", False)

    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("Invalid request_id.")
    if not isinstance(app_id, str) or not RESOURCE_ID_RE.fullmatch(app_id):
        raise ValueError("Invalid expected_app_id.")
    if not isinstance(bundle_id, str) or not BUNDLE_ID_RE.fullmatch(bundle_id):
        raise ValueError("Invalid expected_bundle_id.")
    if not isinstance(territories, list) or not territories or len(territories) > 200:
        raise ValueError("territories must be a non-empty array with at most 200 items.")
    if not isinstance(available_in_new, bool):
        raise ValueError("available_in_new_territories must be boolean.")

    clean_territories = []
    seen = set()
    for value in territories:
        if not isinstance(value, str) or not TERRITORY_RE.fullmatch(value):
            raise ValueError(f"Invalid territory id: {value!r}")
        if value not in seen:
            clean_territories.append(value)
            seen.add(value)

    return {
        "request_id": request_id,
        "expected_app_id": app_id,
        "expected_bundle_id": bundle_id,
        "territories": clean_territories,
        "available_in_new_territories": available_in_new,
    }


def preflight_app(token: str, app_id: str, bundle_id: str) -> None:
    _, response = api_get(token, f"/v1/apps/{app_id}")
    data = response.get("data") if isinstance(response, dict) else None
    actual = (data or {}).get("attributes", {}).get("bundleId") if isinstance(data, dict) else None
    if actual != bundle_id:
        raise RuntimeError(f"Target preflight failed: expected bundle {bundle_id}, got {actual!r}")


def validate_territories(token: str, requested: list[str]) -> None:
    _, response = api_get(token, "/v1/territories?limit=200")
    valid = {
        str(item.get("id"))
        for item in (response.get("data") or [])
        if isinstance(item, dict) and item.get("id")
    }
    unknown = [territory for territory in requested if territory not in valid]
    if unknown:
        raise RuntimeError(f"Unknown App Store territory ids: {unknown}")


def read_existing_availability(token: str, app_id: str):
    try:
        _, response = api_get(token, f"/v1/apps/{app_id}/appAvailabilityV2")
        return response
    except RuntimeError as exc:
        message = str(exc)
        if "returned HTTP 404" in message and "NOT_FOUND" in message:
            return None
        raise


def create_availability(token: str, app_id: str, territories: list[str], available_in_new: bool):
    refs = []
    included = []
    for territory in territories:
        local_id = "${" + territory + "}"
        refs.append({"type": "territoryAvailabilities", "id": local_id})
        included.append(
            {
                "type": "territoryAvailabilities",
                "id": local_id,
                "attributes": {"available": True},
                "relationships": {
                    "territory": {
                        "data": {"type": "territories", "id": territory}
                    }
                },
            }
        )

    payload = {
        "data": {
            "type": "appAvailabilities",
            "attributes": {"availableInNewTerritories": available_in_new},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "territoryAvailabilities": {"data": refs},
            },
        },
        "included": included,
    }
    return api_request(token, "/v2/appAvailabilities", method="POST", payload=payload)


def verify(token: str, app_id: str, requested: list[str], available_in_new: bool) -> dict:
    _, availability = api_get(token, f"/v1/apps/{app_id}/appAvailabilityV2")
    data = availability.get("data") if isinstance(availability, dict) else None
    if not isinstance(data, dict) or not data.get("id"):
        raise RuntimeError("Availability read-back returned no resource id.")

    attrs = data.get("attributes") or {}
    if attrs.get("availableInNewTerritories") is not available_in_new:
        raise RuntimeError("availableInNewTerritories read-back mismatch.")

    availability_id = str(data["id"])
    path = (
        f"/v2/appAvailabilities/{availability_id}/territoryAvailabilities"
        "?limit=200&include=territory&fields%5BterritoryAvailabilities%5D=available,territory"
    )
    _, territories_response = api_get(token, path)
    available_ids = set()
    for item in territories_response.get("data") or []:
        if not isinstance(item, dict):
            continue
        if (item.get("attributes") or {}).get("available") is not True:
            continue
        territory_rel = ((item.get("relationships") or {}).get("territory") or {}).get("data")
        if isinstance(territory_rel, dict) and territory_rel.get("id"):
            available_ids.add(str(territory_rel["id"]))

    missing = [territory for territory in requested if territory not in available_ids]
    if missing:
        raise RuntimeError(f"Availability read-back missing requested territories: {missing}")

    return {
        "availability_id": availability_id,
        "available_in_new_territories": attrs.get("availableInNewTerritories"),
        "requested_territories": requested,
        "verified_available_territories": sorted(available_ids),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Create App Store availability safely.")
    parser.add_argument("--command", default="automation/app-store-availability-command.json")
    parser.add_argument("--output", default="availability-result.json")
    args = parser.parse_args()

    command = load_command(Path(args.command))
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing ASC_ISSUER_ID or ASC_KEY_ID.")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        preflight_app(token, command["expected_app_id"], command["expected_bundle_id"])
        validate_territories(token, command["territories"])
        existing = read_existing_availability(token, command["expected_app_id"])
        if existing is not None:
            raise RuntimeError(
                "App availability already exists; this create-only gateway refuses to mutate an existing availability."
            )

        status, response = create_availability(
            token,
            command["expected_app_id"],
            command["territories"],
            command["available_in_new_territories"],
        )
        created = response.get("data") if isinstance(response, dict) else None
        if status != 201 or not isinstance(created, dict) or not created.get("id"):
            raise RuntimeError("App availability creation did not return a valid created resource.")

        verification = verify(
            token,
            command["expected_app_id"],
            command["territories"],
            command["available_in_new_territories"],
        )
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    result = {
        "request_id": command["request_id"],
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "action": "create_app_availability",
        "expected_app_id": command["expected_app_id"],
        "expected_bundle_id": command["expected_bundle_id"],
        "http_status": status,
        "verification": verification,
    }
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"PASS: created app availability for {command['expected_app_id']} "
        f"territories={','.join(command['territories'])}"
    )


if __name__ == "__main__":
    main()
