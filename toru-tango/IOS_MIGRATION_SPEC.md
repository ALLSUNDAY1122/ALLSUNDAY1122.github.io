# 撮る単語帳 iOS移植仕様

更新日: 2026-07-26

## 目的

GitHub Pages上のWeb版「撮る単語帳」を、Expo / React NativeでiOSアプリ化し、EAS Build経由でTestFlightへ提出できる状態にする。

## 技術方針

- Expo SDK 57系
- React Native + TypeScript
- Expo Router
- 状態管理はReact ContextまたはZustandのいずれか一つに統一
- 永続化はAsyncStorage
- 写真選択・撮影はexpo-image-pickerまたはexpo-camera
- 読み上げはexpo-speech
- ファイル入出力はexpo-file-system + expo-sharing + expo-document-picker
- AI作問はCloudflare Worker経由。OpenAI APIキーはアプリに埋め込まない
- OCRは初期TestFlight版ではサーバーOCRまたは別API接続を前提とし、接続未完了時は画像添付後の手入力導線を残す

## 画面構成

### 1. 作る

- AI作問
  - 教材本文入力
  - 作問形式: 一問一答 / 穴埋め / 混合
  - 難易度: やさしい / 標準 / 難しい
  - 問題数: 5 / 10 / 15 / 20
  - 生成結果の編集
  - 重複除外
  - 保存済みカードとの完全重複除外
  - API未設定・通信失敗時は端末内簡易作問へフォールバック
- 直接入力
- まとめて入力
- 教材写真の撮影・選択

### 2. 単語帳

- 全カード一覧
- 苦手カード絞り込み
- 未学習カード絞り込み
- 問題・答え編集
- 個別削除
- 全削除は二段階確認

### 3. 学習

- 全カード
- 苦手優先
- 未学習のみ
- 問題表示
- 答え表示
- 読み上げ
- 覚えた / もう一度
- もう一度を選んだカードは同一セッション末尾へ再追加
- 進捗表示
- 学習完了表示

### 4. 記録

- 総回答数
- 正答率
- 連続学習日数
- 苦手カード数
- 直近14日の日別回答数・正答率
- JSONバックアップ
- JSON復元

## データモデル

```ts
export type Card = {
  id: string;
  question: string;
  answer: string;
  correct: number;
  wrong: number;
  lastStudiedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type StudyHistory = {
  id: string;
  cardId: string;
  answeredAt: string;
  dateKey: string;
  correct: boolean;
};
```

## AI API仕様

エンドポイントは環境変数 `EXPO_PUBLIC_AI_API_URL` で指定する。

```http
POST /generate
Content-Type: application/json

{
  "text": "教材本文",
  "count": 10,
  "type": "mix",
  "difficulty": "normal"
}
```

期待レスポンス:

```json
{
  "questions": [
    { "question": "問題文", "answer": "答え" }
  ]
}
```

## App Store向け設定

- 表示名: 撮る単語帳
- Bundle ID候補: `com.allsunday1122.torutango`
- バージョン: 1.0.0
- Build number: 1
- iPhone対応
- iPadは初期版では任意
- カメラ利用目的文を設定
- 写真ライブラリ利用目的文を設定
- 暗号化輸出規制は通常のHTTPS通信のみとして申告内容を確認
- プライバシーポリシーURL: `https://allsunday1122.github.io/toru-tango/privacy-policy.html`
- サポートURL: `https://allsunday1122.github.io/toru-tango/`

## TestFlight到達条件

- TypeScriptエラーなし
- Expo Doctor重大エラーなし
- iPhone実機で主要4画面が動作
- カード追加・編集・削除・学習・履歴・バックアップ復元が動作
- AI API未設定でもクラッシュしない
- 権限拒否時にクラッシュしない
- 空データ、重複データ、不正JSONでクラッシュしない
- EAS production buildが成功
- App Store Connectへビルドがアップロード済み

## 非対象

初回TestFlightでは以下を必須としない。

- ユーザー登録
- クラウド同期
- 課金
- 広告
- プッシュ通知
- 高精度OCRの完全自前実装
