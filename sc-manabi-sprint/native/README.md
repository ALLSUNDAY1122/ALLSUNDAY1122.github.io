# iOS製品化 scaffold

Safari製品候補版 v2140 を、URL表示ではなくアプリ内同梱コンテンツとしてiOSへパッケージするための構成です。

## 方針
- Capacitor 8.4.2でiOSネイティブコンテナを生成する。
- 325問データを含むWeb資産を `native/www` へコピーしてアプリに同梱する。
- 通常学習はネットワーク接続なしで動作させる。
- IPA等の一次根拠リンクだけユーザー操作で外部サイトを開く。
- 初版は広告SDK、解析SDK、ログイン、クラウド同期を導入しない。
- 初版はiPhone縦向き体験へ集中し、iPad対応は別UI監査後の将来候補とする。

## 暫定識別子
- App ID / Bundle ID: `jp.allsunday1122.scmanabisprint`
- App Name: `情報処理安全確保支援士`
- Version: `1.0.0`
- Build: `1`

Bundle IDはApp Store Connect登録前の最終人間確認で確定する。

## Mac / Cloud Macでの生成
```bash
cd sc-manabi-sprint/native
npm install
npm run prepare:web
npm run ios:add
npm run ios:sync
npm run ios:open
```

`ios:add` / `ios:sync` は `configure-ios.sh` を呼び、次を自動適用する。
- `PrivacyInfo.xcprivacy` をアプリターゲットへ配置
- `ITSAppUsesNonExemptEncryption = NO`
- iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)
- Version `1.0.0` / Build `1`

## Xcodeで人間入力が必要な項目
1. Signing & CapabilitiesでApple Developer Teamを選択。
2. Bundle IdentifierをApp Store Connectで確定した値に合わせる。
3. 最終App IconをAssetsへ設定する。
4. ArchiveしてTestFlightへアップロードする。
5. TestFlight実機でオフライン起動、8問スプリント、模試、記録、設定、外部リンクを再確認する。
6. App Store用スクリーンショットを実アプリ画面から取得する。

## 自動監査
`.github/workflows/sc-manabi-ios-preflight.yml` がmacOS上で以下を検査する。
- 325問同梱資産
- 13問／12問模試分割
- データ初期化・プライバシー導線
- Privacy Manifest
- 輸出コンプライアンスInfo.plistキー
- iPhone-only、Version/Build
- unsigned Simulator Debug build
- unsigned physical-device Release build
- 生成`.app`内の問題データ・UIパッチ・Privacy Manifest

## 再発火原則
問題データ、解説、権利表示、保存方式、SDK、広告、解析、外部通信、課金、対象端末を変更した場合、該当する問題・制度・著作権・プライバシー・実装・申請前監査を再実施する。
