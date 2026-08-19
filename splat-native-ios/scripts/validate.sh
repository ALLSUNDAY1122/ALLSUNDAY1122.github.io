#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_file() { test -f "$1" || { echo "missing: $1"; exit 1; }; }
require_text() { grep -q "$2" "$1" || { echo "missing contract '$2' in $1"; exit 1; }; }

# Project / legal / privacy
require_file project.yml
require_file SplatNative/PrivacyInfo.xcprivacy
require_file APP_REVIEW_NOTES_JA.md
require_file SplatNative/Resources/Licenses/msplat-APACHE-2.0.txt
require_file SplatNative/Resources/Licenses/MetalSplatter-MIT.txt
require_text project.yml 'jp.allsunday1122.splatlab'
require_text project.yml 'MARKETING_VERSION: 1.0.0'
require_text project.yml 'SplatNative/CapturePolicy.swift'
require_text project.yml 'SplatNative/SplatViewerState.swift'
require_text project.yml 'SplatNative/ScanProjectStore.swift'

# S1 capture / recovery
for f in ScanModel.swift ScanModel+SessionLifecycle.swift CapturePolicy.swift RootScanView.swift CapturePolicyTests.swift; do
  if [[ "$f" == *Tests.swift ]]; then require_file "SplatNativeTests/$f"; else require_file "SplatNative/$f"; fi
done
require_text SplatNative/ScanModel.swift 'CapturePolicy.shouldAcceptFrame'
require_text SplatNative/ScanModel.swift 'CapturePolicy.coverageSatisfied'
require_text SplatNative/ScanModel.swift 'sceneDepth'
require_text SplatNative/ScanModel.swift 'func pauseCapture'
require_text SplatNative/ScanModel.swift 'func resumeCapture'
require_file SplatNative/ScanWorldMapArchiveStore.swift
require_text SplatNative/ScanModel.swift 'persistWorldMapForTransition'
require_text SplatNative/ScanModel.swift 'schedulePeriodicWorldMapPersistence'
require_text SplatNative/ScanModel.swift 'isWorldMapPersistencePending'
require_text SplatNative/ScanModel.swift 'restoreSavedProject'
require_text SplatNative/ScanModel+SessionLifecycle.swift 'sessionShouldAttemptRelocalization'
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
resume=s.index('func resumeCapture()')
finish=s.index('func finishCapture()')
block=s[resume:finish]
assert 'var options: ARSession.RunOptions = []' in block
assert 'if let worldMap = pendingResumeWorldMap' in block
assert 'config.initialWorldMap = worldMap' in block
assert 'options = [.resetTracking, .removeExistingAnchors]' in block
assert 'session.run(config, options: options)' in block
print('PASS: in-memory resume preserves coordinates; cold resume restores ARWorldMap')
PY

# S2 reconstruction / resource safety
for f in SplatReconstructionPolicy.swift SplatSeedColorizer.swift SplatSkySeeder.swift SplatResourceGuard.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/ScanModel.swift 'trainer.saveCheckpoint'
require_text SplatNative/ScanModel.swift 'trainer.loadCheckpoint'
require_text SplatNative/ScanModel.swift 'SplatSkySeeder.makeSeeds'
require_text SplatNative/ScanModel.swift 'passResourceGuard.evaluate'
require_text SplatNative/SplatReconstructionPolicy.swift 'trainingHorizon = 30_000'
require_text SplatNative/SplatReconstructionPolicy.swift 'standardIterations = 7_000'
require_text SplatNative/SplatReconstructionPolicy.swift 'enhancementIncrement = 5_000'

# S3 viewer / edit / measure
for f in SplatViewer.swift SplatViewerState.swift SplatResultView.swift; do require_file "SplatNative/$f"; done
require_file SplatNativeTests/SplatViewerStateTests.swift
require_text SplatNative/SplatViewer.swift 'robustFraming(for: points)'
require_text SplatNative/SplatViewer.swift 'scenePan'
require_text SplatNative/SplatViewer.swift 'measureTap'
require_text SplatNative/SplatViewer.swift 'editedPoints'
require_text SplatNative/SplatResultView.swift '切り抜き'
require_text SplatNative/SplatResultView.swift '調整'
require_text SplatNative/SplatResultView.swift '計測'
require_text SplatNative/SplatResultView.swift '品質向上'

