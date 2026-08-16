#!/usr/bin/env python3
from pathlib import Path
import json
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
PRIVACY_CHOICES_URL = "https://allsunday1122.github.io/splat-native-ios/privacy-choices.html"
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

# The optional cloud preview is a user-associated rendered image and must stay declared as Photos or Videos.
require("SplatNative/ScanModel.swift", "let rendered = trainer.render(cameraIndex: 0)", "self.previewImage = preview")
require("SplatNative/ScanLabShellView.swift", "PublishScanView(resultURL: resultURL, previewImage: model.previewImage)")
require(
    "SplatNative/ScanLabBackend+TrustedPublish.swift",
    "scene.spz",
    "manifest.json",
    "preview.jpg",
    'contentType: "image/jpeg"',
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

# Privacy Manifest describes Scan Lab/app-side collected-data declarations.
manifest_path = ROOT / "SplatNative/PrivacyInfo.xcprivacy"
with manifest_path.open("rb") as fh:
    manifest = plistlib.load(fh)

assert manifest.get("NSPrivacyTracking") is False
assert manifest.get("NSPrivacyTrackingDomains") == []
collected = manifest.get("NSPrivacyCollectedDataTypes", [])
manifest_by_type = {item.get("NSPrivacyCollectedDataType"): item for item in collected}
manifest_expected = {
    "NSPrivacyCollectedDataTypeName",
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypePreciseLocation",
    "NSPrivacyCollectedDataTypePhotosorVideos",
    "NSPrivacyCollectedDataTypeOtherUserContent",
    "NSPrivacyCollectedDataTypeEnvironmentScanning",
    "NSPrivacyCollectedDataTypeProductInteraction",
}
assert set(manifest_by_type) == manifest_expected, f"privacy manifest data types drifted: {sorted(set(manifest_by_type) ^ manifest_expected)}"
for kind in manifest_expected:
    item = manifest_by_type[kind]
    assert item.get("NSPrivacyCollectedDataTypeLinked") is True, kind
    assert item.get("NSPrivacyCollectedDataTypeTracking") is False, kind
    assert "NSPrivacyCollectedDataTypePurposeAppFunctionality" in item.get("NSPrivacyCollectedDataTypePurposes", []), kind

accessed = manifest.get("NSPrivacyAccessedAPITypes", [])
file_timestamp = next((item for item in accessed if item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryFileTimestamp"), None)
assert file_timestamp is not None, "missing FileTimestamp required-reason declaration"
assert "C617.1" in file_timestamp.get("NSPrivacyAccessedAPITypeReasons", []), "missing FileTimestamp C617.1"

# App Store Connect must include app declarations AND third-party-partner collection.
answers = json.loads(read("APP_STORE_PRIVACY_RESPONSES.json"))
assert answers.get("schema_version") == 2
assert answers.get("tracking") is False
assert answers.get("tracking_domains") == []
assert answers.get("privacy_policy_url") == PRIVACY_URL
assert answers.get("user_privacy_choices_url") == PRIVACY_CHOICES_URL
answer_rows = answers.get("data_types", [])
answer_by_type = {row.get("manifest_type"): row for row in answer_rows}
partner_diagnostic = "NSPrivacyCollectedDataTypeOtherDiagnosticData"
app_store_expected = manifest_expected | {partner_diagnostic}
assert set(answer_by_type) == app_store_expected, f"App Store privacy answer types drifted: {sorted(set(answer_by_type) ^ app_store_expected)}"
assert len(answer_rows) == len(app_store_expected), "duplicate App Store privacy answer type"
assert manifest_expected < app_store_expected
assert set(manifest_by_type).issubset(set(answer_by_type)), "App Store answers must cover every Manifest data type"

for kind in app_store_expected:
    row = answer_by_type[kind]
    assert row.get("collected") is True, kind
    assert row.get("purposes") == ["App Functionality"], kind
    assert row.get("linked_to_user") is True, kind
    assert row.get("used_for_tracking") is False, kind
    assert row.get("app_store_name"), kind
    assert row.get("evidence"), kind

diagnostic = answer_by_type[partner_diagnostic]
assert diagnostic.get("app_store_name") == "Other Diagnostic Data"
assert diagnostic.get("source_scope") == "third_party_partner"
assert diagnostic.get("manifest_declared") is False
for token in ("Supabase Auth", "IP address", "user agent", "security"):
    assert token.lower() in diagnostic.get("condition", "").lower(), token

reason_rows = answers.get("required_reason_apis", [])
reason = next((row for row in reason_rows if row.get("category") == "NSPrivacyAccessedAPICategoryFileTimestamp"), None)
assert reason is not None
assert "C617.1" in reason.get("reasons", [])

# Public policy and review material must describe current D2 behavior and third-party auth audit collection.
for rel in ("privacy.html", "APP_REVIEW_NOTES_JA.md", "APP_STORE_METADATA_JA.md"):
    require(rel, "Supabase", "scene.spz", "manifest.json", "IPアドレス", "User-Agent", "監査ログ")

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
    "preview.jpg",
    "写真ライブラリから選択した画像ではなく",
    "アカウントと認証ログ",
    "不正利用・不正アクセス",
    "アカウント削除と同時に必ず消去されるとは限りません",
    "広告、マーケティング、ユーザートラッキングには利用しません",
    "./privacy-choices.html",
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
    "法令または正当なセキュリティ上の義務",
)

require(
    "privacy-choices.html",
    "Scan Lab プライバシー設定・削除",
    "位置情報の利用をやめる",
    "公開だけを停止する",
    "クラウドスキャンを削除する",
    "アカウントとクラウドデータを削除する",
    "preview画像",
    "Supabase Auth",
    "監査ログ",
    "アカウント削除と同時に必ず消去されるとは限りません",
    "広告・トラッキングには利用しません",
    "./support.html",
    "./privacy.html",
    f'mailto:{SUPPORT_EMAIL}',
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

for rel in ("APP_REVIEW_NOTES_JA.md", "APP_STORE_METADATA_JA.md"):
    require(
        rel,
        "public",
        "unlisted",
        "private",
        "Other Diagnostic Data",
        "APP_STORE_PRIVACY_RESPONSES.json",
        "9項目",
        "第三者パートナー",
        "Privacy Manifest",
        "包含",
        "C617.1",
        SUPPORT_URL,
        PRIVACY_URL,
        PRIVACY_CHOICES_URL,
        SUPPORT_EMAIL,
        "Supabase Auth URL Configuration",
        "jp.allsunday1122.splatlab://password-recovery",
    )

require(
    "APP_REVIEW_NOTES_JA.md",
    "Photos or Videos",
    "Environment Scanning",
    "Product Interaction",
    "位置情報が自動取得されない",
    "UGC安全機能",
    "保存期間・削除・同意撤回",
    "同等以上の保護",
    "Supabase Authの監査ログはこのcascade対象ではありません",
)
require(
    "APP_STORE_METADATA_JA.md",
    "Photos or Videos",
    "Environment Scanning",
    "Product Interaction",
    "App Review Information",
    f"Support URL: `{SUPPORT_URL}`",
    f"Privacy Policy URL: `{PRIVACY_URL}`",
    f"User Privacy Choices URL: `{PRIVACY_CHOICES_URL}`",
    "本審査前に",
    "第三者サービス / 保存 / 同意撤回",
    "同等以上の保護",
    "partner-only",
)

# Never regress to the false assumption that third-party-partner App Store answers must exactly equal app-manifest rows.
forbid("APP_REVIEW_NOTES_JA.md", "Manifestとのdata type完全一致")
forbid("APP_STORE_METADATA_JA.md", "Privacy ManifestとこのJSONのdata type集合はCIで完全一致")

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

print("PASS: D2 privacy manifest is covered by App Store answers; Supabase Auth partner diagnostics, deletion retention, permissions, review and UGC contracts are aligned")
