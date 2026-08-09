# 通関士｜学びスプリント StoreKit 2 テスト計画

更新日: 2026-08-09
Product ID: `jp.allsunday1122.tsukanshi.premium`
Type: Non-Consumable

## A. XcodeローカルStoreKitテスト
App Store Connect登録前でも実施できる開発テスト。

### ローカル設定値
- Reference Name: `通関士 プレミアム解放`
- Product ID: `jp.allsunday1122.tsukanshi.premium`
- Type: Non-Consumable
- Display Name: `プレミアム解放`
- Description: `模擬試験・苦手復習・申告書演習などのプレミアム機能を買い切りで解放します。`
- Price: テスト用。正式価格はApp Store Connect値を正本とする。

### 合格ケース
1. 未購入状態でPremium=false
2. 商品情報取得後にStoreKitの`displayPrice`が表示される
3. 購入成功でPremium=true
4. 購入後にアプリ再起動してもPremium=true
5. `購入を復元`でPremium=trueへ復帰
6. 取引削除後は未購入状態へ戻せる
7. 保留取引を解決した際、`Transaction.updates`経由でPremium=trueへ更新
8. 購入取消ではPremium=falseを維持
9. 商品情報取得不能時にクラッシュしない
10. revoke済み取引を権利として扱わない

## B. App Store Sandbox / TestFlight
App Store ConnectにIAPを作成し、TestFlight Build処理完了後に実施する本番相当テスト。

### 合格ケース
1. 商品IDがApp Store Connectから取得できる
2. 表示価格がApp Store Connectの正式価格と一致
3. Sandbox購入成功
4. 購入直後にロック対象が解放
5. アプリ終了・再起動後も解放維持
6. アプリ再インストール後、復元で解放
7. 別端末または取引状態変化を再取得できる
8. 通信失敗時も学習済み無料範囲が壊れない
9. `userCancelled`で誤ってPremiumにしない
10. `pending`状態で誤ってPremiumにしない

## C. Premium解放対象の確認
購入後に最低限以下を確認する。
- 苦手復習
- 第59回／58回／57回 × 3科目の模試
- 申告書演習12セット
- 無料範囲外の計算問題

## D. 証跡
TestFlight実機確認時に以下を残す。
- Build番号
- iOSバージョン
- 端末名
- 購入成功画面
- 復元成功画面
- 再起動後Premium維持
- 不具合があれば再現手順

## E. 判定
- Aはコード／Xcode段階の開発ゲート。
- B〜DはApp Store Connect + TestFlight後の実機ゲート。
- Bの購入・復元が両方成功するまでApp Store-readyにしない。
