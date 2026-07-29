# Claude QA引継ぎ書｜撮る単語帳 iOS

> **2026-07-29 方針変更**：AI作問はGemini API無料枠の`gemini-3.5-flash-lite`へ変更された。`AI_GEMINI_BENCHMARK.md`を正本とし、以降のGPT-5 nano表記は旧仕様として読み替える。

更新日: 2026-07-29

> **待機中**：Claudeはまだ開始しない。Codexが`CODEX_API_HANDOFF.md`に従い、Worker公開、アプリ接続、GPT-5 nano実通信、EAS development buildを完了し、`CODEX_API_REPORT.md`へ「Claudeへ引渡可能」と記録した後に開始する。

## 1. 開発順と役割

1. Codex: API実装、Worker公開、モバイル接続、実通信、自動テスト、EAS development build
2. Claude: API実装後のUI・UX、OCR、作問品質、主要導線のQA
3. Codex: ClaudeのP0・P1解消後、TestFlight・App Store申請

Claudeの担当:

- 主要操作の実機確認
- UI、文字、余白、Safe Area、キーボード
- 空状態、権限拒否、エラー表示
- OCRと作問品質
- P0、P1、P2の分類
- UI範囲の修正と再テスト

ClaudeはAPI設計、Secret設定、Workerデプロイ、EAS Submit、TestFlight提出、App Review提出を担当しない。

## 2. 対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- QAブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- アプリ: `toru-tango-mobile/`
- API: `toru-tango/backend/`
- Codex実装指示: `toru-tango-mobile/CODEX_API_HANDOFF.md`
- Codex結果: `toru-tango-mobile/CODEX_API_REPORT.md`
- リリース状況: `toru-tango-mobile/RELEASE_STATUS.md`
- チェックリスト: `toru-tango-mobile/RELEASE_CHECKLIST.md`
- OCR実機計画: `toru-tango-mobile/NATIVE_OCR_TEST_PLAN.md`
- nano評価基準: `toru-tango-mobile/AI_NANO_BENCHMARK.md`

QA開始時にPRの最新head SHAを取得し、`CLAUDE_QA_REPORT.md`へ記録する。mainではなく指定ブランチを対象にする。

## 3. QA開始の前提

次がすべて完了していることを確認する。

1. `CODEX_API_REPORT.md`が存在する
2. Codexの最終判定が「Claudeへ引渡可能」である
3. Cloudflare Workerが公開済み
4. アプリが公開Workerへ接続済み
5. GPT-5 nanoで3～5教材の基本実通信済み
6. API正常系・異常系テスト成功
7. GitHub Actions成功
8. EAS development build成功
9. Apple Vision OCR ModuleがSwiftコンパイル済み
10. PR `#3959`がReady for review

未完了の場合はQAを開始せず、`CLAUDE_QA_REPORT.md`またはPRコメントへ不足項目を記録し、Codex工程へ差し戻す。

## 4. 問題分類

- P0: 起動不能、クラッシュ、データ損失、復元不能、Secret・教材本文等の主要情報漏えい
- P1: 撮影、OCR、AI作問、カード保存、学習、読み上げ等の主要機能が完了しない
- P2: 見た目、分かりやすさ、操作感、将来改善

UI修正はClaudeがQAブランチへ反映してよい。API、中核ロジック、OCR、nano作問品質のP0・P1は、仕様やモデルを勝手に変更せずCodexまたはChatGPTへ差し戻す。

## 5. 起動

Apple Vision OCRはExpo Goでは動作しない。Codexが作成したEAS development buildを使用する。

```bash
cd toru-tango-mobile
npm install --no-audit --no-fund
npm run check
npx expo start --dev-client
```

## 6. 重点確認

### 初回起動・画面

- 白画面、無限読み込み、例外がない
- 主要4画面を移動できる
- ノッチ、Dynamic Island、ホームインジケータと重ならない
- キーボードで重要ボタンが隠れない
- 空状態とエラーが理解できる

### 写真・Apple Vision OCR

- カメラと写真ライブラリ
- 権限許可・拒否
- 写真プレビュー
- 0度・90度・180度・270度の自動比較
- 左90度・右90度の手動指定
- 通常文章、横向き表、薄い文字で日本語認識
- OCR結果の編集と教材本文への転送
- 文字のない画像や認識不足時のエラー

### API・AI作問

- Codex報告のWorker URLへ接続している
- `gpt-5-nano`、reasoning effort `medium`
- AI作問と端末内簡易作問が別操作
- AI失敗時に端末内作問や別モデルへ自動切替しない
- 未設定URL、通信不能、タイムアウト、HTTPエラー、不正JSON、空出力を確認
- APIエラー後もOCR本文が失われない
- モデル、トークン数、応答時間、除外件数を表示
- 同じ事実の一問一答と穴埋めが重複しない
- 不完全な答え、英語表記だけ、事実誤りを除外する
- 指定件数を満たすために低品質カードを追加しない

### 固定20教材

`AI_NANO_BENCHMARK.md`に従い評価する。nano品質不足時はminiへ変更せず、同一教材の結果と不足理由を記録して差し戻す。

### 単語帳・学習

- 表裏カードの表示
- タップ反転
- 表と裏の個別読み上げ
- 裏表示前に評価ボタンが出ない
- 「もう一度」と「覚えた」
- 0件、1件、大量カード
- 追加、編集、削除、全削除
- 学習履歴、統計、苦手カード
- 再起動後の保存
- JSONバックアップと復元

## 7. 初期版の確定事項

- iPhone専用
- ライトモード固定
- ログインなし
- 課金なし
- 広告なし
- クラウド同期なし
- AI初期モデルはGPT-5 nano
- AI失敗時の自動フォールバックなし
- OCRはApple Vision
- OCR結果は作問前に編集可能

## 8. 成果物

`toru-tango-mobile/CLAUDE_QA_REPORT.md`へ次を記録する。

- 対象head SHA
- Codex完了候補head SHA
- Worker URL、デプロイRun ID
- EAS Build ID
- iPhone機種、iOSバージョン
- 実行した検査と結果
- OCRの採用角度と認識結果
- API正常系・異常系結果
- 固定20教材の評価
- P0、P1、P2
- 再現手順
- 修正ファイルとコミット
- 再テスト結果
- 未確認項目
- 「申請工程へ進行可能」または「Codexへ差し戻し」の判定

## 9. 完了条件

- P0未解決が0件
- P1未解決が0件
- P2が記録されている
- 撮影から読み上げまでの主要導線を実機再テスト済み
- API異常系を確認済み
- 固定20教材のnano評価を完了
- 修正後のGitHub Actionsが成功
- CodexへTestFlight・App Store申請工程を戻せる状態
