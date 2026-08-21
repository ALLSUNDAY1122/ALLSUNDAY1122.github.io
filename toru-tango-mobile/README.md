# 撮る単語帳 Mobile

Expo / React Native / TypeScriptで作成したiPhoneアプリ版です。

## 現在の実装

- 4タブ: 作る / 単語帳 / 学習 / 記録
- 直接入力と一括入力
- AI作問API接続
- Apple Foundation Modelsによる端末内AI作問（iOS 26以降・対応端末）
- API未設定・失敗時の端末内簡易作問
- 生成結果の選択・編集・重複除外
- AsyncStorageによるカード・履歴保存
- カード編集・個別削除・二段階全削除
- 全カード / 苦手優先 / 未学習の学習モード
- 読み上げ
- 覚えた / もう一度
- 総回答数、正答率、連続学習、苦手カード、直近14日
- JSONバックアップと復元
- カメラ撮影・写真選択と権限拒否処理

写真OCRはApple VisionのローカルExpo Moduleで実装済みです。Expo Goでは動作しないため、EAS development buildまたは本番ビルドで確認します。

端末内AI作問もローカルExpo Moduleです。iOS 26以降でApple Intelligenceのモデルが利用可能な場合はFoundation Modelsを使い、非対応OS・非対応端末・Apple Intelligence無効・モデル準備中・生成失敗・品質基準未達では、端末内のルールベース作問へ自動で切り替えます。端末内作問では教材本文を外部送信しません。

生成した問題・答え・解説・根拠・確信度は保存前に確認できます。既存データとの互換性を守るため、単語帳へ保存するのは従来どおり問題と答えです。

## 必要環境

Expo SDK 57はNode.js 22.13系以上を使用します。

```bash
cd toru-tango-mobile
npm install
npm run check
npm start
```

個別に実行する場合:

```bash
npm run typecheck
npm run lint
npm run doctor
```

## AI API

Cloudflare Worker公開後に `.env` を作成します。

```env
EXPO_PUBLIC_AI_API_URL=https://YOUR-WORKER.workers.dev
```

`/generate` まで含めたURLも利用できます。

Gemini APIキーをアプリ、GitHub、`.env`へ保存してはいけません。APIキーはCloudflare Workerの`GEMINI_API_KEY` Secretだけに登録します。既定モデルは無料枠対象の`gemini-3.5-flash-lite`です。無料枠には利用上限があり、無料枠のデータ取扱いを公開前に再確認します。

## iPhoneでの確認

SDK 57移行期間中は、iPhoneのExpo Goが対応SDKと一致しない場合があります。その場合はEAS development buildまたはpreview buildを使います。

```bash
npx eas-cli@latest login
npx eas-cli@latest build --platform ios --profile preview
```

## 標準の担当順

1. ChatGPT: 仕様、Safari価値検証、既存実装監査
2. Codex: Gemini API、Worker公開、実通信、EAS development build
3. Claude: 動作確認、UI/UX改善、P0・P1解消
4. ユーザー: リリース候補承認
5. Codex: EAS production build、EAS Submit、TestFlight、申請

Codexへ渡した後は、原則として機能追加や大幅なUI変更を行いません。

## TestFlight

```bash
npx eas-cli@latest build --platform ios --profile production
npx eas-cli@latest submit --platform ios --profile production --latest
```

実行前に以下を確定します。

- Bundle ID: `com.allsunday1122.torutango`
- Version: `1.0.0`
- Build: `1`
- Apple Developer認証
- App Store Connectのアプリ登録
- EAS projectId
- アイコンと起動画面
- Cloudflare Worker URL
- プライバシー設問と輸出規制回答
- Claude QAのP0・P1が0件
- ユーザーの明示的な承認

## リリース文書

- `RELEASE_STATUS.md`
- `RELEASE_CHECKLIST.md`
- `CLAUDE_QA_HANDOFF.md`
- `APP_STORE_METADATA_JA.md`
- `PRIVACY_DATA.md`

## 参照

- `../toru-tango/IOS_MIGRATION_SPEC.md`
- `../toru-tango/CODEX_HANDOFF.md`
- `../toru-tango/backend/README.md`
