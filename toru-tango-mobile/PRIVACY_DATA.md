# 撮る単語帳 App Storeプライバシー回答案

更新日: 2026-08-21

この文書はBuild 9時点のApp Store Connect「Appのプライバシー」回答案である。公開時のアプリ、Cloudflare Worker、Google Gemini APIおよび公開プライバシーポリシーと一致させる。

## 基本方針

- アカウント登録なし
- 広告なし
- トラッキングなし
- アクセス解析SDKなし
- カードと学習履歴は原則として端末内保存
- Apple Vision OCRは端末内処理で、教材画像を外部送信しない
- 「iPhone内で問題を作る」はApple Foundation Modelsまたは端末内簡易作問を利用し、教材本文を外部送信しない
- 利用者が明示的にGemini OCRを選んだ場合のみ、選択した教材画像をCloudflare Worker経由でGoogle Gemini APIへ送信する
- 利用者が明示的にクラウドAI作問を選んだ場合のみ、教材本文等をCloudflare Worker経由でGoogle Gemini APIへ送信する
- クラウドAI利用回数管理のため、アプリ内で生成した匿名IDをCloudflare Workerへ送信し、月次利用回数をKVで保持する

## App Store Connect回答案

### 1. User Content / Photos or Videos

対象:
- 利用者がGemini OCRを明示的に選択した場合の教材画像

用途:
- App Functionality

回答:
- 収集: あり
- ユーザーのアイデンティティにリンク: いいえ
- トラッキング: いいえ

### 2. User Content / Other User Content

対象:
- クラウドAI作問へ入力した教材本文
- 作問形式、難易度、問題数

用途:
- App Functionality

回答:
- 収集: あり
- ユーザーのアイデンティティにリンク: いいえ
- トラッキング: いいえ

### 3. Identifiers / User ID

対象:
- アプリ内でランダム生成しAsyncStorageへ保存する匿名ID
- Cloudflare Workerで月間AI利用回数を管理するために使用
- Worker側の利用回数キーは約45日で期限切れになる

用途:
- App Functionality

回答:
- 収集: あり
- ユーザーのアイデンティティにリンク: いいえ
- トラッキング: いいえ

## 収集しないデータ

現行Build 9では、次の情報を広告・分析・運営者サーバー収集のために取得するSDKや処理はない。

- 連絡先情報
- 健康・フィットネス情報
- 金融情報
- 位置情報
- 連絡先一覧
- 閲覧履歴
- 検索履歴
- 購入履歴
- 使用状況データ（上記の匿名AI利用回数を除く）
- 診断データ
- 広告データ

## 端末権限

### カメラ

教材写真の撮影に使用する。Apple Vision OCRを選択している場合は端末内で認識する。Gemini OCRを利用者が明示的に選択した場合のみ、選択画像を外部AI処理へ送信する。

### 写真ライブラリ

利用者が選んだ教材写真にのみアクセスする。選択していない写真へアクセスしない。

## バックアップ

バックアップは利用者の操作によりJSONファイルを作り、iOS共有シートへ渡す。共有先は利用者が選ぶ。運営者のサーバーへ自動送信しない。

## 外部事業者

- Cloudflare: AI API中継、匿名IDによる月間利用回数管理
- Google: 利用者が明示的に選んだ場合のGemini APIによる教材本文の作問または教材画像OCR
- Apple: App Store、TestFlight、Apple Vision OCR、Foundation Models、iOS標準機能

## 提出前確認

- [x] Build 9のWorkerは教材本文・画像そのものをアプリ独自ログへ保存する処理を持たない
- [x] 公開プライバシーポリシーへGemini作問・Gemini OCR・匿名利用IDを明記
- [x] Apple Vision OCR / Foundation Modelsの端末内経路を明記
- [x] アクセス解析SDK・広告SDKなし
- [x] Gemini OCRの画像外部送信を回答案へ反映
- [x] 匿名IDとKV利用回数管理をIdentifiers回答案へ反映
- [ ] App Store ConnectのApp Privacy画面で Photos or Videos / Other User Content / User ID を設定し公開
- [ ] App Store Connectの表示プレビューと公開プライバシーポリシーを最終照合
