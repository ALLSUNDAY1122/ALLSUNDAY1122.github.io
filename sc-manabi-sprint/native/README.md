# iOS製品化 scaffold

Safari製品候補版 v2140 を、URL表示ではなくアプリ内同梱コンテンツとしてiOSへパッケージするための構成です。

## 方針
- Capacitor 8.4.2でiOSネイティブコンテナを生成する。
- 325問データを含むWeb資産を `native/www` へコピーしてアプリに同梱する。
- 通常学習はネットワーク接続なしで動作させる。
- IPA等の一次根拠リンクだけユーザー操作で外部サイトを開く。
- 初版は広告SDK、解析SDK、ログイン、クラウド同期を導入しない。

## 暫定識別子
- App ID / Bundle ID: `jp.allsunday1122.scmanabisprint`
- App Name: `情報処理安全確保支援士`

Bundle IDはApp Store Connect登録前の最終人間確認で確定する。

## Mac / Cloud Macでの生成
```bash
cd sc-manabi-sprint/native
npm install
npm run prepare:web
npx cap add ios
npx cap sync ios
npx cap open ios
```

## Xcodeで行う項目
1. Signing & CapabilitiesでTeamを選択。
2. Bundle Identifierを最終確定値に合わせる。
3. `PrivacyInfo.xcprivacy` をAppターゲットのResourcesへ追加する。
4. App IconをAssetsへ設定する。
5. Deployment Targetと対応端末を確認する。
6. Archive前に実機でオフライン起動、8問スプリント、模試、記録、設定を再確認する。

## 再発火原則
問題データ、解説、権利表示、保存方式、SDK、広告、解析、外部通信、課金を変更した場合、該当する問題・制度・著作権・プライバシー・実装・申請前監査を再実施する。
