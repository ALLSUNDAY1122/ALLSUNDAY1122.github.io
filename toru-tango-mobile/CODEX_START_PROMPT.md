# Codex開始プロンプト｜撮る単語帳 API実装

> **2026-07-29 方針変更**：ユーザー指示によりOpenAI / GPT-5 nanoではなく、当面はGemini API無料枠の`gemini-3.5-flash-lite`を使用する。Secretは`GEMINI_API_KEY`、GitHub Actions Secretは`TORU_TANGO_GEMINI_API_KEY`とする。以降のOpenAI / nano記述は旧引継ぎ時点の参考情報であり、この方針変更を優先する。

以下をCodexへそのまま渡してください。

---

あなたは「撮る単語帳」iOSアプリのAPI実装・接続・開発ビルド担当です。

対象リポジトリ:
`ALLSUNDAY1122/ALLSUNDAY1122.github.io`

対象ブランチ:
`qa/toru-tango-mobile-20260726`

対象Pull Request:
`#3959`

対象ディレクトリ:

- `toru-tango-mobile/`
- `toru-tango/backend/`
- `.github/workflows/deploy-toru-tango-ai.yml`

最初に次を読んでください。

1. `toru-tango-mobile/CODEX_API_HANDOFF.md`
2. `toru-tango-mobile/RELEASE_STATUS.md`
3. `toru-tango-mobile/RELEASE_CHECKLIST.md`
4. `toru-tango-mobile/AI_NANO_BENCHMARK.md`
5. `toru-tango-mobile/AI_PROVIDER_RESEARCH.md`
6. `toru-tango-mobile/NATIVE_OCR_TEST_PLAN.md`
7. `toru-tango/IOS_MIGRATION_SPEC.md`
8. `toru-tango/backend/src/index.js`
9. `toru-tango/backend/wrangler.jsonc`
10. `toru-tango-mobile/src/services/ai.ts`

ユーザー判断により、作業順は次です。

1. CodexがAPI実装、Worker公開、アプリ接続、GPT-5 nano実通信、EAS development buildまで進める
2. その後にClaudeがUI・UX・OCR・作問品質と主要導線をQAする
3. ClaudeのP0・P1解消後、CodexがTestFlightとApp Store申請を担当する

現時点でClaudeを開始しないでください。

実施内容:

- PR #3959の最新head SHAを取得して作業報告へ記録
- Worker、モバイルAPIクライアント、デプロイworkflow、環境設定の整合性監査
- Secretをコードやログへ出さない構成の確認
- Workerとモバイルクライアントの正常系・異常系テスト追加
- Cloudflare Secretsが設定済みならworkflow_dispatchでWorkerを公開
- 未設定なら必要なSecret名と設定場所だけを報告し、値を要求しない
- `EXPO_PUBLIC_AI_API_URL`の安全な設定
- GPT-5 nano、reasoning effort mediumで3～5教材を実通信
- モデル、トークン、応答時間、品質指標、生成カードを記録
- AI失敗時に別モデルや端末内作問へ自動切替しないことを確認
- EAS development buildを実行可能な状態へ整備
- Apple Vision OCR ModuleのSwiftコンパイルを確認
- `toru-tango-mobile/CODEX_API_REPORT.md`を作成

既存の中心仕様を維持してください。

- iPhone専用
- ライトモード固定
- ログインなし
- 広告なし
- 課金なし
- クラウド同期なし
- OCRはApple Vision
- OCR結果は作問前に編集可能
- AI作問と端末内簡易作問は別操作
- 既定モデルはGPT-5 nano
- 自動モデル切替なし
- 表裏カード、タップ反転、両面読み上げ

禁止事項:

- mainへ直接コミットしない
- Secretをコード、Markdown、PRコメント、ログへ保存しない
- GPTモデルを独断で変更しない
- API未完了のままClaudeへ渡さない
- 大幅なUI刷新をしない
- TestFlight提出、EAS Submit、App Review提出まで先行しない
- Safari試作PR #4059をAPI実装先にしない

完了条件:

- Worker公開
- アプリからWorkerへ接続
- nanoの3～5教材実通信成功
- API異常系テスト成功
- GitHub Actions成功
- EAS development build成功
- Apple Vision Moduleコンパイル成功
- `CODEX_API_REPORT.md`完成
- Claudeへ渡す完了候補head SHA固定

外部認証またはSecret設定で停止する場合も、認証不要のコード、テスト、文書を先に完了し、必要な人間操作と再開手順を`CODEX_API_REPORT.md`へ記録してください。

---
