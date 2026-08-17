# Release Checklist - TestFlight

## コード・教材側
- [x] FP2級 v1.3実装（PR #4065）を直接比較し共通UIを同期
- [x] 3公表回×3課目＝9カード
- [x] 132問の意味的独立性（旧44コア＋88反復を破棄し再構築）
- [x] 3公表回×44問を意味的に独立した132問へ再構築
- [x] 各回17/17/10、計44レコード
- [x] 各回・課目の完答回数保存
- [x] 中断・続きから再開
- [x] 選択肢タップ即時採点 / わからない / 3連続正解で弱点解除
- [x] 関係法令51レコードの現行法監査（基準日2026-08-08）
- [x] 現行132レコードの正答文字列監査（132/132 PASS）
- [x] 再構築後132問の正答・解説・意味的重複・出典を全件再監査
- [x] StoreKit 2 月額サブスク＋買い切りIAPコード
- [x] currentEntitlements / Transaction.updates / 購入 / 復元 / revocation対応
- [x] Privacy Manifest
- [x] App Icon
- [x] App Store metadata / IAP設定書
- [x] Codemagic TestFlight設定（App Store本審査自動提出OFF）

## Apple側・実ビルドで必要
- [ ] Explicit App ID `jp.allsunday1122.healthmanager1` 登録
- [ ] App Store ConnectにApp作成
- [ ] Non-Consumable `jp.allsunday1122.healthmanager1.premium` 作成・価格設定
- [ ] Paid Apps Agreement / 税務 / 銀行情報確認
- [ ] Codemagic App Store Connect integration接続
- [ ] 署名付きArchive / IPA build成功
- [ ] TestFlight upload成功
- [ ] iPhoneで起動、9カード、12問、44問、中断再開、完答回数を確認
- [ ] Sandbox購入成功・キャンセル・pending・復元・失効を確認

**上の未完了項目を実行するまでは「TestFlight申請済み／アップロード成功」と表現しない。**

## 法律・規約 最終ゲート（2026-08-09）
- [x] 公式公表問題の全文転載なし
- [x] 「公表回対応」表記へ変更し、公式過去問そのものと誤認させない
- [x] 非公式アプリであることを明記
- [x] プライバシーポリシーをGitHub Pages用リポジトリに配置
- [x] 利用規約をGitHub Pages用リポジトリに配置
- [x] サポートページをGitHub Pages用リポジトリに配置
- [x] デジタル機能の解放はStoreKit 2の非消耗型IAP
- [x] 購入復元導線あり
- [ ] App Store Connect登録時に各URLへ実ブラウザからアクセスできることを再確認

## 月額＋買い切り課金ゲート（2026-08-09）
- [x] 月額Product ID `jp.allsunday1122.healthmanager1.monthly`
- [x] 買い切りProduct ID `jp.allsunday1122.healthmanager1.lifetime`
- [x] 2商品をStoreKitから同時取得
- [x] どちらかのentitlementでプレミアム解放
- [x] 月額のIntro Offer資格をStoreKitで判定
- [x] 7日無料はStoreKit設定・資格の両方を満たす場合のみ表示
- [x] 月額・買い切り比較UI
- [x] 購入復元
- [x] サブスクリプション管理導線
- [ ] App Store Connectで月額200円相当を設定
- [ ] Introductory Offer: Free Trial / 1 Weekを設定
- [ ] App Store Connectで買い切り980円相当を設定
- [ ] Sandboxで月額購入・無料トライアル・期限切れ・買い切り・復元・返金を実機確認
