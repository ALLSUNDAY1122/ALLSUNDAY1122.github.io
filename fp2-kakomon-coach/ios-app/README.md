# FP2級 過去問コーチ｜iOSネイティブラッパー

FP2級学科の公式過去問180問（2026年5月・2025年5月・2025年1月）を学習できる、監査済み単一HTML（`FP2_KAKOMON_COACH_v1.3.0.html`）を、Expo Router + WebViewでオフライン表示するだけの薄いネイティブラッパーです。

FP3級版（`com.allsunday1122.fp3kakomoncoach`）と同じ構成（Expo SDK 57 / React Native / react-native-webview）を踏襲していますが、Bundle ID・localStorageキー・GitHubブランチ・アイコン等はFP2級専用の値に分離しています。FP3級の資産には一切触れていません。

## 技術構成

- Expo SDK 57 / React Native 0.86 / Expo Router 6
- `react-native-webview`（Expo SDK互換バージョンに固定：`npx expo install react-native-webview` で解決）
- 画面は `app/index.tsx` の1画面のみ。`require('../assets/fp2-kakomon-coach.html')` でHTMLをJSバンドルにアセット同梱し、`file://` で読み込むためネットワーク接続不要
- 外部URL（`http`/`https`）はWebView内で開かず `Linking.openURL` でOS標準ブラウザに渡す
- サーバー通信・ログイン・広告・課金・トラッキングは一切なし。学習履歴はすべて端末内 `localStorage`（キー：`fp2_kakomon_coach_v1`）に保存

## 識別子（FP2級専用）

| 項目 | 値 |
| --- | --- |
| アプリ名 | FP2級 過去問コーチ |
| Expo slug | `fp2-kakomon-coach` |
| URL scheme | `fp2coach` |
| iOS Bundle ID | `com.allsunday1122.fp2kakomoncoach` |
| Android package | `com.allsunday1122.fp2kakomoncoach` |
| localStorageキー（HTML内） | `fp2_kakomon_coach_v1` |
| Version / Build | 1.0.0 / 1 |
| Expo Project ID | 未発行（`app.json` の `extra.eas.projectId` は空欄。EAS初回ビルド時に発行・記録する） |
| App Store Connect ID | 未発行 |

## セットアップ

```bash
npm install
npx expo-doctor      # 依存関係・設定の整合性チェック
npx tsc --noEmit      # 型チェック
npx eslint .          # Lint
```

いずれも本開発時点で0エラーであることを確認済み（後述の検証結果を参照）。

## ビルド（次工程）

```bash
# EAS初回のみ：プロジェクト作成・Project ID発行
eas init

# 開発ビルド / シミュレータ確認用
eas build --profile preview --platform ios

# 本番ビルド
eas build --profile production --platform ios

# 提出（App Store Connectの非消耗型/掲載情報等を先に設定した上で）
eas submit --profile production --platform ios
```

`eas.json` の `submit.production.ios` にある `appleId` / `ascAppId` / `appleTeamId` は空欄です。実行前に値を設定してください。

## 検証済み事項（本開発時点）

- `npm install`：依存解決成功（525パッケージ、node_modulesはネイティブLinuxファイルシステム上で実施。Windows共有マウント上では低速だったため、ビルド検証はホームディレクトリ配下で実施し、ソースを同期）
- `npx expo-doctor`：20/20チェック合格
- `npx tsc --noEmit`：0エラー（当初 `react-native-webview` のバージョンずれによる型エラーと `StyleSheet.absoluteFillObject` の誤記があったため、`npx expo install react-native-webview` でSDK互換バージョンへ調整し、`absoluteFill` に修正）
- `npx eslint .`：0エラー・0警告
- HTMLアセット（`assets/fp2-kakomon-coach.html`）は180問データを含むv1.3.0（暖色デザイン版）を同梱

## 未実施（次工程で必要な作業）

- `eas init` によるExpo Project ID発行
- iOSシミュレータ/実機でのWebView実地確認（Node.js上の型・構文検証のみで、実機・シミュレータでの起動確認は未実施）
- App Store Connectでのアプリ登録、非消耗型IAP（該当する場合）、掲載情報、スクリーンショット、プライバシー回答
- EAS Build（production）、TestFlight内部テスト、iPhone実機確認
- App Review提出

Apple ID・二要素認証・開発者契約同意など本人操作が必要な箇所は、ユーザー自身が行ってください。
