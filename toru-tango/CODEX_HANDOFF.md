# Codex引き継ぎ書: 撮る単語帳 iOS

## 現在地

Web版は `toru-tango/index.html` で稼働中。

実装済み:

- カード直接入力
- 一括入力
- 教材本文から端末内簡易作問
- 作問形式・難易度・問題数指定
- 生成結果編集
- 重複除外
- カード編集・削除
- 学習モード
- 正誤記録
- 連続学習日数
- JSONバックアップ・復元
- ブラウザOCR
- PWA / Service Worker
- Cloudflare Worker用AIバックエンド雛形

主要参照ファイル:

- `toru-tango/index.html`
- `toru-tango/privacy-policy.html`
- `toru-tango/IOS_MIGRATION_SPEC.md`
- `toru-tango/backend/src/index.js`
- `toru-tango/backend/wrangler.jsonc`
- `toru-tango/backend/README.md`

## Codexへの実装指示

`toru-tango-mobile/` にExpo / React Native / TypeScriptプロジェクトを作成すること。

1. Expo Routerで4タブを作成する。
   - 作る
   - 単語帳
   - 学習
   - 記録
2. Web版の機能を `IOS_MIGRATION_SPEC.md` に従って移植する。
3. AsyncStorageを利用し、アプリ再起動後もカードと履歴を保持する。
4. データアクセスを `src/repositories/`、型を `src/types/`、画面を `app/`、共通UIを `src/components/` に分離する。
5. AI作問API URLはコードへ直書きせず、`EXPO_PUBLIC_AI_API_URL` を使用する。
6. API未設定または失敗時は端末内簡易作問へ切り替える。
7. OpenAI APIキーをアプリ、GitHub、`.env.example` に書かない。
8. iOS権限説明文を `app.json` または `app.config.ts` に設定する。
9. EAS Build用 `eas.json` を作成する。
10. `npm run typecheck`、`npm run lint`、`npx expo-doctor` を実行できる構成にする。

## 推奨ディレクトリ

```text
toru-tango-mobile/
  app/
    _layout.tsx
    (tabs)/
      _layout.tsx
      create.tsx
      cards.tsx
      study.tsx
      records.tsx
  src/
    components/
    services/
      ai.ts
      localQuestionGenerator.ts
      backup.ts
    repositories/
      storage.ts
    types/
      index.ts
    utils/
      date.ts
      duplicate.ts
  assets/
  app.config.ts
  eas.json
  package.json
  tsconfig.json
  .env.example
  README.md
```

## 受け入れテスト

- 初回起動時にクラッシュしない
- 直接入力でカードを1枚保存できる
- 同じ問題・答えの完全重複を保存しない
- 10枚以上の一括登録ができる
- AI API未設定でも簡易作問できる
- AI API応答をカード候補として編集できる
- カード一覧で編集・削除できる
- 全カード・苦手・未学習で学習できる
- 「もう一度」で同一セッション末尾に再出題される
- 履歴と正答率が再起動後も残る
- JSONバックアップを書き出せる
- 正常JSONを復元できる
- 不正JSONでは既存データを破壊しない
- カメラ・写真権限拒否時にクラッシュしない

## ユーザー側で必要な操作

- Expo / EASへのログイン
- Apple Developerアカウント認証
- Bundle IDの最終確定
- Cloudflare Worker公開
- OpenAI APIキーをCloudflare Secretに登録
- TestFlightの輸出規制・プライバシー設問への回答

## 完了報告に含める内容

- 実装した機能
- 未完了項目
- 実行した検査と結果
- EAS Buildコマンド
- TestFlight提出手順
- ユーザーが入力すべき値の一覧
