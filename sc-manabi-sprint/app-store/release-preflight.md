# 情報処理安全確保支援士｜学びスプリント
## App Store申請前リリース監査

基準日：2026-08-09

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

## 3. App Review 4.2対策
本番iOS版は公開WebサイトをURL表示するだけのラッパーにしない。
- [x] 325問をアプリバンドル内へ同梱
- [x] 学習履歴・苦手・設定を端末内保持
- [x] オフラインで主要学習機能を利用可能
- [x] 8問スプリント、苦手復習、模試分割、記録、JSONバックアップ等のアプリ固有機能を持つ
- [x] 外部Webは一次根拠・サポート・プライバシー等をユーザー操作で開く用途に限定

Apple公式：App Review Guidelines
https://developer.apple.com/app-store/review/guidelines/

## 4. プライバシー
- [x] Privacy Policy公開ページ作成
- [x] Support公開ページ作成
- [x] アプリ設定画面からPrivacy Policyへアクセス可能
- [x] 学習データの保持・削除方針を明記
- [x] アプリ内データ初期化を実装
- [x] 初版：広告SDKなし
- [x] 初版：解析SDKなし
- [x] 初版：ログインなし
- [x] 初版：クラウド同期なし
- [x] 初版：独自サーバーへのユーザーデータ送信なし
- [x] App Privacy想定：No, we do not collect data from this app
- [x] PrivacyInfo.xcprivacy作成・構文監査
- [x] 生成.app内へPrivacyInfo.xcprivacy同梱確認

Privacy Policy URL:
https://allsunday1122.github.io/sc-manabi-sprint/privacy.html

Support URL:
https://allsunday1122.github.io/sc-manabi-sprint/support.html

## 5. iOSビルド
- [x] Capacitor 8.4.2固定
- [x] app内同梱方式
- [x] iOSプロジェクト自動生成
- [x] iOS sync
- [x] unsigned iOS Simulator Debug build
- [x] unsigned physical-device Release build
- [x] 生成.app内の問題データ確認
- [x] 生成.app内のUIパッチ確認
- [x] Version 1.0.0 / Build 1
- [x] 初版iPhone-only

## 6. 輸出コンプライアンス
- [x] 独自暗号アルゴリズム実装なし
- [x] 外部HTTPS等はApple OS側の暗号機能を利用
- [x] ITSAppUsesNonExemptEncryption = NO を生成Info.plistへ自動設定
- [x] ビルド済み.appのInfo.plistでもNOを確認

Apple公式：Export Compliance
https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance

## 7. App Storeメタデータ
- [x] App名案：19文字／30文字以内
- [x] サブタイトル案：13文字／30文字以内
- [x] Promotional Text：73文字／170文字以内
- [x] Description案
- [x] Keywords：UTF-8 94 bytes／100 bytes以内
- [x] Support URL
- [x] Privacy Policy URL
- [x] App Review Notes
- [x] 非公式IPAアプリである旨の表示
- [ ] Age Rating：App Store Connect質問票の最終結果を確定
- [ ] Content Rights：IPA公表問題を含むため、権利を有する／利用条件上許可される第三者コンテンツとしてApp Store Connectで回答

## 8. スクリーンショット
AppleはiPhoneアプリで1〜10枚を受け付ける。
初版推奨5枚：
1. ホーム：8問スプリント＋進捗
2. 問題：4択
3. 回答後：○×＋ここだけ覚える
4. 模試：3回×前半13／後半12
5. 記録：正答率＋分野＋5週間ヒートマップ

実アプリのTestFlight画面から取得し、SafariブラウザのUIが写った画像は使用しない。

Apple公式：Screenshot specifications
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## 9. 人間入力が必要になる最終ゲート
以下はAppleアカウントまたはプロダクト判断が必要なため自動確定しない。
1. 収益方式：無料／買い切り／IAP
2. Bundle ID最終確定（暫定 `jp.allsunday1122.scmanabisprint`）
3. SKU最終確定
4. Apple Developer Team・署名・2FA
5. App Store Connectのアプリレコード作成
6. App Icon最終承認
7. Signed Archive → TestFlightアップロード
8. TestFlight実機確認
9. App Store用実機スクリーンショット最終選定
10. Age Rating質問票、Content Rights、App Privacy回答
11. 最終「審査へ提出」承認

## 10. 再発火
問題、解説、出典、SDK、広告、解析、課金、外部通信、保存方式、対応端末、プライバシー、権利表示のいずれかを変更した場合、対応するPASSは失効し、関係ループを再実行する。
