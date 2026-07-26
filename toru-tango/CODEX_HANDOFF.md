# Codex引き継ぎ書: 撮る単語帳 iOS

更新日: 2026-07-26

## 現在地

Web版は `toru-tango/index.html` で公開中です。

Expo / React Native版は `toru-tango-mobile/` に作成済みです。新規作成から始めず、既存実装を検査・修正してTestFlightへ進めてください。

## Mobile実装済み

- Expo SDK 57 / React Native / TypeScript / Expo Router
- 4タブ
  - 作る
  - 単語帳
  - 学習
  - 記録
- AsyncStorageによるカード・履歴の永続化
- 直接入力
- まとめて入力
- AI作問APIクライアント
- API未設定・失敗時の端末内簡易作問
- 作問形式・難易度・問題数指定
- 生成結果の編集
- 保存済みカードを含む重複除外
- カード編集・個別削除・二段階全削除
- 全カード / 苦手優先 / 未学習の学習モード
- 問題・答えの読み上げ
- 覚えた / もう一度
- 「もう一度」の同一セッション末尾への再追加
- 総回答数・正答率・連続学習日数・苦手カード数
- 直近14日の日別履歴
- JSONバックアップ・復元
- カメラ撮影・写真選択
- 権限拒否時の案内
- iOS権限説明文
- EAS Build設定
- ESLint・TypeScript・Expo Doctor用スクリプト
- GitHub Actions CI

## 主要ファイル

### Mobile

- `toru-tango-mobile/AGENTS.md`
- `toru-tango-mobile/README.md`
- `toru-tango-mobile/package.json`
- `toru-tango-mobile/app.config.ts`
- `toru-tango-mobile/eas.json`
- `toru-tango-mobile/app/`
- `toru-tango-mobile/src/context/AppStore.tsx`
- `toru-tango-mobile/src/services/ai.ts`
- `toru-tango-mobile/src/services/localQuestionGenerator.ts`
- `toru-tango-mobile/src/services/backup.ts`
- `.github/workflows/toru-tango-mobile-ci.yml`

### Web・バックエンド

- `toru-tango/index.html`
- `toru-tango/privacy-policy.html`
- `toru-tango/IOS_MIGRATION_SPEC.md`
- `toru-tango/backend/src/index.js`
- `toru-tango/backend/wrangler.jsonc`
- `toru-tango/backend/README.md`

## 最初に実行すること

```bash
cd toru-tango-mobile
npm install
npm run typecheck
npm run lint
npm run doctor
```

依存関係が確定したら `package-lock.json` を生成してコミットしてください。

## 優先作業

1. GitHub Actionsの初回結果を確認し、TypeScript・ESLint・Expo Doctorの失敗を修正する。
2. iPhone実機またはEAS preview buildで4画面を操作確認する。
3. カード追加・編集・削除・学習・履歴・バックアップ復元を通しで確認する。
4. 教材写真からのOCRを接続する。初回TestFlightに間に合わない場合は、写真選択後の手入力導線を明確化する。
5. 1024px App Storeアイコンと起動画面を追加する。
6. Cloudflare Workerを公開し、`EXPO_PUBLIC_AI_API_URL` を設定してAI作問を実接続する。
7. EAS production buildを作成し、App Store Connectへアップロードする。

## 固定ルール

- OpenAI APIキーをアプリ、GitHub、`.env.example` に書かない。
- APIキーはCloudflare WorkerのSecretだけに登録する。
- AI API未設定・失敗時の端末内簡易作問を削除しない。
- Bundle ID `com.allsunday1122.torutango` はユーザー確認なしに変更しない。
- 既存カード・履歴を破壊するデータ変更を行わない。
- Web版の変更をMobile版へ無条件で上書きしない。

## 未検証・未完了

- このセッションでは外部ネットワーク制限により、ローカルでの `npm install`、TypeScript、ESLint、Expo Doctorを実行できていない。
- GitHub Actions CIの結果確認
- package-lock.json生成
- iPhone実機確認
- OCR接続
- アイコン・起動画面
- Cloudflare Worker公開
- OpenAI APIキーのCloudflare Secret登録
- AI API実接続
- EAS preview / production build
- TestFlightアップロード

## 受け入れテスト

- 初回起動時にクラッシュしない
- 直接入力でカードを1枚保存できる
- 同じ問題・答えの完全重複を保存しない
- 10枚以上を一括登録できる
- AI API未設定でも簡易作問できる
- AI API応答をカード候補として編集できる
- カード一覧で編集・削除できる
- 全カード・苦手優先・未学習で学習できる
- 「もう一度」で同一セッション末尾に再出題される
- 履歴と正答率が再起動後も残る
- JSONバックアップを書き出せる
- 正常JSONを復元できる
- 不正JSONでは既存データを破壊しない
- カメラ・写真権限拒否時にクラッシュしない
- AI APIタイムアウト・4xx・5xxでクラッシュしない

## ユーザー側で必要な操作

- Expo / EASへのログイン
- Apple Developerアカウント認証
- Bundle IDの最終確認
- Cloudflare Worker公開
- OpenAI APIキーをCloudflare Secretに登録
- App Store Connectのアプリ登録
- TestFlightの輸出規制・プライバシー設問への回答

## 完了報告に含める内容

- 実装した機能
- 未完了項目
- 実行した検査と結果
- CI URLと結果
- EAS Build URLと結果
- TestFlight提出手順
- ユーザーが入力すべき値の一覧
