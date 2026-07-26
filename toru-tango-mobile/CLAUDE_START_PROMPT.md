# Claude開始プロンプト｜撮る単語帳 iOS QA

以下をClaudeへそのまま渡してください。

---

あなたは「撮る単語帳」iOSアプリの改善・QA担当です。

対象リポジトリ:
`ALLSUNDAY1122/ALLSUNDAY1122.github.io`

対象ブランチ:
`qa/toru-tango-mobile-20260726`

対象Pull Request:
`#3959`

対象ディレクトリ:
`toru-tango-mobile/`

最初に次のファイルを読んでください。

1. `toru-tango-mobile/CLAUDE_QA_HANDOFF.md`
2. `toru-tango-mobile/RELEASE_STATUS.md`
3. `toru-tango-mobile/RELEASE_CHECKLIST.md`
4. `toru-tango-mobile/NATIVE_OCR_TEST_PLAN.md`
5. `toru-tango-mobile/AI_NANO_BENCHMARK.md`
6. `toru-tango-mobile/AI_PROVIDER_RESEARCH.md`
7. `toru-tango/IOS_MIGRATION_SPEC.md`
8. `toru-tango-mobile/PRIVACY_DATA.md`
9. `toru-tango-mobile/APP_STORE_METADATA_JA.md`

QA開始時にPRの最新head SHAを取得し、報告書へ記録してください。mainではなく指定ブランチを対象にしてください。

開始前提:

- PRがReady for reviewである
- EAS development buildが成功している
- Apple Vision OCRモジュールがコンパイル済みである
- iPhoneへ開発ビルドをインストール済みである
- Cloudflare Workerが公開済みである
- GPT-5 nanoの基本実通信が完了している

いずれかが未完了ならQAを開始せず、外部設定待ちまたはChatGPT工程へ差し戻してください。

実施内容:

- `npm run check`を実行する
- GitHub Actions `Toru Tango Mobile CI`の最新Runが成功していることを確認する
- EAS development buildで主要4画面を確認する
- 写真撮影・写真選択・権限拒否を確認する
- 自動向き判定、左90度、右90度を確認する
- Apple Vision OCRで日本語表と通常文章を確認する
- OCR結果を編集し、教材本文へ転送できることを確認する
- 端末内簡易作問とAI作問を別々に確認する
- AI失敗時に簡易作問へ自動切替しないことを確認する
- 使用モデルが`gpt-5-nano`、reasoning effortが`medium`であることを確認する
- モデル、トークン数、応答時間、除外件数が表示されることを確認する
- 歴史文章と保険表OCRで、意味重複、不完全な答え、事実誤りを確認する
- 表裏カード、タップ反転、両面読み上げを確認する
- カード追加・編集・削除、学習、履歴、バックアップ復元を確認する
- UI、文字、余白、Safe Area、キーボード、エラー、空状態を確認する
- 固定20教材を`AI_NANO_BENCHMARK.md`に従って評価する
- nano品質が不足する場合、miniへ勝手に変更せずChatGPTへ差し戻す

問題分類:

- P0: 起動不能、クラッシュ、データ損失、復元不能、主要情報漏えい
- P1: 撮影、OCR、作問、保存、学習、読み上げ等の主要機能が完了しない
- P2: UI、分かりやすさ、操作感、将来改善

UI修正はQAブランチへ反映して構いません。中核ロジック、OCR、nano作問品質にP0・P1がある場合は、勝手に仕様やモデルを変更せずChatGPTへ差し戻してください。TestFlight提出、署名、EAS Submit、App Store申請は行わないでください。

成果物として`toru-tango-mobile/CLAUDE_QA_REPORT.md`を作成し、次を記録してください。

- 対象head SHA
- EAS Build ID
- iPhone機種とiOSバージョン
- 実行した検査と結果
- OCRの自動採用角度と認識結果
- P0、P1、P2一覧
- 再現手順
- 修正ファイルとコミット
- 再テスト結果
- nano実通信結果と使用モデル
- 未確認項目
- 「申請工程へ進行可能」または「ChatGPTへ差し戻し」の最終判定

完了条件は、P0とP1の未解決が0件で、撮影から読み上げまでの導線、固定20教材のnano評価、修正後のGitHub Actionsがすべて完了していることです。

---
