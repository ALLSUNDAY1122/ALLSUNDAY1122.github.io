# 撮る単語帳 Mobile

Expo / React Native / TypeScriptで作成したiOSアプリ版です。

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

OCRは未接続です。初回TestFlightまでに接続するか、写真選択後の手入力導線を明確にします。

## 必要環境

Expo SDK 57はNode.js 22.13系以上を使用します。

```bash
cd toru-tango-mobile
npm install
npm run typecheck
npm run lint
npm run doctor
npm start
```

## AI API

Cloudflare Worker公開後に `.env` を作成します。

```env
EXPO_PUBLIC_AI_API_URL=https://YOUR-WORKER.workers.dev/generate
```

OpenAI APIキーをアプリ、GitHub、`.env`へ保存してはいけません。APIキーはCloudflare WorkerのSecretだけに登録します。

## iPhoneでの確認

SDK 57移行期間中は、iPhoneのExpo Goが対応SDKと一致しない場合があります。その場合はEAS development buildまたはpreview buildを使います。

```bash
npx eas-cli@latest login
npx eas-cli@latest build --platform ios --profile preview
```

## TestFlight

```bash
npx eas-cli@latest build --platform ios --profile production
npx eas-cli@latest submit --platform ios --profile production
```

実行前に以下を確定します。

- Bundle ID: `com.allsunday1122.torutango`
- Apple Developer認証
- App Store Connectのアプリ登録
- アイコンと起動画面
- Cloudflare Worker URL
- プライバシー設問と輸出規制回答

## 参照

- `../toru-tango/IOS_MIGRATION_SPEC.md`
- `../toru-tango/CODEX_HANDOFF.md`
- `../toru-tango/backend/README.md`
