# AI引継ぎ帳 v0.4 macOS・iOS検証手順

更新日：2026-07-23

## 現在地

Flutter 3.44.7のLinux CIでは、依存解決、整形、静的解析、13件のテスト、Webリリースビルドまで成功しています。

次に必要なのは、macOS・Xcode・CocoaPodsを使うiOS固有の確認です。

## 一括検証

Flutterプロジェクトのルートで次を実行します。

```bash
chmod +x scripts/verify_ios_macos.sh
./scripts/verify_ios_macos.sh
```

スクリプトは次を順番に実行します。

1. macOS、Xcode、iOS Simulator SDK、Flutter、Dart、CocoaPodsの確認
2. `flutter doctor -v`
3. `flutter clean`
4. `flutter pub get`
5. Dart整形検査
6. `flutter analyze`
7. `flutter test --coverage`
8. `flutter build ios --simulator --debug`
9. `Runner.app`の表示名、Bundle ID、最低iOSバージョン、Framework確認
10. Simulator用アプリのZIP化とSHA-256生成

結果は `build_reports/ios_YYYYMMDD_HHMMSS/` に保存されます。

## 合格条件

- `flutter doctor -v`でXcodeとCocoaPodsが利用可能
- `flutter pub get`成功
- `flutter analyze`でエラーなし
- 自動テスト全件成功
- `flutter build ios --simulator --debug`成功
- `build/ios/iphonesimulator/Runner.app`が存在
- アプリ表示名が「AI引継ぎ帳」

## 失敗時に確認するログ

- `verification.log`
- `flutter_doctor.log`
- `pub_get.log`
- `analyze.log`
- `test.log`
- `ios_simulator_build.log`
- `Podfile.lock`

## シミュレータービルド後の工程

1. `ios/Runner.xcworkspace`をXcodeで開く
2. Bundle Identifierを正式値へ確定
3. TeamをApple Developerアカウントへ設定
4. iPhoneを接続して実機ビルド
5. バックアップ入出力、共有シート、画面レイアウトを確認
6. Archiveを作成
7. App Store Connectへアップロード
8. TestFlightでテスト

## 未検証

- Apple署名
- iPhone実機
- Release Archive
- TestFlight
- App Store審査

GitHub ActionsによるmacOS CI定義も開発ブランチに用意済みですが、今回の試行では新規Actions実行履歴が生成されませんでした。リポジトリのActions設定または実行制限を確認後、同じ検証を自動化できます。
