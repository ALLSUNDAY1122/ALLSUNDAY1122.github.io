# 理学療法士国家試験｜学びスプリント #15

SwiftUIネイティブ実装。WKWebView/UIWebViewを主UIに使用しません。学びスプリント UI Golden Master v2.1 と `native-ios/LearningSprintCore` を基準にします。

## 現在地
- ブランチ: `feat/15-rigaku-sprint-native`
- SwiftUI native shell: 初期実装
- 第60回: 公式PDFで午前100問＋午後100問を確認済み
- 第59・58回: 件数未固定。各PDF監査後に確定
- 第61回: 正答・合格発表は確認済みだが問題本文公開は未確認
- Bundle ID / App Store Connect App ID / IAP Product ID: 正本値未確認、推測禁止

## 一次資料
- 第61回施行: https://www.mhlw.go.jp/kouseiroudoushou/shikaku_shiken/rigakuryouhoushi/
- 第61回合格発表: https://www.mhlw.go.jp/general/sikaku/successlist/2026/siken08_09/about.html
- 第60回問題: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp250428-08_09.html
- 第58回問題: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp230524-08_09.html
- 厚労省利用規約: https://www.mhlw.go.jp/chosakuken/index.html
- PDL1.0: https://www.digital.go.jp/resources/open_data/public_data_license_v1.0
- 令和6年版出題基準: https://www.mhlw.go.jp/stf/shingi2/0000163627_00001.html

## ローカル検査
```bash
cd rigaku-sprint/ios
python3 static_audit.py
swiftc -frontend -parse Sources/AppConfiguration.swift Sources/RigakuSprintApp.swift Sources/RootTabView.swift
```

XcodeGen / Xcodeビルドでは正本Bundle IDを `RIGAKU_BUNDLE_ID` として注入します。正本値がない状態で仮Bundle IDを作成しません。