# B Mesh
for f in MeshScanModel.swift MeshScanView.swift MeshAdvancedSupervisor.swift MeshDepthRecorder.swift MeshLiDARDenseFusion.swift MeshDenseMVS.swift MeshDenseTextureBaker.swift MeshGeometryRefiner.swift MeshAppearanceEditor.swift MeshTrimEditor.swift MeshDetailSimplifier.swift MeshRawReprocess.swift MeshARViewer.swift MeshParityAuditor.swift MeshAssetContract.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/MeshScanModel.swift 'sceneReconstruction'
require_text SplatNative/MeshScanModel.swift 'PhotogrammetrySession'
require_text SplatNative/MeshScanView.swift '2点タップで計測'
require_text SplatNative/MeshAdvancedSupervisor.swift 'MeshDepthRecorder'
require_text SplatNative/MeshAdvancedSupervisor.swift 'fuseLiDARDenseDepth'
require_text SplatNative/MeshAdvancedSupervisor.swift 'refineMetricGeometry'
require_text SplatNative/MeshAdvancedSupervisor.swift 'bakeDenseRGBTextureAtlas'
require_text SplatNative/MeshAdvancedSupervisor.swift 'runMeshParityAudit'
require_text SplatNative/RootScanView.swift 'Meshをスキャン'

# C local library / durable resume foundation.
require_file SplatNative/ScanProjectStore.swift
require_file SplatNative/ScanLibraryView.swift
require_file SplatNativeTests/ScanProjectStoreTests.swift
require_file SplatNativeTests/ScanColdResumePersistenceTests.swift
require_text SplatNative/ScanProjectStore.swift 'commitPendingSplat'
require_text SplatNative/ScanProjectStore.swift 'reprocessRequest'
require_text SplatNative/ScanProjectStore.swift 'moveToTrash'
require_text SplatNative/ScanProjectStore.swift 'recoverInterruptedProcessing'
require_text SplatNative/ScanProjectStore.swift 'worldMapURL'
require_text SplatNative/ScanLibraryView.swift 'restoreSavedProject'

! grep -R -n 'おもちゃばこ' SplatNative project.yml

# D authenticated cloud sharing is explicit and isolated from capture/reconstruction core.
for f in ScanLabBackend.swift ScanLabBackend+TrustedPublish.swift ScanLabBackend+PublishLifecycle.swift ScanLabShellView.swift ScanLabDiscoverFeedStore.swift ScanLabProfilePolicy.swift ScanLabProfileService.swift ScanLabProfileView.swift ScanLabSessionPolicy.swift ScanLabPublishPackage.swift ScanLabGeotagPolicy.swift ScanReportPolicy.swift ScanReportBackend.swift PublicBrowsePolicy.swift PublishScanView.swift ScanLabAccountView.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/SplatNativeApp.swift 'ScanLabShellView()'
require_text SplatNative/ScanLabShellView.swift 'RootScanView()'
require_text SplatNative/ScanLabBackend.swift 'import Supabase'
require_text SplatNative/ScanLabBackend.swift 'ScanLabVisibility'
require_text SplatNative/ScanLabBackend.swift 'func deleteAccount() async throws'
require_text SplatNative/ScanLabBackend+TrustedPublish.swift 'ScanLabUploadInitRequest'
require_text SplatNative/ScanLabBackend+TrustedPublish.swift 'ScanLabUploadValidateRequest'
require_text SplatNative/ScanLabBackend+TrustedPublish.swift 'cleanupFailedDraft'
require_text SplatNative/PublishScanView.swift 'contentConfirmed'
require_text SplatNative/PublishScanView.swift 'publicPlaceConfirmed'
require_text SplatNative/PublishScanView.swift '位置情報を付けなくてもDiscoverへ公開できます'
require_text SplatNative/ScanLabDiscoverFeedStore.swift 'URLQueryItem(name: "cursor"'
require_text SplatNative/ScanLabDiscoverFeedStore.swift 'URLQueryItem(name: "q"'
require_text SplatNative/ScanLabShellView.swift 'searchable'
require_text SplatNative/ScanLabShellView.swift '続きを再試行'
require_text SplatNative/ScanLabShellView.swift 'ScanReportReason.allCases'
require_text SplatNative/ScanLabShellView.swift 'backend.submitReport(scan'
require_text SplatNative/ScanLabShellView.swift 'backend.hasReported(scan)'
require_text project.yml 'package: Supabase'
require_text project.yml 'INFOPLIST_KEY_NSCameraUsageDescription'
require_text project.yml 'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription'
! grep -qE 'INFOPLIST_KEY_NSLocationAlways|INFOPLIST_KEY_NSLocationAlwaysAndWhenInUse' project.yml
! grep -qE 'INFOPLIST_KEY_NSPhotoLibrary|INFOPLIST_KEY_NSMicrophoneUsageDescription|INFOPLIST_KEY_NSUserTrackingUsageDescription' project.yml
! grep -nE 'URLSession|Supabase' SplatNative/ScanModel.swift SplatNative/ScanModel+SessionLifecycle.swift SplatNative/SplatReconstructionPolicy.swift SplatNative/ScanProjectStore.swift
! grep -R -nE 'Firebase|Amplitude|Mixpanel|AppsFlyer|Adjust' SplatNative --include='*.swift'

