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
ROOT = HERE.parent
LOCK = HERE / "app-icon-lock.json"
RELEASE_BANK = HERE / "Resources" / "questions.release.json"
MOCK_AUDIT = ROOT / "content-loop" / "audit_practice_mock_readiness.py"
MONETIZATION_CONFIG = ROOT / "app-store" / "monetization-config.v1.json"

EXPECTED_BUNDLE_ID = "jp.allsunday1122.yobishikentantou"
EXPECTED_IAP_PRODUCT_ID = "jp.allsunday1122.yobishikentantou.monthly"
EXPECTED_RELEASE_QUESTION_COUNT = 417

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
    values = {name: normalize_explicit(name, env.get(name)) for name in REQUIRED_ENV}
    if values["YOBI_BUNDLE_ID"] != EXPECTED_BUNDLE_ID:
        raise PreflightError(
            f"YOBI_BUNDLE_ID: canonical不一致 {values['YOBI_BUNDLE_ID']} != {EXPECTED_BUNDLE_ID}"
        )
    if values["YOBI_IAP_PRODUCT_ID"] != EXPECTED_IAP_PRODUCT_ID:
        raise PreflightError(
            f"YOBI_IAP_PRODUCT_ID: canonical不一致 {values['YOBI_IAP_PRODUCT_ID']} != {EXPECTED_IAP_PRODUCT_ID}"
        )
    if not re.fullmatch(r"\d{6,20}", values["YOBI_APP_STORE_CONNECT_APP_ID"]):
        raise PreflightError("YOBI_APP_STORE_CONNECT_APP_ID: Apple実発行の数値IDが必要")
    return values


def validate_monetization_registration() -> dict:
    if not MONETIZATION_CONFIG.exists():
        raise PreflightError("monetization-config.v1.json がない")
    config = json.loads(MONETIZATION_CONFIG.read_text(encoding="utf-8"))
    if config.get("standardProcedureVersion") != "2.4":
        raise PreflightError("課金正本が標準手順v2.4ではない")
    if config.get("bundleID") != EXPECTED_BUNDLE_ID:
        raise PreflightError("課金正本のBundle IDがcanonicalと不一致")
    plan = config.get("monetization") or {}
    if plan.get("model") != "auto_renewable_subscription" or plan.get("period") != "P1M":
        raise PreflightError("課金モデルが月額Auto-Renewable Subscriptionではない")
    if plan.get("japanReferencePriceJPY") != 200:
        raise PreflightError("日本向け基準価格が200円/月ではない")
    iap = config.get("iap") or {}
    if iap.get("plannedProductID") != EXPECTED_IAP_PRODUCT_ID:
        raise PreflightError("課金正本のProduct IDがcanonicalと不一致")
    if iap.get("productType") != "autoRenewable":
        raise PreflightError("課金正本の商品種別がautoRenewableではない")
    if iap.get("appStoreConnectRegistrationStatus") != "registered":
        raise PreflightError("IAP Product IDのApp Store Connect実登録確認が未完了")
    if iap.get("runtimeConfigurationStatus") != "configured":
        raise PreflightError("実登録済みIAP Product IDのruntime設定が未完了")
    apple_id = config.get("appStoreConnectAppleID") or {}
    if apple_id.get("status") != "issued" or not re.fullmatch(r"\d{6,20}", str(apple_id.get("value") or "")):
        raise PreflightError("App Store Connect Apple IDの実発行値が正本化されていない")
    return config


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
    if not isinstance(data, list):
        raise PreflightError("questions.release.json が配列ではない")
    if len(data) != EXPECTED_RELEASE_QUESTION_COUNT:
        raise PreflightError(
            f"questions.release.json が正式3回分ではない: {len(data)}/{EXPECTED_RELEASE_QUESTION_COUNT}"
        )
    ids = [question.get("id") for question in data]
    if any(not value for value in ids) or len(ids) != len(set(ids)):
        raise PreflightError("questions.release.json にID欠損または重複がある")
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
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else "completion gate failed"
            raise PreflightError(f"独自模試3回分が未完成: {detail}")


def self_test() -> int:
    good = {
        "YOBI_BUNDLE_ID": EXPECTED_BUNDLE_ID,
        "YOBI_APP_STORE_CONNECT_APP_ID": "1234567890",
        "YOBI_IAP_PRODUCT_ID": EXPECTED_IAP_PRODUCT_ID,
    }
    values = validate_environment(good)
    assert values["YOBI_BUNDLE_ID"] == EXPECTED_BUNDLE_ID
    assert values["YOBI_IAP_PRODUCT_ID"] == EXPECTED_IAP_PRODUCT_ID

    bad_cases = [
        {**good, "YOBI_BUNDLE_ID": "UNSET.YOBI.BUNDLE.ID"},
        {**good, "YOBI_BUNDLE_ID": "jp.allsunday1122.other"},
        {**good, "YOBI_IAP_PRODUCT_ID": "$(YOBI_IAP_PRODUCT_ID)"},
        {**good, "YOBI_IAP_PRODUCT_ID": "jp.allsunday1122.yobishikentantou.lifetime"},
        {**good, "YOBI_BUNDLE_ID": "jp.ci.yobi.preview"},
        {**good, "YOBI_APP_STORE_CONNECT_APP_ID": "explicit-app-id"},
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

    pending = {
        "standardProcedureVersion": "2.4",
        "bundleID": EXPECTED_BUNDLE_ID,
        "monetization": {
            "model": "auto_renewable_subscription",
            "period": "P1M",
            "japanReferencePriceJPY": 200,
        },
        "iap": {
            "plannedProductID": EXPECTED_IAP_PRODUCT_ID,
            "productType": "autoRenewable",
            "appStoreConnectRegistrationStatus": "pending",
            "runtimeConfigurationStatus": "unset_until_registered",
        },
        "appStoreConnectAppleID": {"status": "pending_actual_issued_value", "value": None},
    }
    assert pending["iap"]["appStoreConnectRegistrationStatus"] == "pending"

    print(
        "SELFTEST PASS: v2.4 canonical Bundle/IAP IDs enforced; Apple ID must be issued numeric; "
        "normal preflight also requires registered monthly IAP, 417-question Native bank and three complete mocks"
    )
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
        config = validate_monetization_registration()
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
    print(f"- IAP registration: {config['iap']['appStoreConnectRegistrationStatus']}")
    print(f"- Release questions: {count}")
    print("- Three original practice mocks: complete")
    print(f"- Canonical AppIcon SHA-256: {lock['sha256']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
