# 登録販売者｜学びスプリント iOS

Expo SDK 57 + React Native WebViewのiOSラッパーです。

## 現在の構成
- Expo SDK 57
- React Native 0.86
- React 19.2.3
- react-native-webview 13.16.1
- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- Webアプリ: `https://allsunday1122.github.io/touroku-hanbaisha-sprint/`

## ローカル確認
```bash
npm install
npx expo-doctor
npx expo start
```

## EAS / TestFlight
```bash
npx eas-cli@latest login
npx eas-cli@latest build:configure
npx eas-cli@latest build --platform ios --profile production
npx eas-cli@latest submit --platform ios --profile production
```

Apple Developer / App Store Connectの認証、証明書、EAS projectIdは実行環境で設定してください。

## 申請前チェック
1. iPhone実機でホーム、今日の12問、章別、苦手復習を確認
2. 120問模試で正誤が途中表示されないことを確認
3. 途中中断→再起動→続きから再開を確認
4. 学習記録と文字サイズを確認
5. Privacy / Support URLをSafariで確認
6. 1024×1024アイコンとApp Storeスクリーンショットを確定
7. TestFlightで最終実機確認

## 注意
現在のラッパーはGitHub PagesのHTTPS版をWebViewで表示します。ネットワーク障害時はエラー画面を表示します。App Store本番提出前に、審査リスク低減とオフライン学習のためWeb成果物をアプリへ同梱する方式へ切り替えることを推奨します。
