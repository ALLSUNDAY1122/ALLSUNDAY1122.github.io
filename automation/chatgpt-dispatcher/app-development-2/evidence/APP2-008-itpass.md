# APP2-008｜ITパスポート｜ホームボタン/UI統一修正

- Task: `APP2-008`
- Worker role: `ITPASS`
- Session: `ITパスポート②`
- Completed: 2026-08-19 12:44 JST
- Machine status: `DONE`

## Live source-of-truth recheck

- Notion: `IT Passport｜学びスプリント 正本・開発記録` を再取得。2026-08-18の実機報告では「問題画面のホームが押せない」が最優先不具合で、原因はHTML側 `confirm()` とSwift `WKWebView` wrapperの `WKUIDelegate` 不足だった。
- Golden Master: `学びスプリント｜UI要件定義テンプレ v2.1` を最上位正本として採用。8問、4タブ、生成り紙、藍/朱/緑/金、明朝、進捗リング、手書き風○×、「ここだけ覚える」を基準とした。
- Product source: `ALLSUNDAY1122/it-passport-quiz-ios` の `main`。旧Safari MVP/旧TestFlight履歴ではなく、現行iOS製品sourceを対象とした。
- App Store Connect app: Apple ID `6796310458`, bundle `jp.allsunday1122.itpassportquiz`。

## Existing home/UI fix verification

2026-08-18の既存PR #3で、現行 `ContentView.swift` には以下が既にmainへ統合済みであることを再確認した。

- `webView.uiDelegate = context.coordinator`
- JavaScript `confirm()` を扱う `WKUIDelegate` 実装
- `quizHomeBtn` をcapture phaseで補強し、旧HTMLのhome処理を実行した上で `tab('home')` へ戻す処理
- Golden Master v2.1準拠の8問スプリント、4タブ、生成りUI、進捗リング、○×表示、「ここだけ覚える」

旧 `nomikai-arcade.html` のhome処理が `confirm()` を必須としていることも照合し、報告された不具合の原因と現行修正が対応していることを静的回帰で確認した。

## Newly found release blocker

ホーム/UI修正後の2026-08-18 Codemagic build `6a844e4326bd5cce6b0a54b8` は `failed` で、新TestFlightへ到達していなかった。

追加監査で以下のrelease blockerを特定した。

1. `scripts/prepare-approved-icon.sh` が `ApprovedSource.webp` を `EXPECTED_BYTES=44020` と固定検証していたが、GitHub mainの実blobは7,767 bytesであり、assertで必ず停止する状態だった。
2. scriptは承認済み1024px PNGを `AppIcon-1024-resubmission.png` に生成する一方、`Assets.xcassets/AppIcon.appiconset/Contents.json` は `AppIcon-1024.png` を参照しており、承認済みiconが製品assetへ接続されていなかった。
3. release buildごとのImageMagick install/conversionは不要で、失敗点を増やしていた。

## APP2-008 implementation

Implementation branch: `automation/app2-008-itpass-build-fix`

PR #5 `Fix IT Passport approved AppIcon release build` を作成し、以下だけを変更した。ホーム/UI実装自体は再改変していない。

- `Contents.json` を既存承認済み `AppIcon-1024-resubmission.png` へ接続
- `prepare-approved-icon.sh` を、承認PNGの1024x1024寸法 + Git blob SHA `7f09091a0e293ebce4b7a79dbcabd93bf8d2a9e7` の固定検証へ変更
- `BUILD_NUMBER` → `CURRENT_PROJECT_VERSION` 注入は維持
- Codemagicから不要なImageMagick installを削除

PR #5はsquash merge済み。

- merge commit: `a951f177ba315b460eae51d33eb2c4dc99c8bb88`
- main read-backで上記3ファイルの反映を確認済み

## New release regression

Codemagic one-shot safe triggerを一時的に復元し、固定appId / `ios-native` / `main` のみで新Buildを開始。開始後にone-shot workflowは削除し、mainで404 read-backを確認した。

- Codemagic Build ID: `6a8522e1df20d976398c2bd5`
- source commit: `a951f177ba315b460eae51d33eb2c4dc99c8bb88`
- branch: `main`
- workflow: `IT Passport Manabi Sprint iOS TestFlight`
- Codemagic index / build number: `9`
- IPA: `NomikaiArcade.ipa`
- Codemagic terminal status: `finished`
- Codemagic ASC status at completion: `processing`

App Store Connectを再取得し、新Build 9を確認。

- ASC Build: `9`
- ASC Build ID: `b8696e68-7b4f-4cfd-b5e2-2e93f215f3f3`
- processingState: `VALID`
- 旧最新Build 3から正常更新されたことを確認

## Regression result

PASS:

- 現行製品sourceとGolden Masterを確定
- home不能の元原因と現行home修正を再照合
- Golden Master v2.1共通UI差分を現行mainで確認
- release blockerを修正
- 修正後mainから署名IPA生成成功
- Codemagic build成功
- App Store Connect Build 9 `VALID`
- one-shot trigger削除をread-back

実機上の最終タップ確認はこのWorker環境からは直接実行できないため、新Build 9で「学習中にホーム → ホームへ復帰」「4タブ」「8問リング」「分野導線」「○×/ここだけ覚える」のsmoke確認を行うと、端末側までの完全な閉ループになる。これは今回のmachine taskを止めるhuman decision gateではない。
