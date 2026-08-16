#!/usr/bin/env python3
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        raise AssertionError(f"missing: {rel}")
    return path.read_text(encoding="utf-8")


def require(rel: str, *tokens: str) -> str:
    text = read(rel)
    for token in tokens:
        if token not in text:
            raise AssertionError(f"missing contract {token!r} in {rel}")
    return text


def forbid(rel: str, *tokens: str) -> None:
    text = read(rel)
    for token in tokens:
        if token in text:
            raise AssertionError(f"stale privacy claim {token!r} in {rel}")


SUPPORT_URL = "https://allsunday1122.github.io/splat-native-ios/support.html"
PRIVACY_URL = "https://allsunday1122.github.io/splat-native-ios/privacy.html"
SUPPORT_EMAIL = "kohei3615@gmail.com"

# Permission prompts must describe the actual opt-in behavior.
require(
    "project.yml",
    "INFOPLIST_KEY_NSCameraUsageDescription",
    "INFOPLIST_KEY_NSLocationWhenInUseUsageDescription",
    "Mapへ公開する地点をユーザーが明示的に設定した場合だけ、現在地を取得します。位置情報は自動送信しません。",
)

# Current UI boundary: location is requested only by explicit user action and publish is trusted-package only.
publish = require(
    "SplatNative/PublishScanView.swift",
    "requestCurrentLocation()",
    "manager.requestWhenInUseAuthorization()",
    "現在地を公開地点に設定",
    "投稿するまで送信されません",
    "publishTrustedPackage",
    "このボタンを押すまで3Dファイル・位置情報はサーバーへ送信されません。",
)
if "backend.publish(resultURL:" in publish:
    raise AssertionError("PublishScanView must not call the legacy raw .splat publish path")

require(
    "SplatNative/ScanLabBackend+TrustedPublish.swift",
    "scene.spz",
    "manifest.json",
    "The raw reconstruction `.splat` never leaves the device.",
    "attributesOfItem(atPath: package.assetURL.path)",
)

# Account, UGC interaction, moderation, deletion and published contact paths are network-backed D2 contracts.
require(
    "SplatNative/ScanLabBackend.swift",
    "func signUp(email:",
    "func updateProfile(handle:",
    "func like(_ scan:",
    "func report(_ scan:",
    "func block(_ scan:",
    "func deleteAccount()",
    f'static let supportURL = URL(string: "{SUPPORT_URL}")!',
)
require(
    "SplatNative/ScanLabAccountView.swift",
    'Link("サポート・お問い合わせ", destination: ScanLabConfig.supportURL)',
    f'URL(string: "{PRIVACY_URL}")!',
    "アカウントとクラウドデータを削除",
)
require(
    "supabase/functions/scanlab-delete-account/index.ts",
    'storage.from("scanlab-assets").remove',
    "admin.auth.admin.deleteUser(user.id)",
)
require(
    "supabase/migrations/20260815015516_scanlab_s7_social_backend_v1.sql",
    "references auth.users(id) on delete cascade",
    "scanlab_likes",
    "scanlab_reports",
)

# Privacy manifest must cover all server-retained D2 data categories and the required-reason API.
manifest_path = ROOT / "SplatNative/PrivacyInfo.xcprivacy"
with manifest_path.open("rb") as fh:
    manifest = plistlib.load(fh)

assert manifest.get("NSPrivacyTracking") is False
assert manifest.get("NSPrivacyTrackingDomains") == []

collected = manifest.get("NSPrivacyCollectedDataTypes", [])
by_type = {item.get("NSPrivacyCollectedDataType"): item for item in collected}
expected = {
    "NSPrivacyCollectedDataTypeName",
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypePreciseLocation",
    "NSPrivacyCollectedDataTypeOtherUserContent",
    "NSPrivacyCollectedDataTypeEnvironmentScanning",
    "NSPrivacyCollectedDataTypeProductInteraction",
}
missing = expected - set(by_type)
assert not missing, f"missing privacy data types: {sorted(missing)}"
for kind in expected:
    item = by_type[kind]
    assert item.get("NSPrivacyCollectedDataTypeLinked") is True, kind
    assert item.get("NSPrivacyCollectedDataTypeTracking") is False, kind
    assert "NSPrivacyCollectedDataTypePurposeAppFunctionality" in item.get("NSPrivacyCollectedDataTypePurposes", []), kind

