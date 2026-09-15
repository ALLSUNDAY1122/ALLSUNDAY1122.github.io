#!/usr/bin/env python3
"""Audit or update existing Japanese App Store Connect metadata.

Dry-run is the default. This tool does not create an app record, create a version,
upload screenshots, select a build, submit for review, or release the app.

Production updates require all of the following:
- --apply
- --confirm-bundle-id matching the metadata Bundle ID
- --confirm-version matching the metadata version
- --confirm-apply APPLY_METADATA
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

API_ROOT = "https://api.appstoreconnect.apple.com/v1"
APPLY_CONFIRMATION = "APPLY_METADATA"


def load_jwt_module(script_dir: Path):
    path = script_dir / "verify_app_store_connect_api_key.py"
    if not path.is_file():
        raise SystemExit(f"Missing helper: {path}")
    spec = importlib.util.spec_from_file_location("asc_jwt", path)
    if spec is None or spec.loader is None:
        raise SystemExit("Unable to load JWT helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def api_request(token: str, method: str, path: str, payload: dict | None = None) -> dict:
    body = None
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(API_ROOT + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = {"raw": raw[:1000]}
        raise RuntimeError(
            f"App Store Connect API {method} {path} failed with HTTP {exc.code}: "
            + json.dumps(parsed, ensure_ascii=False)
        ) from exc


def validate_metadata(data: dict) -> list[str]:
    errors: list[str] = []
    app = data.get("app", {})
    version = data.get("version", {})
    required = [
        (app, "bundle_id"),
        (app, "locale"),
        (app, "name"),
        (app, "subtitle"),
        (app, "privacy_policy_url"),
        (version, "platform"),
        (version, "version_string"),
        (version, "description"),
        (version, "keywords"),
        (version, "promotional_text"),
        (version, "support_url"),
    ]
    for section, key in required:
        if not str(section.get(key, "")).strip():
            errors.append(f"Missing required metadata: {key}")
    if len(app.get("name", "")) > 30:
        errors.append("App name exceeds 30 characters")
    if len(app.get("subtitle", "")) > 30:
        errors.append("Subtitle exceeds 30 characters")
    if len(version.get("promotional_text", "")) > 170:
        errors.append("Promotional text exceeds 170 characters")
    if len(version.get("description", "")) > 4000:
        errors.append("Description exceeds 4000 characters")
    if len(version.get("keywords", "").encode("utf-8")) > 100:
        errors.append("Keywords exceed 100 UTF-8 bytes")
    if app.get("locale") != "ja":
        errors.append("This release tool requires locale ja")
    if version.get("platform") != "IOS":
        errors.append("This release tool requires platform IOS")
    if not str(app.get("privacy_policy_url", "")).startswith("https://"):
        errors.append("privacy_policy_url must use HTTPS")
    if not str(version.get("support_url", "")).startswith("https://"):
        errors.append("support_url must use HTTPS")
    return errors


def check_public_url(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "AI-Handover-Log-Release-Audit/0.6"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read(4096).decode("utf-8", errors="ignore")
            return {
                "url": url,
                "http_status": response.status,
                "reachable": 200 <= response.status < 400,
                "looks_like_github_404": "Page not found" in body or "404" in response.geturl(),
                "final_url": response.geturl(),
            }
    except urllib.error.HTTPError as exc:
        return {
            "url": url,
            "http_status": exc.code,
            "reachable": False,
            "looks_like_github_404": exc.code == 404,
        }
    except Exception as exc:
        return {"url": url, "reachable": False, "error": type(exc).__name__}


def get_single(items: list[dict], label: str) -> dict:
    if len(items) != 1:
        raise RuntimeError(f"Expected exactly one {label}, found {len(items)}")
    return items[0]


def diff_attributes(current: dict, desired: dict) -> dict:
    return {
        key: {"current": current.get(key), "desired": value}
        for key, value in desired.items()
        if current.get(key) != value
    }


def save_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def verify_apply_confirmation(args: argparse.Namespace, app_meta: dict, version_meta: dict) -> None:
    errors: list[str] = []
    if args.confirm_bundle_id != app_meta["bundle_id"]:
        errors.append(
            "--confirm-bundle-id must exactly match " + app_meta["bundle_id"]
        )
    if args.confirm_version != version_meta["version_string"]:
        errors.append(
            "--confirm-version must exactly match " + version_meta["version_string"]
        )
    if args.confirm_apply != APPLY_CONFIRMATION:
        errors.append(f"--confirm-apply must be exactly {APPLY_CONFIRMATION}")
    if errors:
        raise SystemExit("\n".join(f"ERROR: {item}" for item in errors))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-key", type=Path, required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("app_store_metadata_audit.json"))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm-bundle-id")
    parser.add_argument("--confirm-version")
    parser.add_argument("--confirm-apply")
    args = parser.parse_args()

    data = json.loads(args.metadata.read_text(encoding="utf-8"))
    errors = validate_metadata(data)
    if errors:
        raise SystemExit("\n".join(f"ERROR: {item}" for item in errors))
    app_meta = data["app"]
    version_meta = data["version"]

    if args.apply:
        verify_apply_confirmation(args, app_meta, version_meta)

    jwt_module = load_jwt_module(Path(__file__).resolve().parent)
    token = jwt_module.create_token(args.api_key, args.key_id, args.issuer_id)

    query = urllib.parse.urlencode({
        "filter[bundleId]": app_meta["bundle_id"],
        "fields[apps]": "name,bundleId,sku,primaryLocale",
        "limit": "2",
    })
    app = get_single(api_request(token, "GET", f"/apps?{query}").get("data", []), "app matching bundle ID")
    app_id = app["id"]

    app_info = get_single(
        api_request(token, "GET", f"/apps/{app_id}/appInfos?limit=10").get("data", []),
        "app info",
    )
    app_info_id = app_info["id"]

    loc_query = urllib.parse.urlencode({"filter[locale]": app_meta["locale"], "limit": "2"})
    app_info_loc = get_single(
        api_request(token, "GET", f"/appInfos/{app_info_id}/appInfoLocalizations?{loc_query}").get("data", []),
        "Japanese app info localization",
    )

    version_query = urllib.parse.urlencode({
        "filter[platform]": version_meta["platform"],
        "filter[versionString]": version_meta["version_string"],
        "limit": "2",
    })
    version = get_single(
        api_request(token, "GET", f"/apps/{app_id}/appStoreVersions?{version_query}").get("data", []),
        f"App Store version {version_meta['version_string']} on {version_meta['platform']}",
    )
    version_id = version["id"]

    version_loc = get_single(
        api_request(token, "GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?{loc_query}").get("data", []),
        "Japanese app store version localization",
    )

    desired_app_info = {
        "name": app_meta["name"],
        "subtitle": app_meta["subtitle"],
        "privacyPolicyUrl": app_meta["privacy_policy_url"],
    }
    desired_version = {
        "description": version_meta["description"],
        "keywords": version_meta["keywords"],
        "promotionalText": version_meta["promotional_text"],
        "supportUrl": version_meta["support_url"],
    }
    app_info_diff = diff_attributes(app_info_loc.get("attributes", {}), desired_app_info)
    version_diff = diff_attributes(version_loc.get("attributes", {}), desired_version)
    url_checks = [
        check_public_url(app_meta["privacy_policy_url"]),
        check_public_url(version_meta["support_url"]),
    ]
    urls_ready = all(
        item.get("reachable") and not item.get("looks_like_github_404")
        for item in url_checks
    )

    report: dict[str, Any] = {
        "mode": "apply" if args.apply else "dry-run",
        "apply_confirmation_verified": bool(args.apply),
        "app": {
            "id": app_id,
            "bundle_id": app_meta["bundle_id"],
            "api_name": app.get("attributes", {}).get("name"),
            "sku": app.get("attributes", {}).get("sku"),
            "primary_locale": app.get("attributes", {}).get("primaryLocale"),
        },
        "app_info_localization": {
            "id": app_info_loc["id"],
            "locale": app_meta["locale"],
            "diff": app_info_diff,
        },
        "app_store_version": {
            "id": version_id,
            "version_string": version_meta["version_string"],
            "platform": version_meta["platform"],
            "state": version.get("attributes", {}).get("appStoreState"),
        },
        "version_localization": {
            "id": version_loc["id"],
            "locale": app_meta["locale"],
            "diff": version_diff,
        },
        "public_url_checks": url_checks,
        "urls_ready_for_apply": urls_ready,
        "changes_applied": [],
        "submission_performed": False,
        "build_selected": False,
        "screenshots_uploaded": False,
    }

    # Persist the complete pre-apply audit before any production PATCH request.
    save_report(args.output, report)

    if args.apply:
        if not urls_ready:
            raise SystemExit(
                "ERROR: Privacy or support URL is not publicly reachable. "
                "Do not apply metadata before PR #1661 is merged and verified."
            )
        if app_info_diff:
            api_request(token, "PATCH", f"/appInfoLocalizations/{app_info_loc['id']}", {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": app_info_loc["id"],
                    "attributes": desired_app_info,
                }
            })
            report["changes_applied"].append("appInfoLocalization")
            save_report(args.output, report)
        if version_diff:
            api_request(token, "PATCH", f"/appStoreVersionLocalizations/{version_loc['id']}", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": version_loc["id"],
                    "attributes": desired_version,
                }
            })
            report["changes_applied"].append("appStoreVersionLocalization")
            save_report(args.output, report)

    save_report(args.output, report)


if __name__ == "__main__":
    main()
