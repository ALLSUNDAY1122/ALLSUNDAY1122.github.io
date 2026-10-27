# 仕訳スワイプ Flutter版

Web MVPと同じ問題データ・ゲームルールを使うiOS/Android向けFlutter実装です。

## 現在の実装

- 3級・2級・両方の級選択
- スコアアタック
- 60秒タイムアタック
- 苦手出題
- デイリー10問
- 左右スワイプとボタン回答
- 回答理由と完成仕訳
- 問題別成績、正答率、自己ベストの端末内保存
- ダークテーマ、iPhone縦画面向けUI

## Windowsでの開始

このディレクトリにはアプリ固有コードを保存しています。Flutter SDK導入後、プラットフォーム用ファイルを生成します。

```powershell
cd shiwake-swipe/flutter_app
flutter create --platforms=ios,android .
flutter pub get
flutter analyze
flutter test
```

`flutter create .` 実行時に `lib/` や `pubspec.yaml` を上書きしないよう、実行前にGitでコミット済みであることを確認してください。通常は既存ファイルを保ったまま不足するプラットフォームディレクトリが生成されますが、差分確認は必須です。

## Android・Windows向けFlutterのTLSセキュリティ確認（2026-10-27）

Dart公式Advisory [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp)（2026-10-23公開）によると、Flutter 3.47.8未満のAndroid・Windowsアプリで `dart:io` のTLS/HTTPS通信を行う場合、侵害されたeMudhra中間CA証明書を使った中間者攻撃の影響を受け得ます。修正版はFlutter stable 3.47.8（Dart stable 3.13.7）以上です。Linuxは未更新の証明書ストア等の条件付きで対象です。iOS・macOS・Webは対象外です。

このアプリの現在の説明では成績は端末内保存であり、該当するネットワーク通信や配布済みAndroid/Windowsバイナリの存在は未確認です。したがって「現行アプリが脆弱」とは断定しません。今後Android/Windows向けに通信機能を追加してビルド・配布する前に、`flutter --version` で実効Flutter/Dart SDKを確認し、3.47.8以上で再ビルドしたことを記録してください。旧版SDKのままの配布やOS証明書更新のみを修正完了と扱わないでください。SDK更新は依存・ビルドの回帰確認後に実施し、既存の公開・署名・認証設定は自動変更しません。

## iOSビルド

iOS向けのビルド、署名、TestFlightアップロードはmacOSとXcode上で行います。MacinCloudへリポジトリを取得後、Bundle ID、Signing Team、バージョンを設定します。

## 未実装

- App Store用PNGアイコン一式
- StoreKit課金
- 通知
- オンラインランキング
- 問題報告フォーム
- 全問題の監修