accessed = manifest.get("NSPrivacyAccessedAPITypes", [])
file_timestamp = next(
    (item for item in accessed if item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryFileTimestamp"),
    None,
)
assert file_timestamp is not None, "missing FileTimestamp required-reason declaration"
assert "C617.1" in file_timestamp.get("NSPrivacyAccessedAPITypeReasons", []), "missing FileTimestamp C617.1"

# Public policy and review material must describe the current D2 behavior, not the pre-network build.
for rel in ("privacy.html", "APP_REVIEW_NOTES_JA.md", "APP_STORE_METADATA_JA.md"):
    require(rel, "Supabase", "scene.spz", "manifest.json")

require(
    "privacy.html",
    "非公開",
    "限定リンク",
    "公開",
    "現在地を公開地点に設定",
    "いいね",
    "報告",
    "ブロック",
    "アカウントとクラウドデータを削除",
    "お問い合わせ",
    "./support.html",
    f'mailto:{SUPPORT_EMAIL}',
)

# Apple Guideline 5.1.1(i): policy must cover third-party protection, retention/deletion, and consent withdrawal.
require(
    "privacy.html",
    "第三者サービスとデータ保護",
    "同等以上の保護",
    "広告目的で販売せず",
    "保存期間と削除",
    "機能提供・安全運用に必要な間保持",
    "同意の撤回と設定変更",
    "iOSの設定",
    "すでにクラウドへ送信した位置情報を削除する場合",
    "法令または正当なセキュリティ上の義務",
)

# UGC apps need a reachable published support/contact path in addition to in-app report/block controls.
require(
    "support.html",
    "Scan Lab サポート",
    "お問い合わせ",
    "不適切なコンテンツ・ユーザー",
    "アプリ内の「報告」",
    "「ブロック」",
    "アカウントとクラウドデータの削除",
    f'mailto:{SUPPORT_EMAIL}',
    "./privacy.html",
)
forbid("support.html", "Splat Lab サポート")

# Review/metadata files are implementation-facing and intentionally name the internal visibility enums.
for rel in ("APP_REVIEW_NOTES_JA.md", "APP_STORE_METADATA_JA.md"):
    require(rel, "public", "unlisted", "private")

require(
    "APP_REVIEW_NOTES_JA.md",
    "Environment Scanning",
    "Product Interaction",
    "C617.1",
    "位置情報が自動取得されない",
    SUPPORT_URL,
    PRIVACY_URL,
    SUPPORT_EMAIL,
    "UGC安全機能",
    "保存期間・削除・同意撤回",
    "同等以上の保護",
    "iOS設定で位置情報権限を取り消し",
    "Supabase Auth URL Configuration",
)
require(
    "APP_STORE_METADATA_JA.md",
    "Environment Scanning",
    "Product Interaction",
    "C617.1",
    "App Review Information",
    f"Support URL: `{SUPPORT_URL}`",
    f"Privacy Policy URL: `{PRIVACY_URL}`",
    SUPPORT_EMAIL,
    "本審査前に",
    "第三者サービス / 保存 / 同意撤回",
    "同等以上の保護",
    "Supabase Auth URL Configuration",
)

forbid(
    "privacy.html",
    "現在の版では、撮影画像や生成した3Dデータを開発者のサーバーへ送信しません。",
    "現在の版には、開発者がこれらを受信するための外部API、アカウント機能、解析SDK、広告SDKはありません。",
    "マイク・位置情報・通知・トラッキング: 現在の版では要求しません。",
)
forbid(
    "APP_REVIEW_NOTES_JA.md",
    "現段階ではログインはありません。",
    "Location: 現段階では要求しません。",
    "将来のS7公開共有機能",
)
forbid(
    "APP_STORE_METADATA_JA.md",
    "ログイン: 現段階なし",
    "現段階の外部API: なし",
    "位置情報: 現段階では使用しない",
    "現段階の開発者によるデータ収集: なし",
)

print("PASS: D2 privacy manifest / permissions / retention / consent / third-party / review / UGC support / publish boundary are aligned")
