# 撮る単語帳 リリースチェックリスト

更新日: 2026-07-29

## 1. ChatGPTコード実装

- [x] 画面構成とデータモデルを固定
- [x] カード追加・編集・削除
- [x] 表・裏としてカードを表示
- [x] 学習カードをタップして表裏反転
- [x] 表と裏の個別読み上げ
- [x] 学習履歴、統計、バックアップ・復元
- [x] AI作問と端末内簡易作問を別操作にする
- [x] AI失敗時に別モデル・簡易作問へ自動切替しない
- [x] カメラ撮影と写真選択
- [x] Apple Vision OCRローカルネイティブモジュール
- [x] OCRの自動向き比較と手動90度指定
- [x] OCR結果を編集して教材本文へ送る
- [x] OCR文字間空白、罫線、明確な誤認の修復
- [x] 表形式教材向けの事実抽出
- [x] Gemini 3.5 Flash-Liteを当面の無料枠モデルとして設定
- [x] AIレスポンスへモデル・トークン数・応答時間・除外件数を追加
- [x] EAS development／preview／production設定
- [x] `expo-dev-client`を追加
- [x] アプリアイコンと起動画面
- [x] Web作問回帰テスト
- [x] モバイルOCR対応作問回帰テスト
- [x] GitHub Actions検査

最新自動検査証跡:

- PR: `#3959`
- Run ID: `30220648043`
- 結果: success
- 検査: TypeScript / ESLint / Expo Doctor / Expo config / Web作問 / モバイル作問 / OCRモジュール構成 / Worker構文

## 2. Claude引き渡し前の必須確認

### ネイティブビルド

- [ ] Expoへログインまたは`EXPO_TOKEN`を設定
- [ ] `eas build --platform ios --profile development`を実行
- [ ] Apple Vision OCRモジュールのSwiftコンパイル成功
- [ ] iPhoneへ開発ビルドをインストール
- [ ] 初回起動でクラッシュしない
- [ ] 4タブを移動できる
- [ ] Safe Areaに文字やボタンが重ならない

### 写真・OCR

- [ ] カメラ権限を許可して撮影できる
- [ ] カメラ権限を拒否してもクラッシュしない
- [ ] 写真ライブラリから選択できる
- [ ] 写真権限を拒否してもクラッシュしない
- [ ] 写真プレビューが表示される
- [ ] 自動向き判定で横向き教材を正立させられる
- [ ] 左90度・右90度の手動指定が動く
- [ ] Apple Visionで日本語を認識できる
- [ ] 認識結果を編集できる
- [ ] OCR結果を教材本文へ移せる
- [ ] 今回の横向き保険表で主要項目を認識できる
- [ ] 「撮影→OCR→作問→保存」の導線が完了する

### 作問・単語帳

- [ ] 通常の歴史文章から意味のあるカードを作れる
- [ ] 保険表OCRから支払事由、金額、年齢等を作れる
- [ ] 同じ事実を一問一答と穴埋めで重複生成しない
- [ ] 情報不足文でカードを捏造しない
- [ ] 生成結果を編集できる
- [ ] 保存済みとの重複を除外できる
- [ ] 保存後に表裏が明確に表示される
- [ ] タップで表裏を往復できる
- [ ] 表と裏を個別に読み上げる
- [ ] 再起動後もカードと履歴が残る

### Gemini実通信

- [x] Cloudflare Workerを公開
- [x] `GEMINI_API_KEY`をWorker Secretへ登録
- [x] アプリへ`EXPO_PUBLIC_AI_API_URL`を設定
- [x] 使用モデルが`gemini-3.5-flash-lite`と表示される
- [x] JSON Schema形式でカードが返る
- [x] トークン数、応答時間、除外件数が表示される
- [x] AI失敗時に簡易作問へ自動切替しない
- [ ] 3～5教材で重大な事実誤りがない

## 3. Claude QA入口

- [x] QA用PR `#3959` を作成
- [x] `CLAUDE_QA_HANDOFF.md` を作成
- [x] `CLAUDE_START_PROMPT.md` を作成
- [x] `AI_NANO_BENCHMARK.md` を作成
- [x] QAブランチを最新mainへ同期
- [ ] ネイティブビルドと実機OCR確認を完了
- [ ] Gemini基本実通信を完了
- [x] 最新headで自動検査成功
- [ ] PRをReady for reviewへ変更
- [ ] ClaudeがQA対象head SHAを報告書へ記録

## 4. Claude QA完了条件

- [ ] P0未解決 0件
- [ ] P1未解決 0件
- [ ] P2を一覧化
- [ ] UI修正後の再テスト完了
- [ ] 固定20教材でGemini品質を評価
- [ ] Gemini継続採用または別モデル比較を決定
- [ ] Claudeが申請工程へ進行可能と判定
- [ ] ユーザーがリリース候補を承認

## 5. Codex申請工程

- [x] 対象コミットを固定（`3385359f64a4f79df02c884d2ef118eef50fe84a`）
- [x] EAS projectIdを設定
- [ ] Apple Developer資格情報を確認（Apple IDログイン・2段階認証待ち）
- [x] App Store Connectにアプリを作成（App ID `6795968222`）
- [ ] `eas build --platform ios --profile production`
- [ ] Build ID、Version、Build、成功日時を記録
- [ ] `eas submit --platform ios --profile production --latest`
- [ ] TestFlight処理完了
- [ ] 内部テスターへ割り当て
- [ ] iPhone実機テスト合格
- [ ] スクリーンショットと掲載情報を完成
- [ ] データ収集、暗号化、年齢区分を回答
- [ ] ユーザー承認後にApp Reviewへ提出
