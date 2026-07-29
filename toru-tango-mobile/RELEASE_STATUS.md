# 撮る単語帳 リリース状況

更新日: 2026-07-29

## 現在の段階

ユーザー判断により、Safari価値検証後の次担当をClaudeからCodexへ変更した。

現在は**Gemini API実装・Worker公開・モバイル接続・EAS／Apple登録を完了し、TestFlight用production buildのApple認証待ち**である。ユーザー指示によりTestFlight準備を先行しているが、EAS上のiOSビルドはまだ0件であり、TestFlight完了とは扱わない。PR `#3959`はDraftを維持する。

開発順:

1. ChatGPT: Safari価値検証、仕様整理、既存実装監査
2. Codex: API実装、Worker公開、アプリ接続、実通信、開発ビルド
3. Claude: API実装後のQAとUI改善
4. Codex: ClaudeのP0・P1解消後、TestFlight・App Store申請

## 作業対象

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ: `qa/toru-tango-mobile-20260726`
- Pull Request: `#3959`
- iOSアプリ: `toru-tango-mobile/`
- API Worker: `toru-tango/backend/`
- Safari価値検証参照: PR `#4059`
- Codex指示: `toru-tango-mobile/CODEX_API_HANDOFF.md`
- Codex開始文: `toru-tango-mobile/CODEX_START_PROMPT.md`
- Codex成果物: `toru-tango-mobile/CODEX_API_REPORT.md`

PR `#4059`はSafari OCR比較の参照資産として残す。API実装先、EAS実装先、Claude QA対象はPR `#3959`である。

## リリース識別情報

- アプリ名: 撮る単語帳
- Bundle ID: `com.allsunday1122.torutango`
- Version: `1.0.0`
- Build: `1`
- EAS project: `@allsunday1122/toru-tango`
- EAS project ID: `96443b56-fef4-4a25-b5e9-831eaa4ec854`
- App Store Connect App ID: `6795968222`
- 対応: iPhone
- 初期版の外観: ライトモード固定
- プライバシーポリシー: `https://allsunday1122.github.io/toru-tango/privacy-policy.html`
- サポートURL: `https://allsunday1122.github.io/toru-tango/`

## 実装済み

### 単語帳・学習

- カードの直接追加、一括追加、編集、削除
- 保存カードを表・裏として明示
- タップによる表裏反転
- 表と裏の個別読み上げ
- 重複除外
- AsyncStorage保存
- 学習履歴、正答率、連続学習、苦手カード
- JSONバックアップと復元

### 写真・OCR

- カメラ撮影と写真選択
- Apple Vision `VNRecognizeTextRequest`を使うiOSローカルExpo Module
- 0度・90度・180度・270度を比較する自動向き判定
- 左90度・右90度の手動指定
- 日本語・英語認識
- OCR結果の編集と教材本文への転送
- OCR空白、罫線、明確な誤認の修復

Apple Vision OCRはExpo Goでは利用できない。`expo-dev-client`を含むEAS development buildまたは本番ビルドで確認する。

### AI作問

- AI作問と端末内簡易作問を別操作として実装
- AI失敗時の別モデル・端末内作問への自動切替なし
- Google Gemini Developer API、`gemini-3.5-flash-lite`
- JSON Schemaによる構造化出力
- 事実単位の重複除外
- 使用モデル、トークン数、応答時間、除外件数の表示
- 歴史文章、保険表OCR、重複文、情報不足文の回帰テスト
- 低品質問題で指定件数を埋めない

### API / Worker

- `POST /generate`
- Gemini `generateContent` API
- Worker Secret `GEMINI_API_KEY`
- `GEMINI_MODEL`
- 入力長・件数・形式・難易度検証
- 45秒タイムアウト
- 重複・不完全カード除外
- 使用量、品質指標、応答時間返却
- モバイル側の`EXPO_PUBLIC_AI_API_URL`
- GitHub ActionsによるCloudflare Workerデプロイworkflow

## 自動検査

既存のPR `#3959`では次を検査している。

- TypeScript
- ESLint
- Expo Doctor
- Expo public config
- Web作問回帰
- モバイルOCR対応作問回帰
- Apple Vision Module構成
- Expo Modules Autolinking
- Expo iOS prebuild
- Worker構文

CodexはAPI正常系・異常系のテストを追加し、最新headでGitHub Actionsを成功させる。

## Codexの現在作業

2026-07-29時点でCloudflare Worker公開、GitHub Repository secrets 3件登録、Worker Secret登録、モバイル公開URL設定、EAS project作成、Apple Bundle ID登録、App Store Connectアプリ作成まで完了した。公開URLは`https://toru-tango-ai.kohei3615.workers.dev`。Worker versionは`95067016-86d6-4246-8b92-24e776f7f15a`。

単発のGemini実通信はHTTP 200、3問生成に成功した。直後の5教材連続試験は全件45秒タイムアウトしたため、無料枠を考慮して間隔を空けた再評価が必要である。最新head `3385359f64a4f79df02c884d2ef118eef50fe84a`ではGenerator CIとMobile CI 2件がすべて成功した。

1. Worker・モバイルクライアント・デプロイworkflowの整合性監査
2. API正常系・異常系テスト追加
3. Cloudflare Worker公開
4. Gemini APIキーをWorker Secretとして登録
5. `EXPO_PUBLIC_AI_API_URL`設定（完了）
6. Gemini 3.5 Flash-Liteで3～5教材の実通信
7. EAS projectの初期化・リンク確認（完了）
8. TestFlight用EAS production build（Apple認証待ち）
9. Apple Vision ModuleのSwiftコンパイル確認
10. `CODEX_API_REPORT.md`作成

Secretはコード、Markdown、PRコメント、ログへ保存しない。

## 外部操作に必要な情報

- Apple Developer認証（Apple IDログインと2段階認証）
- Cloudflare API Token
- Cloudflare Account ID
- Gemini APIキー

CodexはSecret値を要求・表示しない。未設定の場合は、必要なSecret名、設定場所、人間操作後の再開手順を報告する。

## Codex完了条件

- Worker公開
- アプリからWorkerへ接続
- Gemini 3.5 Flash-Lite 3～5教材の実通信成功
- API異常系テスト成功
- GitHub Actions成功
- EAS iOS build成功
- Apple Vision Moduleコンパイル成功
- `CODEX_API_REPORT.md`完成
- 完了候補head SHA固定

上記完了後にPR `#3959`をReady for reviewへ変更し、Claudeへ渡す。

## Claude QA

ClaudeはAPI実装完了後に開始する。

開始条件:

- `CODEX_API_REPORT.md`が「Claudeへ引渡可能」
- Worker公開済み
- アプリ接続済み
- Gemini実通信済み
- EAS development build成功
- GitHub Actions成功
- PR `#3959`がReady for review

Claudeの成果物は`toru-tango-mobile/CLAUDE_QA_REPORT.md`である。P0・P1を0件にし、固定20教材、主要導線、UI、エラー、空状態、保存・復元を確認する。

## 申請工程

ClaudeのP0・P1が0件となり、ユーザーがリリース候補を承認した後、Codexへ戻す。

Codexが担当する。

- production build
- EAS Submitまたは採用したクラウド経路
- App Store Connectアップロード
- TestFlight
- 掲載情報・スクリーンショット・審査資料
- App Review提出と差し戻し対応

ユーザー指示によりTestFlight準備を開始した。Apple DeveloperへのBundle ID登録とApp Store Connectアプリ作成は完了した。`eas build --platform ios --profile production`はApple認証待ちで、ビルド作成・EAS Submit・TestFlight処理は未完了。App Review提出は行わない。
