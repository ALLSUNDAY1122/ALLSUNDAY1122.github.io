#!/usr/bin/env python3
"""Validate the canonical release registry without contacting external services."""
from __future__ import annotations

import json
import os
from pathlib import Path

REGISTRY = Path(os.environ.get("APP_RELEASE_REGISTRY", "automation/app-release-registry.json"))
OUT = Path(os.environ.get("APP_RELEASE_REGISTRY_AUDIT", "automation/app-release-registry-audit.json"))
EXPECTED_APP2 = {f"APP2-{i:03d}" for i in range(1, 14)}


def main() -> None:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    apps = data.get("apps")
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(apps, dict) or not apps:
        raise SystemExit("registry apps must be a non-empty object")

    app_ids: dict[str, str] = {}
    bundle_ids: dict[str, str] = {}
    task_to_label: dict[str, str] = {}

    for label, app in apps.items():
        if not isinstance(app, dict):
            errors.append(f"{label}: entry is not an object")
            continue
        bundle_id = str(app.get("bundle_id") or "").strip()
        app_id_raw = app.get("app_id")
        app_id = str(app_id_raw).strip() if app_id_raw is not None else ""
        task = str(app.get("app2_task") or "").strip()
        status = str(app.get("status") or "").strip()
        readback = bool(app.get("readback", True))

        if not bundle_id:
            errors.append(f"{label}: missing bundle_id")
        elif bundle_id in bundle_ids:
            errors.append(f"duplicate bundle_id {bundle_id}: {bundle_ids[bundle_id]} and {label}")
        else:
            bundle_ids[bundle_id] = label

        if app_id:
            if not app_id.isdigit():
                errors.append(f"{label}: app_id must be numeric or null")
            elif app_id in app_ids:
                errors.append(f"duplicate app_id {app_id}: {app_ids[app_id]} and {label}")
            else:
                app_ids[app_id] = label
        elif readback:
            errors.append(f"{label}: readback=true but app_id is unresolved")

        if task:
            if task in task_to_label:
                errors.append(f"duplicate app2_task {task}: {task_to_label[task]} and {label}")
            else:
                task_to_label[task] = label
            if task not in EXPECTED_APP2:
                warnings.append(f"{label}: unexpected app2_task {task}")
            if not app_id and status != "apple_id_pending":
                errors.append(f"{label}: unresolved APP2 app must use status=apple_id_pending")
            if not app_id and readback:
                errors.append(f"{label}: unresolved APP2 app must have readback=false")

    missing_tasks = sorted(EXPECTED_APP2 - set(task_to_label))
    if missing_tasks:
        errors.append(f"missing APP2 tasks: {','.join(missing_tasks)}")

    result = {
        "registry": str(REGISTRY),
        "schema_version": data.get("schema_version"),
        "app_count": len(apps),
        "app2_task_count": len(set(task_to_label) & EXPECTED_APP2),
        "resolved_app_id_count": len(app_ids),
        "pending_app_id_labels": sorted(label for label, app in apps.items() if not app.get("app_id")),
        "errors": errors,
        "warnings": warnings,
        "status": "PASS" if not errors else "FAIL",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if errors:
        raise SystemExit("release registry audit failed")


if __name__ == "__main__":
    main()
