#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
LOCK = HERE / "app-icon-lock.json"
RELEASE_BANK = HERE / "Resources" / "questions.release.json"
MOCK_AUDIT = HERE.parent / "content-loop" / "audit_practice_mock_readiness.py"

REQUIRED_ENV = (
    "YOBI_BUNDLE_ID",
    "YOBI_APP_STORE_CONNECT_APP_ID",
    "YOBI_IAP_PRODUCT_ID",
)


class PreflightError(ValueError):
    pass


def normalize_explicit(name: str, value: str | None) -> str:
    if value is None:
        raise PreflightError(f"{name}: 未設定")
    value = value.strip()
    if not value:
        raise PreflightError(f"{name}: 空値")
    upper = value.upper()
    if "UNSET" in upper or "$(" in value:
        raise PreflightError(f"{name}: placeholderは禁止")
    if value.startswith("jp.ci.") or ".preview" in value.lower():
        raise PreflightError(f"{name}: CI/preview識別子は禁止")
    return value


def validate_environment(env: dict[str, str]) -> dict[str, str]:
    return {name: normalize_explicit(name, env.get(name)) for name in REQUIRED_ENV}


def validate_icon_lock() -> dict:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    if lock.get("developmentSequence") != 11:
        raise PreflightError("AppIcon lockの開発連番が#11ではない")
    sha = str(lock.get("sha256", ""))
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise PreflightError("AppIcon lockのSHA-256が不正")
    if lock.get("width") != 1024 or lock.get("height") != 1024:
        raise PreflightError("AppIcon lockは1024x1024ではない")
    return lock


def validate_release_bank(path: Path = RELEASE_BANK) -> int:
    if not path.exists():
        raise PreflightError("questions.release.json が未生成。教材Release監査PASS前は署名禁止")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list) or not data:
        raise PreflightError("questions.release.json が空")
    for question in data:
        if question.get("releaseEligible") is not True:
            raise PreflightError(f"{question.get('id', '<no-id>')}: releaseEligible=trueではない")
        if question.get("originType") == "original_preview":
            raise PreflightError(f"{question.get('id', '<no-id>')}: preview問題がReleaseへ混入")
    return len(data)


def validate_three_mock_completion() -> None:
    if not MOCK_AUDIT.exists():
        raise PreflightError("3回分完成監査スクリプトがない")
    with tempfile.TemporaryDirectory() as tmp:
        report = Path(tmp) / "practice-mock-readiness.json"
        result = subprocess.run(
            [
                sys.executable,
                str(MOCK_AUDIT),
                "--require-complete",
                "--report",
                str(report),
            ],
            cwd=str(HERE.parent.parent.parent),
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else "completion gate failed"
            raise PreflightError(f"独自模試3回分が未完成: {detail}")


def self_test() -> int:
    good = {
        "YOBI_BUNDLE_ID": "jp.example.userchosen.yobi",
        "YOBI_APP_STORE_CONNECT_APP_ID": "explicit-app-id",
        "YOBI_IAP_PRODUCT_ID": "jp.example.userchosen.yobi.premium",
    }
    values = validate_environment(good)
    assert values["YOBI_BUNDLE_ID"] == good["YOBI_BUNDLE_ID"]

    bad_cases = [
        {**good, "YOBI_BUNDLE_ID": "UNSET.YOBI.BUNDLE.ID"},
        {**good, "YOBI_IAP_PRODUCT_ID": "$(YOBI_IAP_PRODUCT_ID)"},
        {**good, "YOBI_BUNDLE_ID": "jp.ci.yobi.preview"},
        {**good, "YOBI_APP_STORE_CONNECT_APP_ID": ""},
    ]
    for case in bad_cases:
        try:
            validate_environment(case)
        except PreflightError:
            pass
        else:
            raise AssertionError(f"unsafe env accepted: {case}")

    validate_icon_lock()
    print("SELFTEST PASS: production IDs must be explicit; CI/placeholder IDs rejected; AppIcon lock valid; normal preflight also requires three complete mocks")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--release-bank", type=Path, default=RELEASE_BANK)
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    try:
        values = validate_environment(dict(os.environ))
        lock = validate_icon_lock()
        count = validate_release_bank(args.release_bank)
        validate_three_mock_completion()
    except PreflightError as error:
        print(f"BLOCKED: {error}")
        return 2

    print("PASS: production release preflight")
    print(f"- Bundle ID: {values['YOBI_BUNDLE_ID']}")
    print(f"- App Store Connect App ID: {values['YOBI_APP_STORE_CONNECT_APP_ID']}")
    print(f"- IAP Product ID: {values['YOBI_IAP_PRODUCT_ID']}")
    print(f"- Release questions: {count}")
    print("- Three original practice mocks: complete")
    print(f"- Canonical AppIcon SHA-256: {lock['sha256']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
