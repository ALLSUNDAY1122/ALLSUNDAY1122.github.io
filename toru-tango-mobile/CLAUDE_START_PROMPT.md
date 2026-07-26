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

最初に次のファイルを読み、現在地と役割分担を確認してください。

1. `toru-tango-mobile/CLAUDE_QA_HANDOFF.md`
2. `toru-tango-mobile/RELEASE_STATUS.md`
3. `toru-tango-mobile/RELEASE_CHECKLIST.md`
4. `toru-tango/IOS_MIGRATION_SPEC.md`
5. `toru-tango-mobile/PRIVACY_DATA.md`
6. `toru-tango-mobile/APP_STORE_METADATA_JA.md`

QA開始時にPRの最新head SHAを取得し、報告書へ記録してください。mainではなく指定ブランチを対象にしてください。

実施内容:

- 依存関係を導入し、`npm run check`を実行する
- GitHub Actions `Toru Tango Mobile CI` が成功していることを確認する
- 主要4画面を最初から最後まで確認する
- UI、文字、余白、Safe Area、キーボード、エラー、空状態を確認する
- カード追加・編集・削除、学習、履歴、バックアップ復元を確認する
- AI未設定時の端末内作問フォールバックを確認する
- カメラ・写真権限を拒否してもクラッシュしないことを確認する
- アプリアイコンとpreview build上の起動画面を確認する
- 「撮る単語帳」という名称に対してOCR未実装がP1に該当するか明示的に判定する

問題分類:

- P0: 起動不能、クラッシュ、データ損失、復元不能、主要情報漏えい
- P1: 主要機能が正常に完了しない、名称・説明と機能の重大な不一致
- P2: UI、分かりやすさ、操作感、将来改善

UI修正はこのQAブランチへ反映して構いません。中核ロジックにP0・P1がある場合は、勝手に仕様変更せずChatGPTへ差し戻してください。TestFlight、署名、EAS Submit、App Store申請は行わないでください。

成果物として `toru-tango-mobile/CLAUDE_QA_REPORT.md` を作成し、次を記録してください。

- 対象head SHA
- 実行環境
- 実行した検査と結果
- P0、P1、P2一覧
- 再現手順
- 修正ファイルとコミット
- 再テスト結果
- 未確認項目
- 「申請工程へ進行可能」または「ChatGPTへ差し戻し」の最終判定

完了条件は、P0とP1の未解決が0件で、修正後のGitHub Actionsが成功していることです。

---