# D2-001: hosted Auth readiness is probed without creating a user; live E2E uses GitHub Secrets only.
require_file scripts/scanlab_auth_readiness.mjs
require_file scripts/scanlab_auth_e2e.mjs
require_file ../.github/workflows/splat-native-ios.yml
require_text scripts/scanlab_auth_readiness.mjs '/auth/v1/settings'
require_text scripts/scanlab_auth_readiness.mjs 'external?.email'
require_text scripts/scanlab_auth_readiness.mjs 'disable_signup'
require_text ../.github/workflows/splat-native-ios.yml 'Hosted ScanLab auth readiness gate'
require_text ../.github/workflows/splat-native-ios.yml 'node splat-native-ios/scripts/scanlab_auth_readiness.mjs'
require_text ../.github/workflows/splat-native-ios.yml 'Live ScanLab auth/session/profile E2E gate'
require_text ../.github/workflows/splat-native-ios.yml 'secrets.SCANLAB_E2E_EMAIL'
require_text ../.github/workflows/splat-native-ios.yml 'secrets.SCANLAB_E2E_PASSWORD'
require_text ../.github/workflows/splat-native-ios.yml 'LIVE_E2E_BLOCKED_BY_TEST_IDENTITY'
require_text ../.github/workflows/splat-native-ios.yml 'node splat-native-ios/scripts/scanlab_auth_e2e.mjs'
! grep -R -nE 'SCANLAB_E2E_(EMAIL|PASSWORD)=' scripts . --exclude='validate.sh' --exclude-dir='.git'

# D2-002 session persistence / refresh / expired-session recovery.
require_file SplatNativeTests/ScanLabSessionPolicyTests.swift
bash scripts/test_session_policy.sh

# D2-003 profile / public profile / avatar policy.
require_file SplatNativeTests/ScanLabProfilePolicyTests.swift
require_text SplatNative/ScanLabProfileService.swift 'scanlab_public_profile'
require_text SplatNative/ScanLabProfilePolicy.swift 'normalizedAvatarURL'

# D2-004 trusted upload entry / authorization / validation.
require_file supabase/functions/scanlab-upload/index.ts
python3 scripts/d2_trusted_upload_gate.py

# D2-005 publish package / scene.spz / manifest integrity.
require_file SplatNativeTests/ScanLabPublishPackageTests.swift
require_text SplatNative/ScanLabPublishPackage.swift 'scene.spz'
require_text SplatNative/ScanLabPublishPackage.swift 'manifest.json'
require_text SplatNative/ScanLabPublishPackage.swift 'SHA256.hash'

# D2-006 durable asset URL / browser Range retrieval.
require_file supabase/functions/scanlab-public/asset_delivery.mjs
node scripts/test_scanlab_public_asset_delivery.mjs

# D2-007 public / unlisted / private visibility lifecycle.
node supabase/functions/scanlab-visibility/visibility_contract.test.mjs
require_text supabase/functions/scanlab-visibility/index.ts '#token='

# D2-008 + D2-009 browser viewer loading/error/retry + share metadata.
for f in viewer/index.html viewer/viewer.js viewer/viewer.css viewer/share-url.js; do require_file "$f"; done
require_text viewer/viewer.js 'history.replaceState'
require_text viewer/viewer.js 'previewImageUrl'
require_text viewer/viewer.js 'runtime_load_failed'
require_text viewer/index.html 'no-referrer'

# D2-010 explicit optional geotag privacy boundary.
require_file SplatNativeTests/ScanLabGeotagPolicyTests.swift
python3 scripts/test_geotag_publish_contracts.py

# D2-011 Map query / published geotag display.
require_file SplatNative/ScanLabMapQuery.swift
require_file SplatNativeTests/ScanLabMapQueryTests.swift
require_text SplatNative/ScanLabShellView.swift 'ScanLabMapBounds.make'

# D2-012 Discover cursor / search / pagination / empty / error / retry.
python3 - <<'PY'
from pathlib import Path
edge=Path('supabase/functions/scanlab-public/index.ts').read_text()
store=Path('SplatNative/ScanLabDiscoverFeedStore.swift').read_text()
for needle in [
    'const cursor = parseCursor(url.searchParams.get("cursor"))',
    'const q = (url.searchParams.get("q") ?? "").trim().slice(0, 80)',
    'if (q) query = query.ilike("title"',
    '.order("published_at", { ascending: false })',
    '.order("id", { ascending: false })',
    'nextCursor',
]: assert needle in edge, needle
for needle in [
    'let nextCursor: String?',
    'URLQueryItem(name: "cursor", value: cursor)',
    'URLQueryItem(name: "q", value: String(query.prefix(80)))',
    'seenCursors.insert(next).inserted',
    'guard hasMore, errorMessage == nil, !isLoadingInitial, !isLoadingMore, let cursor = nextCursor else { return }',
]: assert needle in store, needle
assert 'URLQueryItem(name: "offset"' not in store
print('D2-012 Discover cursor/search regression gate PASS')
PY

