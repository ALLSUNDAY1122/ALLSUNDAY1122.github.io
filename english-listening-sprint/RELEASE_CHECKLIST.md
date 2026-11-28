# English Listening Sprint — TestFlight checklist

更新日: 2026-08-29

## 完成版受け入れ

- [x] SwiftUIが主UIで、WebViewラッパーではない
- [x] 30レッスン／90設問／5地域を確認
- [x] 312本の音声参照が一意で、欠落なし
- [x] iOSリソースに教材JSON 3ファイルと音声フォルダを登録
- [x] 学習完了状態は端末内UserDefaultsだけに保存
- [x] 広告、分析、ログイン、課金、外部教材取得なし
- [ ] macOS/Xcodeで起動と全主要導線を確認
- [ ] iPhoneでオフライン、バックグラウンド再生、保存を確認

## iOS／申請素材

- [x] Bundle ID: `jp.allsunday1122.englishlistening`
- [x] Version: `1.0.0`
- [x] Build: `1`
- [x] Apple Team ID: `MN3D2ZM44N`
- [x] 1024×1024 App Iconを配置
- [x] Privacy Manifestを配置
- [x] UserDefaultsのRequired Reason API `CA92.1`を宣言
- [x] 非免除暗号化なしをInfo.plistに宣言
- [x] サポート／プライバシーページを公開
- [x] 公開HTTPSでサポート／プライバシーのHTTP 200を確認
- [x] App Store Connect入力原稿を作成
- [ ] App Store Connect App IDを作成して記録
- [ ] Apple Developer Explicit App IDを確認
- [ ] スクリーンショットを実機またはSimulatorから取得（本審査前）

## ビルド／TestFlight

- [x] ルート`codemagic.yaml`へTestFlight内部専用ワークフローを追加
- [x] `submit_to_testflight: true`を設定
- [x] `submit_to_app_store: false`を設定
- [x] Internal-only exportを設定
- [ ] CodemagicでApple署名連携を読み戻す
- [ ] 署名付きIPAを作成
- [ ] IPA内のBundle ID、教材、音声、署名を自動検査
- [ ] App Store Connectでビルド処理完了を確認
- [ ] 内部テストグループへBuildを割り当て
- [ ] TestFlight実機確認を完了

## 禁止事項

- App Store本審査の`Add for Review`／`Submit for Review`は、依頼者の最終承認なしに実行しない。
- パスワード、2FAコード、APIキー、秘密鍵、個人の電話番号をファイルやGitへ保存しない。
