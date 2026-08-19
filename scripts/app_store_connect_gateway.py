#!/usr/bin/env python3
"""Safe semantic App Store Connect API gateway.

Credentials are supplied only by the GitHub Actions secret store. Arbitrary write
paths are forbidden. Read requests remain available, while writes are limited to
reviewable semantic operations with app/bundle preflight and read-back checks.
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
PRODUCT_ID_RE = re.compile(r"^[A-Za-z0-9._-]{3,200}$")
MAX_BATCH = 50
MAX_WRITE_OPS = 10
VERSION_LOCALIZATION_ATTRS = {
    "description",
    "keywords",
    "marketingUrl",
    "promotionalText",
    "supportUrl",
    "whatsNew",
}
APP_INFO_LOCALIZATION_ATTRS = {
    "subtitle",
    "privacyPolicyUrl",
    "privacyChoicesUrl",
}


def validate_path(api_path: object) -> str:
    if not isinstance(api_path, str) or not api_path.startswith("/v1/"):
        raise ValueError("Only /v1/ App Store Connect API paths are allowed.")
    if len(api_path) > 2000 or "\n" in api_path or "\r" in api_path:
        raise ValueError("Invalid API path.")
    return api_path


def validate_resource_id(value: object, label: str) -> str:
    if not isinstance(value, str) or not RESOURCE_ID_RE.fullmatch(value):
        raise ValueError(f"Invalid {label}.")
    return value


def validate_short_text(value: object, label: str, max_len: int = 255) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be a string.")
    value = value.strip()
    if not value or len(value) > max_len or "\n" in value or "\r" in value:
        raise ValueError(f"Invalid {label}.")
    return value


def validate_product_id(value: object) -> str:
    if not isinstance(value, str) or not PRODUCT_ID_RE.fullmatch(value):
        raise ValueError("Invalid product id.")
    return value


def validate_request(item: object, index: int) -> dict:
    if not isinstance(item, dict):
        raise ValueError(f"requests[{index}] must be an object.")
    method = item.get("method", "GET")
    if method != "GET":
        raise ValueError("Read request batches allow only GET.")
    label = item.get("label", f"request-{index + 1}")
    if not isinstance(label, str) or not REQUEST_ID_RE.fullmatch(label):
        raise ValueError(f"requests[{index}].label is invalid.")
    return {"label": label, "method": "GET", "path": validate_path(item.get("path"))}


def validate_attributes(value: object, allowed: set[str], label: str) -> dict:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"{label}.attributes must be a non-empty object.")
    unknown = set(value) - allowed
    if unknown:
        raise ValueError(f"Unsupported {label} attributes: {sorted(unknown)}")
    clean = {}
    for key, item in value.items():
        if item is not None and not isinstance(item, str):
            raise ValueError(f"{label}.{key} must be a string or null.")
        if isinstance(item, str) and len(item) > 10000:
            raise ValueError(f"{label}.{key} is too long.")
        clean[key] = item
    return clean


def validate_write_operation(item: object, index: int) -> dict:
    if not isinstance(item, dict):
        raise ValueError(f"operations[{index}] must be an object.")
    op_type = item.get("type")
    if op_type == "update_version_localization":
        return {
            "type": op_type,
            "id": validate_resource_id(item.get("id"), "version localization id"),
            "app_store_version_id": validate_resource_id(item.get("app_store_version_id"), "app store version id"),
            "attributes": validate_attributes(item.get("attributes"), VERSION_LOCALIZATION_ATTRS, op_type),
        }
    if op_type == "update_app_info_localization":
        return {
            "type": op_type,
            "id": validate_resource_id(item.get("id"), "app info localization id"),
            "app_info_id": validate_resource_id(item.get("app_info_id"), "app info id"),
            "attributes": validate_attributes(item.get("attributes"), APP_INFO_LOCALIZATION_ATTRS, op_type),
        }
    if op_type == "attach_build":
        return {
            "type": op_type,
            "app_store_version_id": validate_resource_id(item.get("app_store_version_id"), "app store version id"),
            "build_id": validate_resource_id(item.get("build_id"), "build id"),
        }
    if op_type == "create_subscription_group":
        return {
            "type": op_type,
            "reference_name": validate_short_text(item.get("reference_name"), "subscription group reference name"),
        }
    if op_type == "create_subscription":
        period = item.get("subscription_period")
        if period != "ONE_MONTH":
            raise ValueError("Only ONE_MONTH subscriptions are allowed by this semantic operation.")
        return {
            "type": op_type,
            "subscription_group_id": validate_resource_id(item.get("subscription_group_id"), "subscription group id"),
            "name": validate_short_text(item.get("name"), "subscription name"),
            "product_id": validate_product_id(item.get("product_id")),
            "subscription_period": period,
        }
    if op_type == "create_non_consumable":
        return {
            "type": op_type,
            "name": validate_short_text(item.get("name"), "in-app purchase name"),
            "product_id": validate_product_id(item.get("product_id")),
        }
    raise ValueError(f"Unsupported semantic write operation: {op_type}")


def load_command(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Command must be a JSON object.")

    request_id = payload.get("request_id")
    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("request_id must match [A-Za-z0-9._-]{1,100}.")

    if payload.get("action") == "write":
        app_id = validate_resource_id(payload.get("expected_app_id"), "expected app id")
        bundle_id = payload.get("expected_bundle_id")
        if not isinstance(bundle_id, str) or not BUNDLE_ID_RE.fullmatch(bundle_id):
            raise ValueError("Invalid expected_bundle_id.")
        operations = payload.get("operations")
        if not isinstance(operations, list) or not operations:
            raise ValueError("operations must be a non-empty array.")
        if len(operations) > MAX_WRITE_OPS:
            raise ValueError(f"Write batch exceeds maximum of {MAX_WRITE_OPS} operations.")
        return {
            "request_id": request_id,
            "action": "write",
            "expected_app_id": app_id,
            "expected_bundle_id": bundle_id,
            "operations": [validate_write_operation(item, i) for i, item in enumerate(operations)],
        }

    if "requests" in payload:
        requests = payload.get("requests")
        if not isinstance(requests, list) or not requests:
            raise ValueError("requests must be a non-empty array.")
        if len(requests) > MAX_BATCH:
            raise ValueError(f"Batch exceeds maximum of {MAX_BATCH} requests.")
        return {
            "request_id": request_id,
            "action": "read",
            "requests": [validate_request(item, i) for i, item in enumerate(requests)],
        }

    method = payload.get("method")
    if method != "GET":
        raise ValueError("Single free-form requests are read-only: method must be GET.")
    return {
        "request_id": request_id,
        "action": "read",
        "requests": [{"label": "single", "method": "GET", "path": validate_path(payload.get("path"))}],
    }


def get_data_ids(response: object) -> set[str]:
    if not isinstance(response, dict):
        return set()
    data = response.get("data")
    if isinstance(data, list):
        return {str(x.get("id")) for x in data if isinstance(x, dict) and x.get("id")}
    if isinstance(data, dict) and data.get("id"):
        return {str(data["id"])}
    return set()


def get_data_list(response: object) -> list[dict]:
    if not isinstance(response, dict):
        return []
    data = response.get("data")
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        return [data]
    return []


def find_by_attribute(response: object, key: str, value: str) -> dict | None:
    for resource in get_data_list(response):
        if (resource.get("attributes") or {}).get(key) == value:
            return resource
    return None


def get_included_ids(response: object, resource_type: str) -> set[str]:
    if not isinstance(response, dict):
        return set()
    included = response.get("included") or []
    return {
        str(x.get("id"))
        for x in included
        if isinstance(x, dict) and x.get("type") == resource_type and x.get("id")
    }


def preflight_target(token: str, app_id: str, bundle_id: str) -> None:
    _, app = api_get(token, f"/v1/apps/{app_id}")
    data = app.get("data") if isinstance(app, dict) else None
    actual = (data or {}).get("attributes", {}).get("bundleId") if isinstance(data, dict) else None
    if actual != bundle_id:
        raise RuntimeError(f"Target preflight failed: expected bundle {bundle_id}, got {actual!r}")


def ensure_version_belongs_to_app(token: str, app_id: str, version_id: str) -> None:
    _, response = api_get(token, f"/v1/apps/{app_id}/appStoreVersions?limit=200")
    if version_id not in get_data_ids(response):
        raise RuntimeError("App Store version does not belong to expected app.")


def ensure_build_belongs_to_app(token: str, app_id: str, build_id: str) -> None:
    _, response = api_get(token, f"/v1/apps/{app_id}/builds?limit=200")
    if build_id not in get_data_ids(response):
        raise RuntimeError("Build does not belong to expected app.")


def ensure_subscription_group_belongs_to_app(token: str, app_id: str, group_id: str) -> None:
    _, response = api_get(token, f"/v1/apps/{app_id}/subscriptionGroups?limit=200")
    if group_id not in get_data_ids(response):
        raise RuntimeError("Subscription group does not belong to expected app.")


def ensure_version_localization(token: str, version_id: str, localization_id: str) -> None:
    _, response = api_get(token, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200")
    if localization_id not in get_data_ids(response):
        raise RuntimeError("Version localization does not belong to expected version.")


def ensure_app_info_localization(token: str, app_id: str, app_info_id: str, localization_id: str) -> None:
    _, infos = api_get(token, f"/v1/apps/{app_id}/appInfos?limit=20&include=appInfoLocalizations")
    if app_info_id not in get_data_ids(infos):
        raise RuntimeError("App info does not belong to expected app.")
    if localization_id not in get_included_ids(infos, "appInfoLocalizations"):
        raise RuntimeError("App info localization does not belong to expected app info.")


def update_resource_attributes(token: str, resource_type: str, resource_id: str, path: str, attributes: dict) -> dict:
    _, before = api_get(token, path)
    before_data = before.get("data") if isinstance(before, dict) else None
    current = (before_data or {}).get("attributes", {}) if isinstance(before_data, dict) else {}
    changes = {key: value for key, value in attributes.items() if current.get(key) != value}
    if not changes:
        return {"changed": False, "before": before, "after": before}

    payload = {
        "data": {
            "type": resource_type,
            "id": resource_id,
            "attributes": changes,
        }
    }
    status, _ = api_request(token, path, method="PATCH", payload=payload)
    _, after = api_get(token, path)
    after_data = after.get("data") if isinstance(after, dict) else None
    after_attrs = (after_data or {}).get("attributes", {}) if isinstance(after_data, dict) else {}
    for key, value in changes.items():
        if after_attrs.get(key) != value:
            raise RuntimeError(f"Read-back mismatch after updating {resource_type}.{key}")
    return {"changed": True, "http_status": status, "changed_attributes": sorted(changes), "after": after}


def create_subscription_group(token: str, app_id: str, reference_name: str) -> dict:
    list_path = f"/v1/apps/{app_id}/subscriptionGroups?limit=200"
    _, before = api_get(token, list_path)
    existing = find_by_attribute(before, "referenceName", reference_name)
    if existing:
        return {"changed": False, "resource": existing}
    payload = {
        "data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": reference_name},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    status, response = api_request(token, "/v1/subscriptionGroups", method="POST", payload=payload)
    created = response.get("data") if isinstance(response, dict) else None
    if not isinstance(created, dict) or not created.get("id"):
        raise RuntimeError("Subscription group creation returned no resource id.")
    _, after = api_get(token, list_path)
    if created["id"] not in get_data_ids(after):
        raise RuntimeError("Subscription group read-back mismatch.")
    return {"changed": True, "http_status": status, "resource": created}


def create_subscription(token: str, app_id: str, group_id: str, name: str, product_id: str, period: str) -> dict:
    ensure_subscription_group_belongs_to_app(token, app_id, group_id)
    list_path = f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200"
    _, before = api_get(token, list_path)
    existing = find_by_attribute(before, "productId", product_id)
    if existing:
        return {"changed": False, "resource": existing}
    payload = {
        "data": {
            "type": "subscriptions",
            "attributes": {
                "name": name,
                "productId": product_id,
                "subscriptionPeriod": period,
            },
            "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group_id}}},
        }
    }
    status, response = api_request(token, "/v1/subscriptions", method="POST", payload=payload)
    created = response.get("data") if isinstance(response, dict) else None
    if not isinstance(created, dict) or not created.get("id"):
        raise RuntimeError("Subscription creation returned no resource id.")
    _, after = api_get(token, list_path)
    if created["id"] not in get_data_ids(after):
        raise RuntimeError("Subscription read-back mismatch.")
    return {"changed": True, "http_status": status, "resource": created}


def create_non_consumable(token: str, app_id: str, name: str, product_id: str) -> dict:
    list_path = f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200"
    _, before = api_get(token, list_path)
    existing = find_by_attribute(before, "productId", product_id)
    if existing:
        return {"changed": False, "resource": existing}
    payload = {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": name,
                "productId": product_id,
                "inAppPurchaseType": "NON_CONSUMABLE",
            },
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    status, response = api_request(token, "/v2/inAppPurchases", method="POST", payload=payload)
    created = response.get("data") if isinstance(response, dict) else None
    if not isinstance(created, dict) or not created.get("id"):
        raise RuntimeError("In-app purchase creation returned no resource id.")
    _, after = api_get(token, list_path)
    if created["id"] not in get_data_ids(after):
        raise RuntimeError("In-app purchase read-back mismatch.")
    return {"changed": True, "http_status": status, "resource": created}


def execute_write(token: str, command: dict) -> list[dict]:
    app_id = command["expected_app_id"]
    preflight_target(token, app_id, command["expected_bundle_id"])
    results = []

    for op in command["operations"]:
        op_type = op["type"]
        if op_type == "update_version_localization":
            ensure_version_belongs_to_app(token, app_id, op["app_store_version_id"])
            ensure_version_localization(token, op["app_store_version_id"], op["id"])
            outcome = update_resource_attributes(
                token,
                "appStoreVersionLocalizations",
                op["id"],
                f"/v1/appStoreVersionLocalizations/{op['id']}",
                op["attributes"],
            )
        elif op_type == "update_app_info_localization":
            ensure_app_info_localization(token, app_id, op["app_info_id"], op["id"])
            outcome = update_resource_attributes(
                token,
                "appInfoLocalizations",
                op["id"],
                f"/v1/appInfoLocalizations/{op['id']}",
                op["attributes"],
            )
        elif op_type == "attach_build":
            ensure_version_belongs_to_app(token, app_id, op["app_store_version_id"])
            ensure_build_belongs_to_app(token, app_id, op["build_id"])
            relationship_path = f"/v1/appStoreVersions/{op['app_store_version_id']}/relationships/build"
            _, before = api_get(token, relationship_path)
            current_ids = get_data_ids(before)
            if op["build_id"] in current_ids:
                outcome = {"changed": False, "before": before, "after": before}
            else:
                payload = {"data": {"type": "builds", "id": op["build_id"]}}
                status, _ = api_request(token, relationship_path, method="PATCH", payload=payload)
                _, after = api_get(token, relationship_path)
                if op["build_id"] not in get_data_ids(after):
                    raise RuntimeError("Build relationship read-back mismatch.")
                outcome = {"changed": True, "http_status": status, "after": after}
        elif op_type == "create_subscription_group":
            outcome = create_subscription_group(token, app_id, op["reference_name"])
        elif op_type == "create_subscription":
            outcome = create_subscription(
                token,
                app_id,
                op["subscription_group_id"],
                op["name"],
                op["product_id"],
                op["subscription_period"],
            )
        elif op_type == "create_non_consumable":
            outcome = create_non_consumable(token, app_id, op["name"], op["product_id"])
        else:
            raise AssertionError(op_type)
        results.append({"operation": op_type, "outcome": outcome})
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Execute safe App Store Connect commands.")
    parser.add_argument("--command", default="automation/app-store-connect-command.json")
    parser.add_argument("--output", default="asc-result.json")
    args = parser.parse_args()

    command = load_command(Path(args.command))
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing ASC_ISSUER_ID or ASC_KEY_ID.")

    key_path, cleanup = load_private_key()
    results = []
    try:
        token = make_token(issuer_id, key_id, key_path)
        if command["action"] == "write":
            results = execute_write(token, command)
        else:
            for req in command["requests"]:
                status, response = api_get(token, req["path"])
                results.append({
                    "label": req["label"],
                    "method": "GET",
                    "path": req["path"],
                    "http_status": status,
                    "response": response,
                })
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    result = {
        "request_id": command["request_id"],
        "action": command["action"],
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "result_count": len(results),
        "results": results,
    }
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"PASS: request_id={command['request_id']} action={command['action']} results={len(results)}")


if __name__ == "__main__":
    main()
