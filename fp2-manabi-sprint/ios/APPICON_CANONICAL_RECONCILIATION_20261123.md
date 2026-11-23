# FP2 AppIcon 正本照合 — 2026-11-23 JST

## 結果
- 正本台帳（Notion）: https://app.notion.com/p/3b709c10697d812cb85dca00649afa9b
- 指定正本フォルダ（Google Drive）: https://drive.google.com/drive/folders/1pPp5EJZZpv3ScsvyTWhkRMqpcKrgniWh
- 採用版フォルダの直接一覧は50件、内訳は資格アイコン等と `icon_manifest.json`。FP2級専用PNGは見つからなかった。
- `icon_manifest.json` には開発連番01–43の資格名/PNG対応を収録。FP2級の資格名・PNGは収録されていない。
- Notionの正本ページにはITパスポート、衛生管理者、登録販売者等の記録があるが、FP2 AppIconのDrive file IDとSHA-256はない。
- 現行iOSファイル: `fp2-manabi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- 現行ファイルのSHA-256: `d456178b2a7b04f180e39b3ad62f5c194832e85aa15102bf6452751551db8033`
- 現行ファイルのGit Blob SHA-1: `ce0cb5bc61296d7ca2ebde213c729ae5d1e4ab9d`（SHA-256ではない）
- 現行ファイルは1024×1024ピクセル / PNG RGB color type 2 / アルファなし。
- 旧実装: `feature/fp2-kakomon-coach:fp2-kakomon-coach/ios-app/assets/icon.png` からコピーされた既存候補。
- **登録済み正規FP2アイコンのSHA-256: NOT FOUND。** `current == canonical` は未判定。
- 不明な原典を推測したりFP3画像と取り違えての置換は行っていない。

## 実行した是正
1. `ios/appicon-provenance.json` に出典・現行SHA・正本不在を記録。
2. `ios/verify-appicon.py` で1024×1024・RGB・現行SHAを確認し、正規SHAが未確定なら出荷ゲートをFail Closedする。
3. `.github/workflows/fp2-ios-native-ci.yml` に個別 `canonical-appicon-gate` jobを追加。Simulatorコンパイルとは独立して失敗理由を確認できる。
4. `automation/app-release-registry.json` のFP2項目に実測現行SHA・正本未特定フラグを反映。

## CI結果
- 対象GitHub Actions: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45148389564
- `canonical-appicon-gate`: FAIL（正本未登録、意図した安全停止）。現行SHAの計算・RGB 1024×1024検査はPASS。
- `static-and-native-simulator`: **PASS**（XcodeGen、署名なしiOS Simulatorビルド、Info.plist、正規教材のバンドル読戻し）。旧Run 45146663362もPASS。\n- CI全体: **FAIL**（アイコン正本不明のため、意図したFail Closed）。
- この検査のFAILをPNG破損・Xcodeコンパイル失敗と混同しない。

## 解決条件
採用版フォルダに正式FP2専用PNGを特定または正本登録し、Drive IDとSHA-256を確定する。バイト一致を検査してからのみiOSアセットを差し替え、provenanceのcanonical SHAを更新してCIをPASSにする。
App Store Connect上の元画像の実バイトや記録済みSHAの読戻しはこの照合では未実施。App Review提出・マージ・署名Buildは行っていない。