# D2-013 public profile -> other-user public scan browse.
require_text SplatNative/ScanLabShellView.swift 'ScanLabAuthorScanBrowserView'
require_text SplatNative/ScanLabShellView.swift 'ScanLabPublicProfileView(handle: author.handle)'

# D2-014 owner unpublish / republish lifecycle.
require_file supabase/functions/scanlab-unpublish/index.ts
require_text SplatNative/ScanLabBackend+PublishLifecycle.swift 'unpublishPublishedScan'
require_text SplatNative/ScanLabBackend+PublishLifecycle.swift 'func republish'

# D2-015 owner scan delete / asset cleanup / delete recovery.
python3 scripts/test_d2_owner_delete.py

# D2-016 account delete / owned data cleanup / auth cleanup.
require_file tests/account-delete-contract.test.mjs
require_file tests/account-delete-live-e2e.ts
node tests/account-delete-contract.test.mjs

# D2-017 report reason / persistence / duplicate prevention.
require_file SplatNativeTests/ScanReportPolicyTests.swift
require_text SplatNative/ScanReportBackend.swift 'scanlab_submit_report'
require_text SplatNative/ScanReportBackend.swift 'scanlab_has_reported'
if grep -q 'backend.report(scan' SplatNative/ScanLabShellView.swift; then echo 'legacy report UI path detected'; exit 1; fi

# D2-018 block / unblock / visibility and interaction suppression.
require_text supabase/functions/scanlab-public/index.ts 'blockedUserIds'
require_text supabase/functions/scanlab-public/index.ts 'blocked.has(data.owner_id)'
require_text SplatNative/ScanLabBackend.swift 'func unblock('
require_text SplatNative/ScanLabAccountView.swift 'ScanLabBlockedUsersSection'

# D2-019 moderation / rate-limit / abuse failure handling.
python3 scripts/verify_d2_w19_safety.py

# HQ-only cross-worker conflict checks: catches contracts no single worker can see.
node scripts/d2_hq_integration_contracts.mjs

# D2-020: privacy manifest, permission strings and review explanation must move together.
plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null
python3 - <<'PY'
import plistlib
from pathlib import Path
with open('SplatNative/PrivacyInfo.xcprivacy','rb') as f:
    data=plistlib.load(f)
assert data.get('NSPrivacyTracking') is False
assert data.get('NSPrivacyTrackingDomains') == []
collected = data.get('NSPrivacyCollectedDataTypes', [])
by_type = {item.get('NSPrivacyCollectedDataType'): item for item in collected}
expected = {
    'NSPrivacyCollectedDataTypeName',
    'NSPrivacyCollectedDataTypeEmailAddress',
    'NSPrivacyCollectedDataTypeUserID',
    'NSPrivacyCollectedDataTypePreciseLocation',
    'NSPrivacyCollectedDataTypeOtherUserContent',
}
assert set(by_type) == expected, (set(by_type), expected)
for kind in expected:
    item = by_type[kind]
    assert item.get('NSPrivacyCollectedDataTypeLinked') is True
    assert item.get('NSPrivacyCollectedDataTypeTracking') is False
    assert item.get('NSPrivacyCollectedDataTypePurposes') == ['NSPrivacyCollectedDataTypePurposeAppFunctionality']
assert data.get('NSPrivacyAccessedAPITypes') == []

project=Path('project.yml').read_text()
review=Path('APP_REVIEW_NOTES_JA.md').read_text()
assert '周囲を撮影して端末内で3Dスキャンを生成するため、カメラを使用します。' in project
assert 'Mapへ公開する地点をユーザーが明示的に設定した場合だけ、現在地を取得します。位置情報は自動送信しません。' in project
for phrase in ['Camera:', 'Location When In Use:', 'Tracking:', 'Name:', 'Email Address:', 'User ID:', 'Precise Location:', 'Other User Content:', 'NSPrivacyTracking = false']:
    assert phrase in review, phrase
assert '現段階ではログインはありません' not in review
assert 'Location: 現段階では要求しません' not in review
print('PASS: D2 privacy manifest / permissions / App Review explanation are aligned')
PY

echo 'PASS: integrated Scan Lab static contracts'
