# 情報処理安全確保支援士｜学びスプリント
## App Store申請前リリース監査

基準日：2026-08-10

## 1. 製品・学習コンテンツ
- [x] Safari製品候補版：iPhone実機 HUMAN PASS
- [x] 8問スプリント
- [x] 4／8／16問設定
- [x] 公開過去問：3回×25問＝75問
- [x] 模試：各回を前半13問／後半12問へ分割
- [x] 独自問題：250問
- [x] 合計：325問
- [x] 苦手3連続正解解除
- [x] 中断復帰
- [x] 結果・記録・5週間ヒートマップ
- [x] JSON書き出し／読み込み
- [x] 学習データ初期化

## 2. 問題・制度・著作権
- [x] IPA公表済み過去問のみ利用
- [x] IPA公式解答照合 75/75
- [x] 出典・改変表示
- [x] 独自解説
- [x] 独自250問は公開シラバス・一次資料準拠
- [x] 重複・高類似・AI水増し監査PASS
- [x] 2026年度以降の非公開本試験問題を受験者記憶・SNS・漏洩情報から復元しない
- [x] 将来の公式サンプル追加時は問題・制度・著作権監査を再発火

## 3. 収益方式B｜購入監査再発火
### 確定方式
- [x] App本体：無料
- [x] IAP：Non-Consumable（買い切り）1件
- [x] Product ID：`jp.allsunday1122.scmanabisprint.premium`
- [x] 外部決済・外部購入誘導なし
- [x] 商品名・価格はStoreKitから取得し、コードへ価格固定しない
- [x] 「購入を復元」を設定画面へ常設

### 無料範囲
- [x] IPA公開過去問75問
- [x] 4／8／16問スプリント（無料時は75問から出題）
- [x] 公開過去問3回分の模試（13問＋12問）
- [x] 公開過去問の苦手復習
- [x] 基本学習記録・試験日・文字サイズ・JSON

### プレミアム範囲
- [x] 独自250問を追加して全325問化
- [x] 全325問を対象としたスプリント
- [x] 全325問の苦手復習
- [x] 分野別集中演習

### 実装監査
- [x] StoreKit 2対応のネイティブ購入ブリッジ導入
- [x] 購入／復元／現在の権利確認を実装
- [x] 以前に確認済みの買い切り権利は通信障害で不用意に失効させない
- [x] Safari確認版は課金テスト不能のため全325問を開放し、iOS本番のみゲートを有効化
- [ ] 最新IAP変更後のmacOS CI：最終PASS確認待ち
- [ ] App Store Connect Sandbox：未購入→購入→解放 HUMAN PASS
- [ ] Sandbox：キャンセル時に未解放を維持 HUMAN PASS
- [ ] Sandbox：再インストール相当→購入復元 HUMAN PASS
- [ ] Sandbox：購入済み端末のオフライン再起動 HUMAN PASS

Apple側のIAP実機試験は、App Store Connectで商品を作成してから実施する。

## 4. App Review 4.2対策
本番iOS版は公開WebサイトをURL表示するだけのラッパーにしない。
- [x] 325問をアプリバンドル内へ同梱
- [x] 学習履歴・苦手・設定を端末内保持
- [x] オフラインで主要学習機能を利用可能
- [x] 学習・復習・模試分割・記録・JSONバックアップ・IAP等のアプリ固有機能を持つ
- [x] 外部Webは一次根拠・サポート・プライバシー等をユーザー操作で開く用途に限定

## 5. プライバシー
- [x] Privacy Policy公開ページ
- [x] Support公開ページ
- [x] アプリ設定画面からPrivacy Policyへアクセス可能
- [x] 学習データの保持・削除方針を明記
- [x] StoreKit決済と端末上の購入権利確認をPrivacy Policyへ追記
- [x] アプリ内データ初期化
- [x] 広告SDKなし
- [x] 解析SDKなし
- [x] ログインなし
- [x] クラウド同期なし
- [x] 独自サーバーへのユーザーデータ・購入履歴・決済情報送信なし
- [x] App Privacy想定：No, we do not collect data from this app
- [x] PrivacyInfo.xcprivacy作成・構文監査

Privacy Policy URL：
https://allsunday1122.github.io/sc-manabi-sprint/privacy.html

Support URL：
https://allsunday1122.github.io/sc-manabi-sprint/support.html

## 6. iOSビルド
- [x] Capacitor 8.4.2固定
- [x] app内同梱方式
- [x] Version 1.0.0 / Build 1
- [x] 初版iPhone-only
- [x] iOSプロジェクト自動生成・設定
- [x] PrivacyInfo.xcprivacyをターゲットへ同梱
- [x] unsigned Simulator Debug build（課金追加前PASS）
- [x] unsigned physical-device Release build（課金追加前PASS）
- [ ] IAPプラグイン追加後のSimulator/Device build最終PASS確認待ち

## 7. 輸出コンプライアンス
- [x] 独自暗号アルゴリズム実装なし
- [x] 外部HTTPS等はApple OS側暗号機能を利用
- [x] ITSAppUsesNonExemptEncryption = NO を生成Info.plistへ自動設定

## 8. App Storeメタデータ
- [x] App名・サブタイトル・説明文・キーワード
- [x] 無料＋IAP表記へ説明文更新
- [x] Support URL / Privacy Policy URL
- [x] App Review NotesをIAP仕様へ更新
- [x] 非公式IPAアプリである旨の表示
- [x] IAP表示名・説明案
- [x] IAP Review Notes用の無料／有料差分を明文化
- [ ] Age Rating：App Store Connect質問票
- [ ] Content Rights：App Store Connect最終回答
- [ ] App Privacy：App Store Connect最終回答

## 9. App Store Connectで人間入力が必要なゲート
1. Paid Apps Agreementを確認／有効化
2. Bundle ID最終確定（暫定 `jp.allsunday1122.scmanabisprint`）
3. SKU確定
4. Appレコード作成
5. IAPをNon-Consumableとして作成
   - Reference Name：SC 学びスプリント プレミアム
   - Product ID：`jp.allsunday1122.scmanabisprint.premium`
6. 日本価格を確定（現時点の推奨：¥600）
7. IAPのReview Screenshotを添付
8. Apple Developer Team・署名・2FA
9. Signed Archive → TestFlightアップロード
10. Sandbox購入・復元・オフライン実機監査
11. TestFlight UI確認・実アプリスクリーンショット取得
12. Age Rating／Content Rights／App Privacy入力
13. 最終「審査へ提出」承認

## 10. スクリーンショット
初版推奨6枚：
1. ホーム：8問スプリント＋進捗
2. 問題：4択
3. 回答後：○×＋ここだけ覚える
4. 模試：3回×13／12
5. 記録：正答率＋分野＋5週間ヒートマップ
6. プレミアム：無料75問と全325問の差分が分かる画面

実アプリのTestFlight画面から取得し、SafariブラウザUIが写った画像は使用しない。

## 11. 再発火
問題、解説、出典、SDK、広告、解析、課金、外部通信、保存方式、対応端末、プライバシー、権利表示のいずれかを変更した場合、対応するPASSを失効し、関係ループを再実行する。
