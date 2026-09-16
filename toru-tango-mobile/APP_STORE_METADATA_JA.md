# 撮る単語帳｜App Store提出確定情報

更新日: 2026-09-16
対象: App Store Connect app 6795968222 / Bundle ID `com.allsunday1122.torutango` / Build 10

## 基本情報
- アプリ名: 撮る単語帳
- サブタイトル: 教材から一問一答をすぐ作成
- 主カテゴリ: 教育
- 副カテゴリ: 仕事効率化
- 価格: 無料
- 対応端末: iPhone
- 言語: 日本語
- 広告: なし
- App内課金: なし
- ログイン: なし

## 説明文要点
教材写真はApple Vision OCRで端末内認識できます。利用者が明示的にGemini OCRを選んだ場合のみ、同意後に選択画像をCloudflare Worker経由でGoogle Gemini APIへ送信します。クラウドAI作問を選択した場合のみ、教材本文と作問設定を同経路で送信します。カードと学習履歴は原則端末内保存です。

主な機能: 撮影/写真選択、端末内OCR、任意Gemini OCR、一問一答/穴埋め作成、編集保存、フォルダ管理、苦手復習、自動学習、学習記録、JSONバックアップ/復元。

## サポート情報
- サポートURL: `https://allsunday1122.github.io/toru-tango/`
- プライバシーポリシーURL: `https://allsunday1122.github.io/toru-tango/privacy-policy.html`

## App Review Notes
ログイン、アカウント作成、外部機器は不要。標準OCRはApple Visionで端末内処理。Gemini OCRは送信前に第三者AI送信を明示し、同意時のみ画像送信。クラウドAI作問時のみ教材本文・設定・匿名利用回数管理IDを送信。広告、解析SDK、トラッキング、IAPなし。

## App Privacy回答
Build 10では次を申告する。
- User Content / Photos or Videos: 収集あり / App Functionality / identityにリンクしない / trackingしない
- User Content / Other User Content: 収集あり / App Functionality / identityにリンクしない / trackingしない
- Identifiers / User ID: 収集あり / App Functionality / identityにリンクしない / trackingしない
- その他のデータ型: 該当なし

## Build 10 drift audit
2026-08-27のBuild 9 metadata確定後からBuild 10まで、`toru-tango-mobile/src/`、`app/`、`app.config.ts`、`package.json` に変更commitはない。変更はEAS CLI設定・QA文書等で、ユーザーデータ取扱い・機能・権限の差分は検出されなかった。したがってBuild 9のApp Privacy回答をBuild 10へ継承する。

## 提出時確定事項
- Build: 10
- Version: App Store Connect 1.0
- Primary Category: EDUCATION
- IDFA: 使用しない
- 輸出コンプライアンス: `ITSAppUsesNonExemptEncryption=false`
- Review demo account: 不要
- 本申請: Human Gate。App Store ConnectのApp Privacy最終一致確認後にのみ提出する。
