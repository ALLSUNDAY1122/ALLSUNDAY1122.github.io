# 情報処理安全確保支援士｜学びスプリント
## 本実装・申請引継ぎ

更新基準日: 2026-08-10

> このファイル名は申請手順の標準読込順に合わせて `CODEX_HANDOFF.md` としているが、内容はCodex / Claudeどちらへ引き継いでも使える。会話履歴の進捗数字ではなく、GitHub・Notion・CIを正とする。

## 0. 最初に読む正本

Notion:
1. AIアプリ開発 標準手順 v2.2
2. 申請手順
3. 学びスプリント UI要件定義テンプレ v2.1 Golden Master
4. 学びスプリント｜問題生成・監査ループ v1.0
5. 情報処理安全確保支援士試験｜学びスプリント 開発正本

GitHub:
1. `sc-manabi-sprint/RELEASE_STATUS.md`
2. `sc-manabi-sprint/app-store/release-preflight.md`
3. `sc-manabi-sprint/app-store/metadata-ja.md`
4. `sc-manabi-sprint/app-store/review-notes-ja.md`
5. `sc-manabi-sprint/native/package.json`
6. `sc-manabi-sprint/native/capacitor.config.json`
7. `sc-manabi-sprint/native/configure-ios.sh`
8. `.github/workflows/sc-manabi-ios-preflight.yml`

## 1. 絶対にやり直さないもの

以下は既にPASS済み。対象物を変更しない限り、最初から作り直さない。

- IPA利用条件調査
- 競合調査
- 科目A-2短問周回の採用判断
- 公開過去問75問の構造化・公式解答照合
- 独自250問の生成・重複・高類似・水増し監査
- 325問統合監査
- Golden Master v2.1準拠Safari UI
- iPhone Safari初期試作品 HUMAN PASS
- 8問スプリントの実機修正
- 模試を13問+12問へ分割
- 325問Safari製品候補版 HUMAN PASS
- Privacy Policy / Support
- PrivacyInfo.xcprivacy
- Capacitor 8.4.2 iOS生成
- unsigned Simulator / device Release build
- Non-Consumable IAP購入・復元コード
- IAP追加後のGitHub Actions macOS preflight

## 2. 現在の製品仕様

### コンテンツ
- 公開過去問: 75問
- 独自問題: 250問
- 合計: 325問
- 非公開となった2026年度本試験問題を復元しない

### 学習UX
- 今日の標準: 8問
- 設定: 4 / 8 / 16問
- 苦手: 3連続正解で解除
- 模試: 各公表回を前半13 / 後半12
- 4タブ: ホーム / 模試 / 記録 / 設定
- 中断復帰、5週間ヒートマップ、試験日、JSON入出力

### 課金
ユーザー承認済み: 無料 + IAP
- 無料: IPA公開過去問75問を中心とする基本機能
- プレミアム: 独自250問を追加し全325問 + 分野別演習
- Type: Non-Consumable
- Product ID: `jp.allsunday1122.scmanabisprint.premium`
- 購入復元必須
- 価格のコード直書き禁止
- 600円は提案値であり、ユーザーの価格最終承認前に固定しない

## 3. iOS正本

- appId暫定: `jp.allsunday1122.scmanabisprint`
- Capacitor: 8.4.2
- Native Purchases: `@capgo/native-purchases`
- Version: 1.0.0
- Build: 1（CI / TestFlightではビルド番号を一意に進める）
- iPhone-only
- app内へ325問とWeb資産を同梱
- 本番でWeb URLを読み込むだけのラッパーにはしない
- `ITSAppUsesNonExemptEncryption = NO`

## 4. AppIcon

申請手順の学びスプリント専用ルールにより、新規生成禁止。

Google Drive正本:
- `08_情報処理安全確保支援士試験.png`
- ID: `1HuyIsiuQFmCbW266NbZIz5YM7tC08fON`
- 1024×1024 RGB
- SHA-256: `6bf2945788da0be45b9e448ea79d5c40ac197e97d6bed387d4215c50d486bb3d`

このPNGをAppIcon sourceへ置き、ビルド前にSHA-256を検査する。別の似たアイコンを生成しない。

## 5. 次担当の最初の作業

Apple認証がなくてもできる範囲:
1. `RELEASE_STATUS.md` とCI結果を確認する
2. Codemagic SC用workflowをroot `codemagic.yaml`へ統合する
3. 正本AppIconをiOS資産へ取り込む
4. signed build前のリリース監査スクリプトを実行する
5. Bundle ID、Product ID、Privacy、metadataの相互一致を再確認する

Apple側で人間入力が必要になったら止める。パスワード、2FA、API private key、証明書秘密鍵をGitHub / Notion / チャットへ保存しない。

## 6. Apple側でユーザー入力後に行うこと

1. App Store Connect Appレコードを作成
2. Non-Consumable IAPを作成
3. 価格をユーザー最終承認値で設定
4. Codemagic App Store Connect integration / signingを接続
5. signed IPAをInternal TestFlightへ送信
6. Sandboxで次をすべて実機確認
   - 未購入 → 購入 → 即時解放
   - 購入キャンセル → 未解放維持
   - 再インストール相当 → 購入復元
   - 購入済み → オフライン再起動 → 解放維持
7. TestFlightでGolden Master UI・Safe Area・外部リンク・オフラインを確認
8. TestFlight実画面からStore screenshotを取得
9. Age Rating / Content Rights / App Privacyを実装と一致させる
10. `Submit for Review` はユーザー最終承認前に押さない

## 7. 再発火ルール

- 問題を変更 → 問題生成・監査
- UIを変更 → UI品質
- コードを変更 → 実装検証
- 課金を変更 → 購入監査
- Privacy / SDK / 外部通信を変更 → Privacy / セキュリティ監査
- 制度・IPA条件を変更 → 制度 / 著作権監査
- TestFlight前 → リリース監査
- FAIL → 修正 → 同じ監査を再実行しPASSするまで次へ進まない

## 8. 停止条件

現在の次の人間ゲートは、標準手順上は「本実装担当AIの選択」またはAppleアカウント入力が必要になる地点。ChatGPT会話だけを正本にせず、このファイル・RELEASE_STATUS・Notion・CIを更新して進める。
