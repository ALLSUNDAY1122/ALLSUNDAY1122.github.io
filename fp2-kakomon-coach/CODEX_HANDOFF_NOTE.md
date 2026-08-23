# Codex 引継ぎメモ — FP2級 過去問コーチ（Claude本開発完了・2026-08-02）

この文書は、Claudeが担当した本開発（HTML価値検証〜ネイティブラッパー雛形まで）の最終状態をまとめたものです。**ここから先（EAS Build本実行〜TestFlight〜App Review提出）をCodexに引き継ぎます。**

## リポジトリ・ブランチ

- リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ: `feature/fp2-kakomon-coach`（mainへは未マージ。ユーザー確認・承認までマージしないこと）
- Draft PR: [#4065「FP2級 過去問コーチ v1.0.0｜Claude本開発引継ぎ（Draft）」](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4065)
- フォルダ: `fp2-kakomon-coach/`

## Webアプリ本体（HTML）のバージョン履歴

- **v1.0.0**: 公式過去問180問（2026年5月・2025年5月・2025年1月の学科試験、各60問＝6分野×10問）を一次資料から直接転記し、全問に独自解説を付与した初版。
- **v1.1.0**: セッション構成をFP3級と同じ「年度×課目＝18セッション（各10問）」に変更。続きから始める（中断復帰）機能を追加。UIをインディゴ基調に刷新。
- **v1.2.0**: 実バグ2件を修正（文字サイズ設定が画面に反映されないバグ、弱点復習の3連続正解ロジックの誤登録バグ）。次回試験日カウントダウン機能、6課目別アクセントカラーを追加。
- **v1.3.0（Web版・最終）**: ユーザー提示の参考デザイン（暖色・クリーム背景・オレンジ基調）に忠実に全面リスキン。インディゴ系グラデーションヘッダーを廃止し、暖色クリーム背景・オレンジアクセントに統一。機能・ロジックはv1.2.0から変更なし。

**正本ファイル: `fp2-kakomon-coach/FP2_KAKOMON_COACH_v1.3.0.html`**（v1.0.0〜v1.2.0は変更履歴として同ディレクトリに残置）

180問の問題データ（question/choices/answer/explanation/domain/examDate等）はv1.0.0作成時から一切変更していません。localStorageキーは `fp2_kakomon_coach_v1` で固定、FP3級版（`fp3_kakomon_coach_v1`）とは完全に分離されています。

試用URL（htmlpreview経由、実際にブラウザ操作して動作確認済み）:
`https://htmlpreview.github.io/?https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/feature/fp2-kakomon-coach/fp2-kakomon-coach/FP2_KAKOMON_COACH_v1.3.0.html`

## ネイティブアプリ（Expo/React Native）の状態

`fp2-kakomon-coach/ios-app/` に、FP3級と同じ構成（Expo SDK 57・React Native・Expo Router・`react-native-webview`）でネイティブラッパーを新規作成済みです。

### 識別子（FP2級専用・FP3級とは別値）

| 項目 | 値 |
| --- | --- |
| アプリ名 | FP2級 過去問コーチ |
| Expo slug | `fp2-kakomon-coach` |
| URL scheme | `fp2coach` |
| iOS Bundle ID | `com.allsunday1122.fp2kakomoncoach` |
| Android package | `com.allsunday1122.fp2kakomoncoach` |
| Version / Build | 1.0.0 / 1 |
| Expo Project ID | **未発行**（`app.json` の `extra.eas.projectId` は空欄。`eas init` で発行が必要） |
| App Store Connect ID | 未発行 |

### 実装内容

- `app/index.tsx`: `require('../assets/fp2-kakomon-coach.html')` でv1.3.0のHTMLをJSバンドルにアセット同梱し、`react-native-webview` でオフライン表示する1画面構成。外部URL（http/https）はWebView内で開かず `Linking.openURL` でOS標準ブラウザに渡す設計。
- アイコン一式（`assets/icon.png` 等）はFP2専用に新規作成（オレンジ基調、中央に「FP2」の文字。FP3級版の紺色デザインとは別配色）。
- 背景色・ローディング表示色はWeb版v1.3.0の暖色テーマ（クリーム `#FDF6EF` ／オレンジ `#EE7D3F`）に合わせて設定済み。

### 発見・修正した実バグ（本開発中）

1. `react-native-webview` の当初インストールバージョン（14.0.1）がExpo SDK 57と非互換で、TypeScriptの型解決が壊れていた（`WebView`のprops型が`never`になる等）。`npx expo install react-native-webview` でSDK互換バージョン（13.16.1）に修正し解消。
2. `StyleSheet.absoluteFillObject` は現行React Native型定義に存在せず、`StyleSheet.absoluteFill` の誤記だった。修正済み。
3. `app.json` の `expo.newArchEnabled` トップレベルフィールドが現行スキーマでは無効なプロパティとして`expo-doctor`に検出されたため削除（RN 0.86では新アーキテクチャがデフォルトのため実害なし）。

### 実行した検証（実際にコマンドを実行し合格を確認済み）

- `npm install`: 依存解決成功（525パッケージ）。**注意**: Windows共有マウント上（`outputs/`直下）でのnpm installは極端に遅く、45秒のコマンドタイムアウトでは完了しなかったため、ホームディレクトリ配下（ネイティブLinuxファイルシステム）に一時コピーしてinstall・検証を実施し、結果（package.json/package-lock.json/eslint.config.js）を正本側に同期しました。次工程でも同様の遅さに遭遇した場合は、ネイティブファイルシステム上での作業を推奨します。
- `npx tsc --noEmit`: **0エラー**
- `npx eslint .`: **0エラー・0警告**
- `npx expo-doctor`: **20/20チェック合格**

これらはすべて型・構文・依存関係レベルの検証であり、**iOSシミュレータ/実機での起動確認・WebView実地動作確認は未実施**です。

## App Store Connect / EAS の状況

- ユーザー自身のブラウザで **App Store Connectへのログインは完了**しています（`https://appstoreconnect.apple.com/apps` が開ける状態）。
- **expo.dev（`allsunday1122's team`）はブラウザ上で既にログイン済み**です。Claudeの作業環境（毎回まっさらなクラウドサンドボックス）からは、この認証済みセッションを使ってCI用アクセストークンを発行しようとしたところ、Claude側の安全装置（アカウント認証情報の新規発行に関する操作）でブロックされました。これはユーザーの許可があっても回避していません。
- そのため **`eas init` によるProject ID発行、`eas build`、`eas submit` は今回未実施**です。Codexの実行環境で `eas login` が可能であれば、通常通り進めてください。

## Codexが次に行うべき作業

1. `fp2-kakomon-coach/ios-app/` を対象フォルダとして開発を引き継ぐ（GitHubは既に `feature/fp2-kakomon-coach` ブランチに反映済み）。
2. `eas init` でExpo Project IDを発行し、`app.json` の `extra.eas.projectId` に記録する。
3. `eas build --profile preview --platform ios`（シミュレータ確認）→ 問題なければ `eas build --profile production --platform ios`。
4. App Store Connectで新規アプリ登録（Bundle ID `com.allsunday1122.fp2kakomoncoach`）、掲載情報、スクリーンショット、プライバシー回答（データ収集なし、localStorageのみ）を設定。
5. `eas submit --profile production --platform ios` でTestFlightへアップロード。
6. ユーザーによるiPhone実機確認（本開発では未実施のため必須）。
7. 問題なければApp Review提出（ユーザーの最終承認後）。

## 変更禁止事項（標準手順どおり）

- FP3級版のBundle ID・Expo Project ID・App Store Connectアプリ・localStorageキー・問題データには一切触れない。
- ユーザー確認なしに `feature/fp2-kakomon-coach` を `main` にマージしない。
- ユーザー確認なしにApp Store一般公開・審査提出をしない。
- 180問の問題文・選択肢・正答・解説は本開発時点の内容を正本とし、Codex側で無断変更しない（修正が必要な場合はユーザーに報告の上で行う）。
