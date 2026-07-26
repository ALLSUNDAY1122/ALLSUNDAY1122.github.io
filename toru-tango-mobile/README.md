# 撮る単語帳 Mobile

Expo / React Native / TypeScriptで作成したiPhoneアプリ版です。

## 現在の実装

- 4タブ: 作る / 単語帳 / 学習 / 記録
- 直接入力と一括入力
- AI作問API接続
- API未設定・失敗時の端末内簡易作問
- 生成結果の編集と重複除外
- AsyncStorageによるカード・履歴保存
- カード編集・個別削除・二段階全削除
- 全カード / 苦手優先 / 未学習の学習モード
- 読み上げ
- 覚えた / もう一度
- 総回答数、正答率、連続学習、苦手カード、直近14日
- JSONバックアップと復元
- カメラ撮影・写真選択と権限拒否処理

写真OCRは未接続です。初回TestFlightの必須範囲から除外する場合は、Claude QAとユーザー承認で確定します。

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

OpenAI APIキーをアプリ、GitHub、`.env`へ保存してはいけません。APIキーはCloudflare WorkerのSecretだけに登録します。

## iPhoneでの確認

SDK 57移行期間中は、iPhoneのExpo Goが対応SDKと一致しない場合があります。その場合はEAS development buildまたはpreview buildを使います。

```bash
npx eas-cli@latest login
npx eas-cli@latest build --platform ios --profile preview
```

## 標準の担当順

1. ChatGPT: 仕様、実装、検査、開発文書
2. Claude: 動作確認、UI/UX改善、P0・P1解消
3. ユーザー: リリース候補承認
4. Codex: EAS Build、EAS Submit、TestFlight、申請

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
