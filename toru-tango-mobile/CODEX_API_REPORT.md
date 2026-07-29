# Codex API実装報告｜撮る単語帳 iOS

更新日: 2026-07-29

## 状態

- 判定: Gemini実装と認証不要検査を完了、外部設定待ち
- 開始head SHA: `c577bbd3468a743daf35d157283ed27a491f5cc3`
- Gemini実装commit SHA: `8d81497c07e623e5ab994b91c48df803187e187c`
- 完了候補head SHA: 未固定（外部設定待ち）
- Claudeへ引渡可能: いいえ

ユーザー指示により、未実装だったAI APIはOpenAI / GPT-5 nanoではなく、当面Gemini API無料枠の`gemini-2.5-flash-lite`を使用する方針へ変更した。

## 実装内容

- Cloudflare Workerの上流をGemini `generateContent` APIへ変更
- `GEMINI_API_KEY`を`x-goog-api-key`ヘッダーでのみ上流へ送信
- 既定モデルを`gemini-2.5-flash-lite`へ変更
- JSON Schema構造化出力、入力制限、タイムアウト、重複・低品質除外を維持
- Geminiの`usageMetadata`を既存のトークン表示形式へ正規化
- 上流エラー、安全ブロック、不正JSON、空出力を明示処理
- APIキーや教材本文をログへ出さない
- モバイル画面のOpenAI / nano表記をGeminiへ変更
- AI失敗時に別モデル・端末内簡易作問へ自動切替しない
- GitHub ActionsのSecret名とWorker登録手順をGeminiへ変更
- Worker正常系・異常系テスト5件をCIへ追加
- 無料枠の上限とデータ取扱い注意をUI・プライバシー文書へ反映

## 主要変更ファイル

- `toru-tango/backend/src/index.js`
- `toru-tango/backend/tests/worker.test.js`
- `toru-tango/backend/wrangler.jsonc`
- `toru-tango/backend/README.md`
- `.github/workflows/deploy-toru-tango-ai.yml`
- `.github/workflows/toru-tango-mobile-ci.yml`
- `toru-tango-mobile/src/services/ai.ts`
- `toru-tango-mobile/app/(tabs)/create.tsx`
- `toru-tango-mobile/AI_GEMINI_BENCHMARK.md`
- `toru-tango-mobile/PRIVACY_DATA.md`
- `toru-tango-mobile/RELEASE_STATUS.md`
- `toru-tango-mobile/RELEASE_CHECKLIST.md`

## 自動テスト

| 検査 | 結果 | 証跡 |
|---|---|---|
| TypeScript | 成功 | `pnpm --dir toru-tango-mobile run typecheck` |
| ESLint | 成功 | GitHub Actions |
| Expo Doctor | 成功 | GitHub Actions。ローカルは`npm`不在のため一部検査不能だった |
| Expo public config | 成功 | Bundle ID、Version、Build、権限文言を確認 |
| Worker構文 | 成功 | `node --check toru-tango/backend/src/index.js` |
| Worker正常系・異常系 | 成功 | Node test 5/5 |
| モバイルOCR対応作問 | 成功 | Node test 3/3 |
| モバイルAPIクライアント | TypeScript成功 | Geminiレスポンス契約へ変更 |
| GitHub Actions | 成功 | Mobile `30451982036` / `30451983871`、Generator `30451983446` |
| Expo iOS prebuild | 成功 | Mobile CI `30451982036` / `30451983871` |

## Cloudflare Worker

- Workflow Run ID: 未実施
- Worker URL: 未設定
- デプロイ日時: 未実施
- Provider: Google Gemini Developer API
- GEMINI_MODEL: `gemini-2.5-flash-lite`
- Secret管理: コードとworkflowは`GEMINI_API_KEY`へ変更済み
- 疎通結果: 未実施

GitHub Repository secretsを確認した時点で必要なSecret名は未登録だった。値は確認・記録していない。

必要なRepository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `TORU_TANGO_GEMINI_API_KEY`

## Gemini基本実通信

| 教材 | 結果 | model | accepted/requested | tokens | elapsedMs | 品質所見 |
|---|---|---|---:|---:|---:|---|
| 通常説明文 | 外部設定待ち | | | | | |
| 歴史文 | 外部設定待ち | | | | | |
| 表形式OCR文 | 外部設定待ち | | | | | |
| OCRノイズ文 | 外部設定待ち | | | | | |
| 事実が少ない短文 | 外部設定待ち | | | | | |

## EAS development build

- Expo project ID: `app.config.ts`に未設定
- Build ID: 未実施
- Build URL: 未実施
- 対象commit SHA: 未固定
- Apple Vision Swift compile: 未確認
- iPhoneインストール: 未確認

ローカル環境に`EXPO_TOKEN`等の認証設定はなかった。Secret値は要求・記録しない。

## P0 / P1 / P2

### P0

- 認証不要範囲では未検出

### P1

- Worker未公開
- Gemini実通信未確認
- EAS development build未実施
- Apple Vision ModuleのSwiftコンパイル未確認

### P2

- Gemini無料枠のレート上限、規約、データ取扱いは公開直前に再確認が必要
- Expo DoctorはGitHub Actionsのnpm環境で再実行が必要

## 人間操作待ち

1. Google AI StudioでGemini APIキーを作成する。
2. GitHubリポジトリのSettings → Secrets and variables → Actionsで、上記3つのRepository secretsを登録する。
3. Expo認証を安全な環境で行うか、`EXPO_TOKEN`を安全に設定する。
4. Apple Developer認証が要求された場合は本人操作を行う。

Secret値はNotion、GitHub文書、PRコメント、チャット、ログへ記録しない。

## 再開手順

1. `Deploy Toru Tango AI Worker`を`workflow_dispatch`で実行する。
2. Worker URLを安全なEAS環境変数`EXPO_PUBLIC_AI_API_URL`へ設定する。
3. `AI_GEMINI_BENCHMARK.md`の3～5教材で実通信する。
4. `eas build --platform ios --profile development`を実行する。
5. Worker URL、Workflow Run ID、EAS Build ID、品質結果だけを本報告へ記録する。
6. 最新GitHub Actions成功後に完了候補headを固定する。

## 最終判定

**Gemini APIのコード実装と認証不要検査は完了。Worker公開、Gemini実通信、EAS development build、Apple Vision Swiftコンパイルが未完了のため、Claudeへはまだ渡さない。PR #3959はDraftを維持する。**
