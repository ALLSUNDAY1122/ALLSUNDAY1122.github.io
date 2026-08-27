# 撮る単語帳 App Storeプライバシー回答案

更新日: 2026-08-27
対象: App Store Connect Build 9 / binary source `a1385d1f997c25dff56b635906ed852d0b54567c`

この文書は、Build 9の実装と公開プライバシーポリシーに合わせたApp Store Connect「Appのプライバシー」回答の正本である。App Store Connect上の最終回答はこの内容と一致させてから本審査へ提出する。

## 基本方針

- アカウント登録なし
- 広告なし
- トラッキングなし
- アクセス解析SDKなし
- カードと学習履歴は原則端末内保存
- Apple Vision OCRは端末内処理で、画像を外部送信しない
- Gemini OCRは利用者が明示的に選択し、送信前の同意ダイアログで許可した場合だけ、選択画像をCloudflare Worker経由でGoogle Gemini APIへ送信する
- 端末内AI／簡易作問では教材本文を外部送信しない
- クラウドAI作問を利用した場合だけ、教材本文等をCloudflare Worker経由でGoogle Gemini APIへ送信する
- クラウドAI/OCRの利用回数管理のため、端末内生成の匿名IDを送信し、Worker側で利用回数情報を最大45日保持する

## App Store Connect 回答案（保守的開示）

### 1. User Content / Photos or Videos

対象:
- 利用者がGemini OCRを明示的に選択した場合の教材画像

用途:
- App Functionality（OCR文字認識）

取扱い:
- 送信前に「Geminiへ写真を送信します」と明示し、Cloudflare Worker経由でGoogle Gemini APIへ送信することを説明する
- 利用者が「同意して認識」を選択した場合のみ送信
- Apple Vision OCRを選択した場合は外部送信しない
- 氏名・アカウントとはリンクしない設計
- トラッキングには使用しない
- 広告やマーケティングには使用しない

App Store Connect:
- Data Collected: Yes
- Data Type: User Content / Photos or Videos
- Purpose: App Functionality
- Linked to User: No
- Tracking: No

### 2. User Content / Other User Content

対象:
- クラウドAI作問へ送る教材本文
- 作問形式
- 難易度
- 問題数

用途:
- App Functionality（問題生成）

取扱い:
- 利用者がクラウドAI作問を実行した場合のみ送信
- Cloudflare Worker経由でGoogle Gemini APIで処理
- 氏名・アカウントとはリンクしない設計
- トラッキングには使用しない
- 広告やマーケティングには使用しない

App Store Connect:
- Data Collected: Yes
- Data Type: User Content / Other User Content
- Purpose: App Functionality
- Linked to User: No
- Tracking: No

### 3. Identifiers / User ID

対象:
- 端末内で生成するアプリ専用の匿名利用回数管理ID

用途:
- クラウドAI/OCRの無料利用回数制御
- 不正・過剰利用の抑制

取扱い:
- AI/OCRリクエスト時に `X-Toru-Tango-Anonymous-Id` として送信
- 氏名、メールアドレス、Apple Account等とは結び付けない
- Workerの利用回数管理データは最大45日保持
- トラッキングには使用しない
- 広告やマーケティングには使用しない

App Store Connect:
- Data Collected: Yes
- Data Type: Identifiers / User ID
- Purpose: App Functionality
- Linked to User: No
- Tracking: No

## 収集しないデータ

現行Build 9では、運営者が次の情報を広告・解析目的で収集するSDKやサーバー処理はない。

- 連絡先情報
- 健康・フィットネス情報
- 金融情報
- 正確な位置情報／おおよその位置情報
- 連絡先一覧
- 閲覧履歴
- 検索履歴
- 購入履歴
- 広告データ
- サードパーティ広告用データ

## 端末権限

### カメラ

教材写真の撮影に使用する。Apple Vision OCRでは端末内処理。Gemini OCRを利用者が明示的に選択し同意した場合のみ、選択画像を外部AIへ送信する。

### 写真ライブラリ

利用者が選んだ教材写真の表示・OCRに使用する。選択していない写真へアクセスしない。Gemini OCR時のみ、選択画像を同意後に外部送信する。

## バックアップ

バックアップは利用者の操作によりJSONファイルを作り、iOS共有シートへ渡す。共有先は利用者が選ぶ。運営者のサーバーへ自動送信しない。

## 外部事業者

- Cloudflare: AI/OCR API中継、匿名利用回数管理
- Google Gemini API: 任意のクラウドAI作問、任意のGemini OCR
- Apple: App Store、TestFlight、Apple Vision OCR、端末内AI等の標準機能

## Build 9 実装read-back

- `src/services/geminiOcr.ts`: 選択画像をbase64化し `/ocr` へ送信。匿名IDをヘッダ送信
- `app/(tabs)/create.tsx`: Gemini OCR実行前に第三者AI送信を明示し、「キャンセル」または「同意して認識」を選択させる
- 公開プライバシーポリシー: 2026-08-21更新版でApple Vision OCR、Gemini OCR、クラウドAI作問、匿名利用IDを開示

## 本申請ゲート

- [x] Build 9にGemini OCR送信前の明示同意UIがある
- [x] 公開プライバシーポリシーがBuild 9実装と整合している
- [x] GitHubのApp Privacy回答案をBuild 9へ更新した
- [ ] App Store ConnectのApp Privacy回答を上記3データタイプと照合し、必要なら更新・公開する
- [ ] App Store Connectの最終read-back後にSubmit for Reviewする
