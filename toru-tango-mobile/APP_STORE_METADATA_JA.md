# 撮る単語帳｜App Store提出確定情報

更新日: 2026-08-27
対象: App Store Connect app 6795968222 / Bundle ID `com.allsunday1122.torutango` / Build 9

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

## プロモーションテキスト

教材を撮る・選ぶ・貼り付ける。AIやiPhone内処理で自分専用の一問一答を作り、カード一覧・自動学習・苦手復習・学習記録まで一つで管理できます。

## 説明文

「撮る単語帳」は、教材から自分専用の一問一答を作り、すぐに復習できる学習アプリです。

教材写真はApple Vision OCRで端末内認識できます。利用者が明示的にGemini OCRを選んだ場合は、確認画面で同意した後に、選択した教材画像をCloudflare Worker経由でGoogle Gemini APIへ送信して文字認識します。

教材本文からの問題作成は、iPhone内の処理またはクラウドAI作問を選べます。クラウドAI作問を選んだ場合のみ、入力した教材本文と作問設定をCloudflare Worker経由でGoogle Gemini APIへ送信します。

主な機能

・教材写真の撮影／写真ライブラリから選択
・Apple Vision OCRによる端末内文字認識
・任意のGemini OCRによる文字認識
・教材本文から一問一答／穴埋め問題を作成
・問題数と難易度を選択
・生成結果を編集してから保存
・問題と答えの直接入力
・複数カードのまとめて登録
・フォルダ単位でカードを一覧・編集
・全カード、苦手優先、未学習のみの学習
・問題と答えの読み上げと自動学習
・「覚えた」「もう一度」による復習
・正答率、連続学習日数、苦手カード数の記録
・JSON形式のバックアップと復元

アカウント登録、広告、App内課金、アクセス解析SDK、トラッキングはありません。カードと学習履歴は原則として端末内に保存されます。

クラウドAIへ送る教材画像・教材本文には、個人情報、秘密情報、学校・勤務先等の非公開情報を含めないでください。クラウドAIを使わず、端末内処理だけで利用することもできます。

## キーワード

単語帳,一問一答,暗記,勉強,学習,資格,問題作成,復習,教科書,穴埋め

## サポート情報

- サポートURL: `https://allsunday1122.github.io/toru-tango/`
- プライバシーポリシーURL: `https://allsunday1122.github.io/toru-tango/privacy-policy.html`
- 問い合わせ: `kmorita3615@gmail.com`

## App Review Notes

本アプリはログイン、アカウント作成、外部機器を必要としません。

標準OCRはApple Visionを利用し端末内で処理します。利用者が「Gemini OCR」を明示的に選択した場合のみ、送信直前の確認画面で「Cloudflare Worker経由でGoogle Gemini APIへ選択画像を送信する」ことを明示し、「同意して認識」を選んだ場合だけ画像を送信します。

「iPhone内で問題を作る」はApple Foundation Modelsまたは端末内簡易作問で処理します。クラウドAI作問を選択した場合のみ、教材本文、作問形式、難易度、問題数、利用回数管理用の匿名IDをCloudflare Worker経由でGoogle Gemini APIへ送信します。匿名IDは氏名・メールアドレス等とは結び付けず、広告・解析・トラッキングには使用しません。

広告、アクセス解析SDK、トラッキング、ログイン、App内課金はありません。カードと学習履歴は原則端末内保存です。

確認手順:
1. 「作る」タブで教材写真を撮影または選択し、Apple Vision OCRまたはGemini OCRを確認
2. Gemini OCRでは送信前の同意確認画面を確認
3. 教材本文を入力し、iPhone内作問またはクラウドAI作問を選択
4. 生成結果を編集してカードへ追加
5. 「フォルダ」でカード一覧・表裏・表示/非表示・編集を確認
6. 「学習」で表読み上げ→設定秒数→裏読み上げ→設定秒数→次カードの自動学習を確認
7. 「記録」で学習履歴と連続学習を確認

## App Privacy回答

Build 9の実装に合わせ、App Store Connectでは次を申告する。

- User Content / Photos or Videos: 収集あり / App Functionality / identityにリンクしない / trackingしない
  - Gemini OCRを利用者が明示選択した場合の教材画像
- User Content / Other User Content: 収集あり / App Functionality / identityにリンクしない / trackingしない
  - クラウドAI作問へ送信する教材本文・作問設定
- Identifiers / User ID: 収集あり / App Functionality / identityにリンクしない / trackingしない
  - 端末内でランダム生成する利用回数管理用匿名ID
- その他のデータ型: 現行Build 9で該当なし

## 提出時確定事項

- Build: 9
- Version: App Store Connect 1.0
- Primary Category: EDUCATION
- IDFA: 使用しない
- 輸出コンプライアンス: `ITSAppUsesNonExemptEncryption=false`
- Review demo account: 不要
- 本申請: ユーザー承認済み（2026-08-27）
