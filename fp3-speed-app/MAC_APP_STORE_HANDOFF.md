# FP3 SPEED v0.4.1+14 Mac・App Store引継ぎ

## 現在地

- アプリ名：FP3 SPEED
- Flutterパッケージ：`fp3_speed_quiz`
- Version / Build：`0.4.1+14`
- Bundle ID：`jp.allsunday.fp3speed`
- 非消耗型課金ID：`jp.allsunday.fp3speed.fullunlock`
- 無料問題：120問（6分野×20問）
- 課金解放：追加480問、合計600問
- 問題基準日：2026年4月1日
- 認証・広告・解析・外部サーバー：なし
- 学習履歴：端末内保存

## 完了済み検証

- 全600問の構造・重複・分野配分検査
- 全600問の公式・公的一次資料監査
- Flutter 3.44.8で依存解決
- `flutter analyze --no-fatal-infos`：0件
- `flutter test`：15件合格
- Web Releaseビルド
- macOS/Xcode上のiOS Releaseビルド（署名なし）
- 生成アプリのBundle ID・表示名確認
- iOSプロジェクト生成とGitHub保存

## Macで最初に行うこと

```bash
git clone --branch app/fp3-speed-v041 --single-branch https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git
cd ALLSUNDAY1122.github.io/fp3-speed-app
flutter pub get
open ios/Runner.xcworkspace
```

ZIPを使う場合は、`FP3_SPEED_Mac_Source_v0.4.1_build14.zip`を展開し、そのフォルダで`flutter pub get`を実行してから`ios/Runner.xcworkspace`を開く。

## Xcode設定

1. 左側で`Runner`プロジェクトを選択する。
2. `TARGETS`の`Runner`を選択する。
3. `Signing & Capabilities`を開く。
4. `Automatically manage signing`を有効にする。
5. Apple Developer Programへ加入しているTeamを選択する。
6. Bundle Identifierが`jp.allsunday.fp3speed`であることを確認する。
7. 実機のiPhone 16を選択してRunする。

## App Store Connect

1. Bundle ID `jp.allsunday.fp3speed`に対応するアプリを作成する。
2. 非消耗型App内課金を作成する。
3. Product IDは`jp.allsunday.fp3speed.fullunlock`を完全一致で登録する。
4. 販売価格、表示名、説明、審査用スクリーンショットを登録する。
5. 課金商品をアプリの初回提出に紐づける。

## StoreKit・Sandbox確認

- 商品価格がアプリ内に表示される。
- 購入確認画面が開く。
- 購入完了後に全600問が利用できる。
- アプリ再起動後も解放状態を維持する。
- 購入済みApple Accountで復元できる。
- 未購入アカウントでは復元対象なしと表示される。
- 購入キャンセル、通信失敗、商品未登録時にクラッシュしない。

## 実機確認

- 右スワイプで○、左スワイプで×になる。
- 15秒経過時の時間切れ処理が一度だけ動く。
- 正解・不正解表示後、自動で次の問題へ進む。
- 無料状態では各分野20問のみ利用できる。
- 課金状態では各分野100問利用できる。
- 未出題、苦手復習、連続学習日数、正答率が保存される。
- 機内モードでも課金済み学習と学習履歴が利用できる。
- アプリ削除・再インストール後は購入復元で再解放できる。

## Archive・TestFlight

1. Xcodeで実機または`Any iOS Device (arm64)`を選ぶ。
2. `Product` → `Archive`を実行する。
3. Organizerで`Validate App`を実行する。
4. `Distribute App` → `App Store Connect`へアップロードする。
5. TestFlight内部テストへ追加する。
6. iPhone 16で購入・復元を含む最終確認を行う。

## 未完了

- Apple Developer Teamによる署名
- App Store Connectのアプリ登録
- 非消耗型課金商品の登録
- StoreKit Configuration／Sandbox購入・復元
- iPhone 16実機試験
- 正式App IconとApp Storeスクリーンショットの最終確認
- TestFlight
- App Review提出

署名なしの`Runner.app`はコンパイル成功の確認用であり、そのままiPhoneへの通常インストールやApp Store提出には使用しない。
