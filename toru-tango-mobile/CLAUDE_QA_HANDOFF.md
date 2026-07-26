# Claude QA引き継ぎ書: 撮る単語帳 iOS

更新日: 2026-07-26

## 役割

Claudeは、ChatGPTが実装したリリース候補について、主要操作、UI、文字、余白、Safe Area、エラー表示、空状態を確認する。

問題は次の優先度で分類する。

- P0: 起動不能、クラッシュ、データ損失、復元不能、主要情報の漏えい
- P1: カード作成、学習、保存、読み上げなど主要機能が正常に完了しない
- P2: 見た目、分かりやすさ、操作感、追加改善

P0・P1の中核ロジック修正はChatGPTへ戻す。UI修正はClaudeがPRブランチへ反映してよい。TestFlight・署名・申請作業は行わない。

## 対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- QAブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- アプリ: `toru-tango-mobile/`
- Web試用版: `https://allsunday1122.github.io/toru-tango/beta.html`
- 仕様: `toru-tango/IOS_MIGRATION_SPEC.md`
- リリース状況: `toru-tango-mobile/RELEASE_STATUS.md`
- チェックリスト: `toru-tango-mobile/RELEASE_CHECKLIST.md`
- nano評価基準: `toru-tango-mobile/AI_NANO_BENCHMARK.md`

QA開始時にPRの最新head SHAを取得し、`CLAUDE_QA_REPORT.md`へ記録する。mainではなくQAブランチを対象にする。

## 自動検査の証跡

- GitHub Actions workflow: `Toru Tango Mobile CI`
- nano変更後の成功Run ID: `30202307772`
- 確認済み:
  - TypeScript
  - ESLint
  - Expo Doctor
  - Expo public config
  - Cloudflare Worker構文
- 検査ログArtifact: `toru-tango-validation-logs`

QA中にコードを変更した場合、PRで同workflowが再度成功することを確認する。

## 起動手順

```bash
cd toru-tango-mobile
npm install --no-audit --no-fund
npm run check
npx expo start
```

iPhoneのExpo GoがSDK 57に対応しない場合はEASのpreview buildを使用する。起動画面はExpo Goではなくpreviewまたはproduction buildで確認する。

## 重点確認

### 1. 初回起動

- 起動時の白画面、無限読み込み、例外
- 最初に「作る」が表示されるか
- 4タブの移動
- iPhoneのノッチ、Dynamic Island、ホームインジケータとの重なり
- ホーム画面アイコンの見え方
- 起動画面から最初の画面への切り替わり

### 2. 作る

- 教材本文、形式、難易度、最大枚数の操作性
- 「AIで作問（nano）」と「端末内で簡易作問」が別操作になっているか
- AI失敗時に簡易作問へ勝手に切り替わらないか
- AI成功時にモデル、reasoning effort、トークン数、応答時間、除外件数が表示されるか
- 生成結果を「表｜裏」として編集できるか
- 生成結果と保存済みカードの重複除外
- 直接入力と一括入力が表・裏として理解できるか
- キーボード表示時にボタンへ到達できるか
- カメラ、写真権限を拒否した場合の表示

### 3. 単語帳

- 各保存カードが表と裏に分けて表示されるか
- 表を読む、裏を読むが正しい面を読み上げるか
- 長い表・裏の折り返し
- 0件、1件、大量カード時の表示
- 編集中のキャンセルと保存
- 削除、全削除の確認文

### 4. 学習

- カードのタップで表と裏を往復できるか
- 表と裏のラベル、反転案内、進捗の視認性
- 表を読む、裏を読むが表示面に関係なく正しい内容を読むか
- 読み上げ中の連続タップ
- 裏を表示するまで評価ボタンが出ないか
- 「もう一度」が末尾へ戻ること
- 対象カード0件と完了状態

### 5. AI作問品質

Workerが公開されている場合のみ実施する。公開前は未確認として報告する。

- 使用モデルが `gpt-5-nano` であること
- reasoning effortが `medium` であること
- 同じ事実を一問一答と穴埋めで重複生成しないこと
- 不完全な語句や英語表記だけを答えにしないこと
- 答えが問題文に残らないこと
- 問題数を満たすための低品質カードを追加しないこと
- `AI_NANO_BENCHMARK.md` の人類史教材で確認すること
- nano品質が不足する場合は、miniへ勝手に変更せずChatGPTへ差し戻すこと

### 6. 記録

- 小さい画面で統計4項目が崩れないか
- 日別履歴の読みやすさ
- バックアップ保存と復元
- 不正ファイル、キャンセル、共有不可時の表示

## 初期版の確定事項

- iPhone専用
- ライトモード固定
- ログインなし
- 課金なし
- 広告なし
- クラウド同期なし
- AI API未設定でも端末内簡易作問を別ボタンから利用可能
- AI失敗時の自動フォールバックなし
- AI初期試験モデルはGPT-5 nano
- 写真の撮影・選択は実装済み
- 写真OCRは未実装

## 特に判定が必要な論点

アプリ名は「撮る単語帳」だが、現状は写真の撮影・選択とプレビューまでで、写真からのOCRは未実装である。

Claudeは次を明示的に判定する。

1. 現在の案内だけでP1を回避できるか
2. 初回版のアプリ名・説明・画面表示と実機能に重大な不一致がないか
3. OCR実装が必須か、名称・説明の変更で初回版を成立させられるか

この論点は推測で完了扱いにせず、`CLAUDE_QA_REPORT.md`へ結論と理由を記録する。

## Claudeの成果物

1. `toru-tango-mobile/CLAUDE_QA_REPORT.md`
2. P0、P1、P2の一覧
3. 各問題の再現手順
4. 修正したファイルとコミット
5. 再テスト結果
6. 未確認項目。特にWorker未公開の場合のAI実通信
7. 「申請工程へ進行可能」または「ChatGPTへ差し戻し」の判定

## 完了条件

- P0未解決が0件
- P1未解決が0件
- P2が記録されている
- 主要操作を最初から最後まで再テスト済み
- 修正後のGitHub Actionsが成功
- AI実通信が未実施の場合は、その外部依存を明記
- ユーザーへリリース候補の承認を求められる状態
