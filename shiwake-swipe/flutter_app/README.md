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

## iOSビルド

iOS向けのビルド、署名、TestFlightアップロードはmacOSとXcode上で行います。MacinCloudへリポジトリを取得後、Bundle ID、Signing Team、バージョンを設定します。

## 未実装

- App Store用PNGアイコン一式
- StoreKit課金
- 通知
- オンラインランキング
- 問題報告フォーム
- 全問題の監修
